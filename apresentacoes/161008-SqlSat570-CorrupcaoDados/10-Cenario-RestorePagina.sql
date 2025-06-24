/*#info 

	# Author 
		Gustavia Maia Aguiar (https://www.linkedin.com/in/gustavo-maia-aguiar-92a159a4/|https://gustavomaiaaguiar.wordpress.com/|)
		Rodrigo Ribeiro Gomes (https://iatalk.ing)

	# Detalhes 
		Este script � parte da demo sobre corrup��o de dados no SQL Server.
*/



-- Restaurando a base ORIGINAL!!
	USE master 
	GO
	IF DB_ID('DbCorrupt') IS NOT NULL
	BEGIN
		EXEC('ALTER DATABASE DbCorrupt SET READ_ONLY WITH ROLLBACK IMMEDIATE')
		EXEC('DROP DATABASE DbCorrupt')
	END

	RESTORE DATABASE DBCorrupt
	FROM DISK = 'T:\DbCorrupt.bak'
	WITH
		REPLACE
		,STATS = 10
		--,MOVE 'DBCorrupt' TO 'C:\temp\DBCorrupt.mdf'
		--,MOVE 'DBCorrupt_log' TO 'C:\temp\DBCorrupt.ldf'

-- Para o restore de p�gina funcionar a base dever� estar em recovery model FULL
	ALTER DATABASE DBCorrupt SET RECOVERY FULL;

-- Vamos criar um BACKUP (SEMPRE FA�A BACKUP)
	BACKUP DATABASE DBCorrupt 
	TO DISK = 'T:\DBCorrupt_FULL.bak' 
	WITH STATS=10,INIT,FORMAT;

--> Vamos consultar a segunda linha da tabela!
	SELECT * FROM DBCorrupt.DBO.Lancamentos 
	WHERE DataLancamento = '20150101' 
	AND NumConta=9999 AND Seq=1

--> Vamos atualizar ela
	UPDATE DBCorrupt.DBO.Lancamentos SET Valor = Valor/2 
	WHERE DataLancamento = '20150101' 
		AND NumConta=9999 AND Seq=1

-- Faz um Backup de LOG!!
	BACKUP LOG DBCorrupt 
	TO DISK = 'T:\DBCorrupt_LOG_1.trn' 
	WITH INIT,FORMAT,STATS=10;

-- Corrompendo uma p�gina!

-- Vamos obter todas as p�ginas da tabela!
-- Page Types: Escolher a segunda linha (primeira data page)
	-- DBCC IND('DBCorrupt','Lancamentos',1)
	 -- ou (2012+)
	select top 100 allocated_page_page_id,page_type_desc from DbCorrupt.sys.dm_db_database_page_allocations(db_id('DbCorrupt'),object_id('DbCorrupt.dbo.Lancamentos'),1,null,'detailed')
	where page_type_desc = 'DATA_PAGE' and previous_page_page_id is null
	order by allocated_page_page_id




-- Usando dbcc writepage para simular corrup��o!
-- help: dbcc WRITEPAGE ({'dbname' | dbid}, fileid, pageid, offset, length, data [, directORbufferpool])
	--Corrompendo a primeira linha (96 bytes ap�s o header)
	ALTER DATABASE DBCorrupt SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DBCC WRITEPAGE('DBCorrupt',1,360,'m_pageId',6,0x000000000000,0)
	ALTER DATABASE DBCorrupt SET MULTI_USER WITH ROLLBACK IMMEDIATE;
	checkpoint; dbcc dropcleanbuffers;

--> Verificando a prova do crime...
	EXEC xp_readerrorlog	-- procurar por: is modifying bytes

--> Vamos ler a segunda linha!
	SELECT * FROM DBCorrupt.DBO.Lancamentos 
	WHERE DataLancamento = '20150101' 
	AND NumConta=9999 AND Seq=1

	-- Erro 824? Confirmando na suspect_pages..
	-- S� registra quando a p�gina � usada...
		SELECT * FROM msdb..suspect_pages
		ORDER BY last_update_date DESC;
	
--> Como reparar sem restaurar o banco inteiro?
		
-- Restaurar o FULL!
	RESTORE DATABASE
		DBCorrupt PAGE = '1:360' -- ajustar num pagina
	FROM
		DISK = 'T:\DBCorrupt_FULL.bak'
	WITH
		NORECOVERY


--> Restore de Page na edi��o ENTERPRISE � feito ONLINE! 
-- Voc� consegue usar a base enquanto restaura!
	SELECT TOP(1) * FROM DBCorrupt.dbo.Lancamentos 
	ORDER BY DataLancamento DESC

	--> Exceto acessar aquela p�gina...!
	SELECT * FROM DBCorrupt.DBO.Lancamentos 
	WHERE DataLancamento = '20150101' 
	AND NumConta=9999 AND Seq=1

-- Restaurando o backup de log j� existente...
	RESTORE LOG DBCorrupt
	FROM DISK = 'T:\DBCorrupt_LOG_1.trn'
	WITH
		NORECOVERY

--> E agora, conseguimos acessar a p�gina?
	SELECT * FROM DBCorrupt.DBO.Lancamentos 
	WHERE DataLancamento = '20150101' 
	AND NumConta=9999 AND Seq=1

--> Ainda precisamos do LOG ATUAL 
-- pra garantir o lsn...

-- Faz BACKUP do LOG atual!!!
	BACKUP LOG DBCorrupt
	TO DISK = 'T:\DBCorrupt_LOG_2.trn'
	WITH INIT,FORMAT,STATS=10

-- Restaurando o �ltimo log... 
	RESTORE LOG DBCorrupt
	FROM DISK = 'T:\DBCorrupt_LOG_2.trn'
	WITH RECOVERY

--> E agora, conseguiremos executar
-- aquele SELECT anterior?
	SELECT * FROM DBCorrupt.DBO.Lancamentos 
	WHERE DataLancamento = '20150101' 
	AND NumConta=9999 AND Seq=1