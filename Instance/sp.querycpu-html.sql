/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Rapaz... N�o lembrava que tinha feito uma proc dessa.
		Fiz alguns testes e ainda funciona... o html que gera � at� bontinho...
		Se n�o me falha a mem�ria, a ideia era criar uma report f�cil para compartilhar ou reusar, quando necess�rio e enviar para outras pessoas.
		N�o me lembro do quanto usei isso... 
		Mas deixei o c�digo aqui para futuras ideias e melhorias.

*/

USE master
GO

create PROCEDURE dbo.prcProceduresMaisCPUHTMLListar
(
		 @HTMLGerado			NVARCHAR(MAX) OUTPUT
		,@NumProcs				SMALLINT	 = 10
		,@CorFundoLinhaCabec	VARCHAR(MAX) = '#002663'
		,@FonteFaceDados		VARCHAR(MAX) = 'tahoma'
		,@CorFundoClara			VARCHAR(MAX) = '#E0EAF3'
		,@CorFundoEscura		VARCHAR(MAX) = '#EFF4F8'
		,@TamanhoFonteDados		VARCHAR(10)  = '2'
		,@DebugDados			BIT			 = 0
)
AS
/*************************************************************************************
Descri��o	:	Obt�m as procedures/functions que ficaram mais tempo na CPU, de acordo com o top especificado
				e retorna um xml em HTML formatado.
Par�metros	:	
				@HTMLGerado			- Vari�vel OUTPUT que conter� o HTML gerado;	
				@NumProcs			- Indica o n�mero de procedure ou fun��es a buscar.
										Valor padr�o: 10
				@CorFundoLinhaCabec	- Cor da linha de cabe�alho
										Valor padr�o: #002663
				@FonteFaceDados		- Tipo da fonte nas linhas onde os dados v�o aparecer.
										Valor padr�o: tahoma
				@CorFundoClara		- Cor das linhas escuras
										Valor padr�o: #EFF4F8
				@CorFundoEscura		- Cor das linhas claras
										Valor padr�o: #E0EAF3
				@TamanhoFonteDados	- Tamanho da fonte dos dados
										Valor padr�o: 2
				@DebugDados			- Se for 1, ent�o o sistema ir� retornar um resultset com os dados, ao inv�s de retornar o HTML.

HIST�RICO
Desenvolvedor		Data				Abrevia��o		Descri��o
Rodrigo Ribeiro		08/08/2011 18:00	--				Cria��o da PROCEDURE.
*************************************************************************************/

IF OBJECT_ID('tempdb..#RelatorioProc')  IS NOT NULL
	DROP TABLE  #RelatorioProc;

--> Vari�veis para configurar cores,fonte,etc ...
--DECLARE
--	 @CorFundoLinhaCabec	VARCHAR(MAX)
--	,@FonteFaceDados		VARCHAR(MAX)
--	,@CorFundoClara			VARCHAR(MAX)
--	,@CorFundoEscura		VARCHAR(MAX)
--	,@TamanhoFonteDados		VARCHAR(10)
--	,@DebugDados			varchar(200)
--	,@NumProcs				SMALLINT
--	,@HTMLGerado			NVARCHAR(MAX)
--;
--SET @CorFundoLinhaCabec = '#002663' --> Cor da linha de cabe�alho
--SET @FonteFaceDados = 'tahoma' --> Tipo da fonte nas linhas onde os dados v�o aparecer.
--SET @CorFundoEscura	= '#EFF4F8'	--> Cor das linhas escuras
--SET @CorFundoClara	= '#E0EAF3' --> Cor das linhas claras
--SET @TamanhoFonteDados	= '2' --> Tamanho da fonte dos dados
--SET @NumProcs			= 10
--SET @DebugDados			= 0

IF OBJECT_ID('tempdb..#ProcsFuns') IS NOT NULL
	DROP TABLE  #ProcsFuns;

CREATE TABLE #ProcsFuns
  (
     Banco     INT
     ,objectid INT
     ,tipo     VARCHAR(20)
  );

EXEC sp_MSforeachdb '
	USE ?;

	INSERT INTO
		#ProcsFuns
	SELECT
		db_id(),o.object_id,''PROCEDURE''
	FROM
		sys.objects o
	WHERE
		o.type in (''P'')
	UNION ALL
	SELECT
		db_id(),o.object_id,''FUNCAO''
	FROM
		sys.objects o 
	where type in (''TF'',''FN'')
';

--> 10 Mais Lentas
;WITH qTOP AS
(
SELECT TOP (@NumProcs)
	 db_name( st.dbid )											as Banco
	,ISNULL(object_name( st.objectid, st.dbid ),'Ad Hoc')		as Objeto
	,SUBSTRING(
		 CASE WHEN st.text IS NULL THEN '' ELSE st.text END
		,qs.statement_start_offset/2
		,CASE qs.statement_end_offset WHEN -1 THEN LEN( st.text ) ELSE (qs.statement_end_offset- qs.statement_start_offset)/2 END
	)											as Trecho
	,qs.plan_generation_num						as Compilacoes
	,qs.total_worker_time/qs.execution_count	as CPU
	,qs.total_elapsed_time						as TempDec
	,qs.last_execution_time						as UltimaExec
	,qs.max_logical_writes						as Escritas
	,qs.max_logical_reads						as Leituras
FROM
				sys.dm_exec_query_stats qs
	CROSS APPLY	sys.dm_exec_sql_text( qs.sql_handle ) st
	CROSS APPLY sys.dm_exec_query_plan( qs.plan_handle ) qp
    INNER JOIN #ProcsFuns p ON p.banco = st.dbid
                                      AND p.objectid = st.objectid
WHERE
     p.Tipo = 'PROCEDURE'
ORDER BY
	CPU	 DESC
)
SELECT
	 Banco	as BancoNome
	,Objeto
	,Compilacoes
	,CAST(1.00*CPU/1000000 AS DECIMAL(5,2) ) as MediaCPU
--	,Trecho
	,UltimaExec
	,ROW_NUMBER() OVER(ORDER BY CAST(1.00*CPU/1000000 AS DECIMAL(5,2) ) DESC)	 as Ordem
INTO
	#RelatorioProc
FROM
	qTOP


	--> Daqui pra frente nao precisa alterar nada, a menos que voc� saiba o que esteja fazendo.	
	
	IF @DebugDados = 1 BEGIN --> Faz o select na tabela com os dados, e encerra a procedure.
		SELECT
			*
		FROM
			#RelatorioProc
	
		RETURN;
	END

	DECLARE
		@HTMLRelatorio NVARCHAR(MAX)

	SELECT
		--> Gerando a tabela e seus headers.
		@HTMLRelatorio = CAST('<table cellpadding="0" width="100%" align="center" style="table-layout:fixed;word-wrap:break-word">
			<thead>
				<tr align="center" bgcolor="'+@CorFundoLinhaCabec+'">
					<th width="10%"><font size="3" color="#FFFFFF">Banco</font></th>
					<th width="40%"><font size="3" color="#FFFFFF">Objeto</font></th>
					<th width="20%"><font size="3" color="#FFFFFF">Total de compila��es</font></th>
					<th width="15%"><font size="3" color="#FFFFFF">�ltima execu��o</font></th>
					<th width="15%"><font size="3" color="#FFFFFF">M�dia CPU(seg.)</font></th>
				</tr>
			</thead>
			<tbody>
				'+CAST(x.dxml AS NVARCHAR(MAX))+'
			</tbody>
		</table>
		'
		AS NVARCHAR(MAX))
	FROM
	(	--> Gerando A parte do tbody, isto � as tags td e as tags de fonte.
		SELECT
			--> Esta parte configura atributos da tag tr, gerada para cada linha
			 CASE Ordem%2 WHEN 1
				THEN @CorFundoClara
				ELSE @CorFundoEscura  
			END							AS '@bgcolor'
			,'left'					AS '@align'
			--> Este trecho configura o s atributuos da tag fonte e deve ser repetido para cada tag font.
			,@FonteFaceDados	as 'td/font/@face'
			,@TamanhoFonteDados	as 'td/font/@size'
			,BancoNome		as 'td/font',NULL --> Este trecho cria uma tag font, dentro de td. O NULL faz com que a pr�xima coluna seja concatenada dentro do mesma tag tr

			,@FonteFaceDados	as 'td/font/@face'
			,@TamanhoFonteDados	as 'td/font/@size'
			,Objeto			as 'td/font',NULL

			,@FonteFaceDados	as 'td/font/@face'
			,@TamanhoFonteDados	as 'td/font/@size'
			,Compilacoes	as 'td/font',NULL

			,@FonteFaceDados	as 'td/font/@face'
			,@TamanhoFonteDados	as 'td/font/@size'
			,CONVERT(VARCHAR(10),UltimaExec,103)
			  +' '+
			 CONVERT(VARCHAR(12),UltimaExec,114)	as 'td/font',NULL

			,@FonteFaceDados	as 'td/font/@face'
			,@TamanhoFonteDados	as 'td/font/@size'
			,MediaCPU as 'td/font'
		FROM
			#RelatorioProc
		ORDER BY --> Garante que as liinhas vir�o na ordem correta para alterna��o
			Ordem
		FOR XML
			PATH('tr')
	) x(dxml)


SET @HTMLGerado = @HTMLRelatorio