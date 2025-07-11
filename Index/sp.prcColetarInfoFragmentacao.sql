/*#info 

	# Autor 
		Luciano Caixeta Moreira (Luti) e Rodrigo Ribeiro Gomes
	
	# Descri��o 
		Em um per�odo que trabalhei como Luti, fizemos essa proc para alguma rotina.
		N�o lembro se chegamos a usar, mas uma r�pida olhada no script parece estar pronta.
		Creio que hoje h� rotinas melhores para essa coleta, mas deixo aqui para futuras refer�ncias.


*/

/********************************************************************************************************************************************
	Autor: Luciano Caixeta Moreira
	Data cria��o: 31/08/2011
	Descri��o:
	
	�ltima atualiza��o: 
	Respons�vel �ltima atualiza��o:
	
	Hist�rico de altera��es:	
		Rodrigo Ribeiro Gomes	- Revis�o/Finaliza��o do script.

	Descri��o
		Salva as informa��es de fragmenta��o, retornadas pela fun��o 'sys.dm_db_index_physical_stats', em uma tabela, ou apenas exibe-as.
		Quando a op��o de salvar em tabela for escolhida, deve se tomar cuidado com a vers�o do SQL, pois dependendo da mesma, as colunas
		podem mudar.
		Al�m de salvar os dados retornados pela fun��o, a procedure ir� salvar a data em que a coleta foi realizada, e este valor ser�
		o mesmo todas as linhas inseridas, a cada chamada da procedure.
	Depend�ncias
		Tabelas/Views:
			#1 - sys.tables
			#2 - sys.indexes
			#3 - sys.partitions
		Fun��es/Procedures
			#1 - sys.dm_db_index_physical_stats
		Refer�ncias
			#1 - http://msdn.microsoft.com/en-us/library/ms188917.aspx (Consulte outras vers�es se necess�rio.)
		Comandos
			Nenhuma
			
	Vers�es suportadas
		SQL Server 2005
		SQL Server 2008 (inclusive R2)
		
	Par�metros
		@BancoDados
			� o banco de dados do qual se deseja obter os dados. Se NULL for especificado, ent�o todos os bancos
			ser�o consultados.
				
		@TabelaDestino
			� a tabela para onde jogar os dados. A estrutura dessa tabela depende da vers�o do SQL.
			Se a tabela n�o existir, o a procedure ir� criar a mesma, com a estrutura de acordo com a vers�o do SQL em que a mesma est� sendo executada.
			Se este par�metro for NULL, ent�o a procedure apenas ira exibir os resultados.
			
		@NomeEsquema
			Se for especificado um valor diferente de NULL, ent�o somente as tabelas desse schema ser�o inclu�das na pesquisa.
			Se NULL for especificado, todos os schemas ser�o considerados.
			
		@NomeObjeto
			� o nome da tabela que se deseja buscar os dados de fragmenta��o.
			Se NULL for passado, ent�o todas as tabelas ser�o consideradas.
			
		@IndexID
			� o ID do indice cujo os dados de fragmenta��o ser�o obtidos.
			Se NULL for especificado, ent�o todos os �ndices ser�o consultados. (De cada tabela.)
			
		@PartitionNumber
			� o n�mero da parti��o a ser filtrado. Se NULL for especificado, todas as parti��es ser�o consideradas.
			
		@FonteInfoTabelas
			� o nome da tabela que cont�m as meta-informa��es das tabelas existentes.
			Para evitar processamento extra na busca das informa��es de certas tabelas, voc� pode usar este par�metro.
			Se j� possuir uma tabela com os dados das tabelas requeridas, basta especificar a query no par�metro.
			Voc� pode espeficiar qualquer comando que possa ser usado dentro de uma expressao de tabela.
			Se o par�metro for NULL, a procedure consulta as tabelas 'sys.tables','sys.indexes' e 'sys.partitions' para
			obter as tabelas necess�rias.
			A estrutura da expressao de tabela, inclusive nomes de colunas, deve ser a seguinte:
				Nome				Tipo		Descri��o
				DatabaseID			int			O ID do banco de dados!
				ObjectID			int			O ID do objeto!
				NomeTabela			sysname		O nome da tabela
				SchemaName			sysname		O nome do schema da tabela.
				IndexID				int			O ID do �ndice.
				PartitionNumber		int			o ID da parti��o a qual o �ndice da tabela pertence.
				
			
		@Modo
			� o modo de pesquisa a ser usado na fun��o 'sys.dm_db_index_physical_stats'.
			O valor padr�o � LIMITED.
			
		HIST�RICO
		Desenvolvedor				Abrevia��o			Data			Descri��o
		Rodrigo Ribeiro Gomes			--				25/11/2011		Cria��o da PROCEDURE.
********************************************************************************************************************************************/
IF OBJECT_ID('proc_ColetarInfoFragmentacao') IS NOT NULL
	DROP PROCEDURE proc_ColetarInfoFragmentacao;
GO

CREATE PROCEDURE  proc_ColetarInfoFragmentacao
(
	 @BancoDados		varchar(100)	= NULL
	,@TabelaDestino		varchar(100)	= NULL
	,@NomeEsquema		varchar(100)	= NULL
	,@NomeObjeto		varchar(100)	= NULL
	,@IndexID			int				= NULL
	,@PartitionNumber	int				= NULL
	,@FonteInfoTabelas	varchar(3000)	= NULL
	,@Modo				varchar(20)		= 'LIMITED'
)
AS
BEGIN
	--> Par�metros para teste
	--DECLARE
	--	 @BancoDados		varchar(100)	= NULL
	--	,@TabelaDestino		varchar(100)	= NULL
	--	,@NomeEsquema		varchar(100)	= NULL
	--	,@NomeObjeto		varchar(100)	= NULL
	--	,@IndexID			int				= NULL
	--	,@PartitionNumber	int				= NULL
	--	,@FonteInfoTabelas	varchar(100)	= NULL
	--	,@Modo				varchar(20)		= 'LIMITED'
		
	--> Recursos Necess�rios

	---------- RECURSOS ----------
	-- Tabelas tempor�rias
	IF OBJECT_ID('tempdb..#InfoTabelasBD') IS NOT NULL
		DROP TABLE #InfoTabelasBD;
		
	/** Esta tabela ir� conter os dados das tabelas (parti��es e �ndices) cujo 
	a informa��o de fragmenta��o devera ser obtida. **/
	CREATE TABLE
	#InfoTabelasBD
	(
		 OrdemSeq			int IDENTITY CONSTRAINT pkInfoTabelaBD PRIMARY KEY
		,DatabaseID			int
		,ObjectID			int
		,IndexID			int
		,PartitionNumber	int
	);
		
	--> Esta tabela conter� o resultado da coleta, caso seja necess�rio.
	IF OBJECT_ID('tempdb..#IPS') IS NOT NULL
		DROP TABLE #IPS;

	-- Vari�veis
	DECLARE
		 @Comando_SQL			nvarchar(max)
		,@FonteTabelasInfo_SQL	nvarchar(max)
		,@colDatabaseID			int
		,@colObjectID			int
		,@colIndexID			int
		,@colPartitionNumber	int
		,@colOrdemSeq			int
		,@DataColeta			datetime
		,@MostrarColeta			bit
		
	---------- SCRIPTING ----------
	 --> Colocando a data de coleta em um vari�vel para ser a mesma para todos os inserts feitos.
	SET @DataColeta = GETDATE();

	--> Verificando se a coleta deve ser exibida.
	SET @MostrarColeta = 0;
	IF @TabelaDestino IS NULL
		SET @MostrarColeta = 1;
		

	--> Se for NULL atribui a ?, pois esta vari�vel ser� usada junto com a procedure sp_MSforeachdb.
	IF @BancoDados IS NULL	--> Se for NULL atribui a ?, pois esta vari�vel ser� usada junto com a procedure sp_MSforeachdb.
		SET @BancoDados = '?';
		
	/** A fonte de informa��es de tabelas � uma query que a procedure usar�
	para obter as informa��es das tabelas. Se o usu�rio j� tiver uma tabela com essas informa��es
	dever� especificar o nome, caso contr�rio deve deixar o par�metro '@FonteInfoTabelas' como NULL, para que a procedure
	busque essas informa��es das tabelas do sistema. **/
	IF @FonteInfoTabelas IS NULL	
		--> O usu�rio nao informou uma fonte, ent�o a query abaixo ser� usada!
		SET @FonteTabelasInfo_SQL = N'SELECT DISTINCT
									 DB_ID()			AS	DatabaseID
									,T.object_id		AS	ObjectID
									,T.name				AS	NomeTabela
									,S.name				AS	SchemaName
									,I.index_id			AS	IndexID
									,P.partition_number	AS	PartitionNumber
								FROM
												sys.tables		T	WITH(NOLOCK)
									INNER JOIN	sys.indexes		I	WITH(NOLOCK)	ON	I.object_id = T.object_id
									INNER JOIN	sys.schemas		S	WITH(NOLOCK)	ON	S.schema_id	= T.schema_id
									INNER JOIN	sys.partitions	P	WITH(NOLOCK)	ON	P.object_id = T.object_id
																					AND P.index_id	= I.index_id'
	ELSE BEGIN
		--> Montando o comando a ser usado.
		SET @FonteTabelasInfo_SQL = 'SELECT * FROM '+@FonteInfoTabelas;
	END

	/** Este � o comando SQL que ir� inserir os dados das tabelas (de todos os bancos ou n�o)
	na tabela tempor�ria #InfoTabelasBD. A query abaixo ser� executada na procedure sp_MSforeacdb.
	o IF serve para impedir que a query seja executada para outros bancos, quando um banco especifico for informado.
	A l�gica do IF � a seguinte:
		IF DB_NAME() NOT IN ('NomeBanco') AND @NomeBanco <> '?'
			RETURN;
	O INT � utilizado para futuras altera��o que envolvam uma lista de bancos que n�o ser�o permitidos!**/
	SET @Comando_SQL = N'
		USE '+@BancoDados+N'

		-- Verifica se o banco do loop atual deve ser considerado. (? = Se a vari�vel @Bancos)
		IF DB_NAME() NOT IN ('+QUOTENAME(@BancoDados,CHAR(0x27))+N') AND '+QUOTENAME(@BancoDados,NCHAR(0x27))+N' <> '+QUOTENAME(N'?',NCHAR(0x27))+N'
			RETURN;

		INSERT INTO
			#InfoTabelasBD(DatabaseID,ObjectID,IndexID,PartitionNumber)
		SELECT
			  D.DatabaseID
			 ,D.ObjectID
			 ,D.IndexID
			 ,D.PartitionNumber
		FROM
			(
				'+@FonteTabelasInfo_SQL+'
			) D
		WHERE
			1 = 1 --> Coloquei este para n�o precisar fazer verifica��es de AND
			'+COALESCE('AND D.NomeTabela = '+QUOTENAME(@NomeObjeto,NCHAR(0x27)),N'')+N'
			'+COALESCE('AND D.SchemaName = '+QUOTENAME(@NomeEsquema,NCHAR(0x27)),N'')+N'
			'+COALESCE('AND D.IndexID = '+CONVERT(varchar(5),@IndexID),'')+N'
			'+COALESCE('AND D.PartitionNumber = '+CONVERT(varchar(5),@PartitionNumber),'')+N'
	'
	EXEC sp_MSforeachdb @Comando_SQL;

	--> Inicializando
	SET @colOrdemSeq	= 0;
	SET @colDatabaseID	= 0;

	--> Se a procedure deve retornar os dados, ent�o inicializa a tabela que conter� os mesmos.
	IF @MostrarColeta = 1 BEGIN
		SELECT 
			*,@DataColeta as DataColeta
		INTO
			#IPS
		FROM 
			sys.dm_db_index_physical_stats(NULL,NULL,NULL,NULL,NULL)
		WHERE
			1 = 2;
			
		SET @TabelaDestino = '#IPS';
	END ELSE BEGIN
		IF OBJECT_ID(@TabelaDestino) IS NULL BEGIN --> Se a tabela n�o existe, ent�o a cria.
			SET @Comando_SQL = N'
				SELECT 
					*,@DataColeta as DataColeta
				INTO
					'+@TabelaDestino+N'
				FROM 
					SYS.dm_db_index_physical_stats(NULL,NULL,NULL,NULL,NULL)
				WHERE
					1 = 2;
			'
			
			EXEC sp_executesql @Comando_SQL,N'@DataColeta datetime',@DataColeta;
		END
	END

	WHILE EXISTS
	(
		SELECT
			 *
		FROM 
			#InfoTabelasBD IT
		WHERE
			IT.OrdemSeq > @colOrdemSeq
	)
	BEGIN

		SELECT TOP 1
			 @colOrdemSeq			= IT.OrdemSeq
			,@colDatabaseID			= IT.DatabaseID
			,@colObjectID			= IT.ObjectID
			,@colIndexID			= IT.IndexID
			,@colPartitionNumber	= IT.PartitionNumber
		FROM 
			#InfoTabelasBD IT
		WHERE
			IT.OrdemSeq > @colOrdemSeq
		ORDER BY
			IT.OrdemSeq ASC
		
		
		SET @Comando_SQL = N'
			INSERT INTO
				'+@TabelaDestino+'
			SELECT 
				*
				,@DataColeta 
			FROM 
				sys.dm_db_index_physical_stats
				('+CONVERT(varchar(10),@colDatabaseId)+N'
				,'+CONVERT(varchar(10),@colObjectId)+N'
				,'+CONVERT(varchar(10),@colIndexId)+N'
				,'+CONVERT(varchar(10),@colPartitionNumber)+N'
				,@Modo
				)
			;
		'
		
		EXECUTE sp_executesql @Comando_SQL,N'@DataColeta datetime, @Modo varchar(20)',@DataColeta, @Modo;

	END

	IF @MostrarColeta = 1
		SELECT * FROM #IPS;
	
END