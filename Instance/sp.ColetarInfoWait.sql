/*#info 
	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Descricao 
		Uma proc que criei no apssado para coletar informacoes de waits.
		NEssa epoca nem sonhava em ter uma ferramenta como o Power Alerts, que ja tem esse tipo de coisa.
		Mas fica ai como ideia original

*/

/********************************************************************************************************************************************
	Descri��o
		Realiza a coleta dos dados da tabela 'sys.dm_os_wait_stats' em um intervado de tempos escolhido.
	Depend�ncias
		Tabelas/Views
			#1 - sys.dm_os_wait_stats
		Fun��es/Procedures
			#1 - dbo.Split
		Refer�ncias
			Nenhuma
		Comandos
			Nenhuma
			
	Vers�es suportadas
		SQL Server 2005
		SQL Server 2008 (inclusive R2)
		
	Par�metros
		@TempoDeColeta
			� o tempo em milisegundos de coleta. Esse tempo que a procedure ficar� rodando realizando a coleta.
			Este tempo pode variar dependendo se alguma opera��o no servidor est� causando algum lock.
			O padr�o � 1000 mil�simos (1 segundo).
			
		@IntervaloColeta
			Esse intervalor deve ser especificado no formato 'hh:mm:ss', e indica o tempo em que a procedure ir�
			esperar para iniciar um nova coleta, se o tempo de coleta ainda n�o tiver sido atinigo.
			Padr�o � 2 segundos.
			
		@ListaWaits
			A lista de waits que dever�o ser inclu�dos, ou exclu�dos da coleta.
			Cada item da lista deve estar separado por ',' (v�rgula).
			Para cada item, pode se especificar caracteres coringas, como '%'.
			Se um item come�a com um '-' (tra�o), ent�o este item ser� exclu�do da coleta. Os itens a serem exclu�dos tem uma preced�ncia
			maior do que os itens que devems ser inclu�dos.
			Algumas vari�veis s�o permitidas:
				$[TODOS]	- Indica que todos os waits ir�o ser inclu�dos.
				
			Se esta vari�vel for NULL ou '', ent�o estes waits ser�o exclu�dos:
				LAZYWRITER_SLEEP,RESOURCE_QUEUE,SLEEP_TASK,SLEEP_SYSTEMTASK,SQLTRACE_BUFFER_FLUSH,WAITFOR,LOGMGR_QUEUE,CHECKPOINT_QUEUE
				REQUEST_FOR_DEADLOCK_SEARCH,XE_TIMER_EVENT,BROKER_TO_FLUSH,BROKER_TASK_STOP,CLR_MANUAL_EVENT
				CLR_AUTO_EVENT,DISPATCHER_QUEUE_SEMAPHORE,FT_IFTS_SCHEDULER_IDLE_WAIT,XE_DISPATCHER_WAIT,XE_DISPATCHER_JOIN
				SQLTRACE_INCREMENTAL_FLUSH_SLEEP
				
			O padr�o � NULL.
				
		@TabelaDeDestino
			� o objeto, onde os dados da coleta ser�o salvos. � poss�vel especificar o objeto no formato banco.schema.tabela.
			Se o objeto n�o existir, ele ser� criado.
			Se este par�metro for NULL ou for '', ent�o os dados coletados ser�o exibidos.
			O padr�o � NULL.
			
		@DebugMode
			Exibe op��es calculadas dentro da procedure para fins de debug.
			Nenhuma coleta � realizada.
			O padr�o � 0 (desativado).
				

		HIST�RICO
		Desenvolvedor				Abrevia��o			Data			Descri��o
		Rodrigo Ribeiro Gomes			--				28/11/2011		Cria��o da FUN��O.
********************************************************************************************************************************************/
IF OBJECT_ID('dbo.ColetarInfoWait') IS NOT NULL
	DROP PROCEDURE dbo.ColetarInfoWait;
GO

CREATE PROCEDURE dbo.ColetarInfoWait
(
	 @TempoDeColeta		int				= 1000
	,@IntervaloColeta	varchar(15)		= '00:00:02'
	,@ListaWaits		varchar(max)	= NULL
	,@TabelaDeDestino	varchar(200)	= NULL
	,@DebugMode			bit				= 0
)
AS
--> Par�metros para teste
--DECLARE
--	 @TempoDeColeta		int
--	,@IntervaloColeta	varchar(15)
--	,@ListaWaits		varchar(max)
--	,@TabelaDeDestino	varchar(200)
--	,@DebugMode			bit
	
--SET @TempoDeColeta		= 10000;
--SET @IntervaloColeta	= '00:00:02'
--SET @ListaWaits			= '';
--SET @TabelaDeDestino	= 'tempdb.dbo.ColetaWaits'
--SET @DebugMode			= 0

IF OBJECT_ID('tempdb..#Waits') IS NOT NULL
	DROP TABLE #Waits;
	
DECLARE
	 @FiltroWaits TABLE(WaitType varchar(max))
;

DECLARE
	 @TempoIni		datetime
	,@TempoFinal	datetime
	,@SQLCmd		varchar(600)
;

SET NOCOUNT ON;

--> Validando os valores dos par�metros.
IF @TempoDeColeta IS NULL OR @TempoDeColeta <= 0
	SET @TempoDeColeta = 1000;			--> Default de 1 Segundo.
IF @IntervaloColeta IS NULL
	SET @IntervaloColeta = '00:00:01';	--> Espera 1 segundo.
	
IF @ListaWaits IS NULL OR LEN(@ListaWaits) = 0
	SET @ListaWaits = '$[TODOS],-CLR_SEMAPHORE,-LAZYWRITER_SLEEP,-RESOURCE_QUEUE,-SLEEP_TASK,-SLEEP_SYSTEMTASK,-SQLTRACE_BUFFER_FLUSH,-WAITFOR,-LOGMGR_QUEUE,-CHECKPOINT_QUEUE'+
					',-REQUEST_FOR_DEADLOCK_SEARCH,-XE_TIMER_EVENT,-BROKER_TO_FLUSH,-BROKER_TASK_STOP,-CLR_MANUAL_EVENT'+
					',-CLR_AUTO_EVENT,-DISPATCHER_QUEUE_SEMAPHORE,-FT_IFTS_SCHEDULER_IDLE_WAIT,-XE_DISPATCHER_WAIT,-XE_DISPATCHER_JOIN,-SQLTRACE_INCREMENTAL_FLUSH_SLEEP'
;

/**
	Este trecho � respons�vel por incluir os waits que atende aos filtros da lista informada pelo usu�rio.
	Ele utiliza fun��o Split para converter cada item da lista, em uma linha, para facilitar as opera��es com os itens.
**/
WITH FiltrosWaits AS
(
	--> Convertendo a string em lista!
	SELECT
		RTRIM(LTRIM(S.Item)) as WaitType
	FROM
		dbo.Split(@ListaWaits,',') S
)
,WaitsIncluir AS (
	--> Incluindo os waits que satistafazem os criterios.
	SELECT DISTINCT
		WS.wait_type as WaitType
	FROM
		sys.dm_os_wait_stats WS WITH(NOLOCK)
	WHERE
		EXISTS(SELECT 
					* 
				FROM 
					FiltrosWaits FW 
				WHERE 
					FW.WaitType = '$[TODOS]'
					OR
					WS.wait_type like FW.WaitType 
			)
)
INSERT INTO
	@FiltroWaits(WaitType)
SELECT
	WI.WaitType
FROM
	WaitsIncluir WI
WHERE
	--> Elimina os waits que passam no crit�rio de exclus�o.
	NOT EXISTS (SELECT * FROM FiltrosWaits FW WHERE LEFT(FW.WaitType,1) = '-' AND WI.WaitType LIKE RIGHT(FW.WaitType,LEN(FW.WaitType)-1) )

--> Criando a estrutura da tabela tempor�ria com os waits a serem coletados.
SELECT
	*,GETDATE() as DataColeta
INTO
	#Waits
FROM
	sys.dm_os_wait_stats WS
WHERE
	1 = 2
	
SET @TempoIni = CURRENT_TIMESTAMP;
--> A data obtida aqui � data em que o loop dever� encerrar. Totalizando o tempo escolhido pelo usu�rio
SET @TempoFinal	= DATEADD(ms,@TempoDeColeta,@TempoIni);

IF @DebugMode = 1 BEGIN
	SELECT 'DEBUG ATIVO'

	SELECT * FROM @FiltroWaits ORDER BY WaitType;
	
	SELECT 'Delay',CONVERT(sql_variant,@IntervaloColeta)
	UNION ALL
	SELECT 'Tempo final',CONVERT(sql_variant,@TempoFinal)
	UNION ALL
	SELECT 'Tempo inicial',CONVERT(sql_variant,@TempoIni)
	UNION ALL
	SELECT 'Tempo total em milisegundos',CONVERT(sql_variant,DATEDIFF(ms,@TempoIni,@TempoFinal))
	
	RETURN;
END
	
--> Enquanto o tempo decorrido for menor ou igual ao tempo especificado...
WHILE CURRENT_TIMESTAMP <= @TempoFinal
BEGIN

	RAISERROR('Inserindo dados... ',0,0) WITH NOWAIT;

	INSERT INTO
		#Waits
	SELECT DISTINCT
		 *
		,getDate()
	FROM
		sys.dm_os_wait_stats WS WITH(NOLOCK)
	WHERE
		WS.wait_type IN (SELECT FW.WaitType FROM @FiltroWaits FW)
		
	RAISERROR('Inserido %d linhas',0,0,@@ROWCOUNT) WITH NOWAIT;
	RAISERROR('Aguardando delay de "%s"... ',0,0,@IntervaloColeta) WITH NOWAIT;
	--> Esperando o tempo de coleta.
	WAITFOR DELAY @IntervaloColeta;
END


IF @TabelaDeDestino IS NULL OR (RTRIM(LTRIM(@TabelaDeDestino))) = ''
		SELECT * FROM #Waits ORDER BY wait_type
ELSE BEGIN
	SET @SQLCmd = '
	
		IF OBJECT_ID('+QUOTENAME(@TabelaDeDestino,CHAR(0x27))+') IS NULL BEGIN
			PRINT '+QUOTENAME('A tabela "'+@TabelaDeDestino+'" n�o existia e foi criada!',CHAR(0x27))+'
		
			SELECT 
				*
			INTO
				'+@TabelaDeDestino+' 
			FROM 
				#Waits 	
		END ELSE
			INSERT INTO
				'+@TabelaDeDestino+'
			SELECT 
				* 
			FROM 
				#Waits
	'
	
	EXEC(@SQLCmd)
END
GO