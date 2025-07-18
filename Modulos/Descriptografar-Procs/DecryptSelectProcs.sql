/*#info 

    # Author
		Rodrigo Ribeiro Gomes (adaptado de Paul White https://sqlperformance.com/2016/05/sql-performance/the-internals-of-with-encryption)
        

    # Descri��o 
        Descriptografa todas as procedures criptografadas no banco atual
        O post do Paul White fornece todos os detalhes!
		Antes de usar esse script, crie as fun��es do arquivo fn.Rc4.sql!


		ATEN��O: VOC� DEVE ESTAR CONECTADO COMO DAC! Esse procedimento n�o � oficial Microsoft, use-o por sua pr�pria conta e risco.

			Formas de conectar como dac:
				- Logue na m�quina onde o sql est� instalado
				- no ssms, coloque admin:. ou admin:.\noneinstancia
					- o sqlbrowser deve estar ativo
				- em instancia clusterizadas, o remote admin deve estar habilitado e voc� deve conectar usando o nome virtual

				Mais info sobre o DAC: https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/diagnostic-connection-for-database-administrators?view=sql-server-ver17
			Lembre-se que o DAC � uma conex�o especial de emerg�ncia, ent�o, n�o ocupe-a por muito tempo.
*/

SELECT
	*

	-- Aqui fica clic�vel e f�cil de copiar. Mas se a proc tiver alguns caraceres especiais, pode dar erro de conversao xml
	-- Se der, comenta esse trecho e copia o "text" (se for maior que o limtie do ssms, pode vir cortado. habilite a quebra de linha nas options tamb�m)
	,ProcXML = (
		select
			[processing-instruction(q)] = P.text
		-- Se tiver caracteres especiais no XML, usar replace, ou comentar isso aqui!
		for xml path(''),type
	) 
FROM
	(
		SELECT
			*
			,RC4K = CONVERT(binary(20),HASHBYTES('SHA1', DBGuid + ObjectID + SubID))
		FROM
			(
				SELECT
					DBGuid		= convert(binary(16),convert(uniqueidentifier,DRS.family_guid))
					,ObjectID	= convert(binary(4),reverse(convert(binary(4),convert(int,OV.objid))))
					,SubID		= convert(binary(2),reverse(convert(binary(2),convert(smallint,OV.subobjid))))
					,OV.imageval
				FROM
					sys.database_recovery_status DRS
					CROSS JOIN
					sys.sysobjvalues OV
				WHERE
					DRS.database_id = DB_ID()
					AND
					OV.valclass = 1
					AND

					-- aqui voce pode filtrar procs especifica se preferir!
					OV.objid in (
						select id From sys.syscomments  where encrypted = 1
					)
			) O
	) K
	CROSS APPLY (
		SELECT 
			text = CONVERT(nvarchar(max),master.dbo.sp_fnEncDecRc4(RC4K,imageval))
	) P(text)