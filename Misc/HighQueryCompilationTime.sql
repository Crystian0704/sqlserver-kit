/*#info 
	# Autor 
		Fabiano Amorim (https://blogfabiano.com/)

	# Descricao 
		Esta � uma query que o Fabiano Amorim fez para simular um cen�ro de alta tempo de compiala��o.
        Voc� pode querer simular isso para testar alguma feature do sql ou cen�rios de como seu ambiente vai responder a esse tipo de processamento

        IMPORTANTE: Evite rodar isso em produ��o, pois pode causar muito impacto nas suas queries.
        Isso � para demos e ambientes de testes

        Geralmente, esse tipo de query rodando em paralelo, em v�rias sess�e, 
        voc� vai waits como RESOURCE_SEMAPHORE_QUERY_COMPILE e pode ver muita CPU alta junto,
        pois uma parte de queries estar� moendo CPU, equanto compila e a outra em wait esperando 
        pra poder compilar (o sql tem um limite de queries que podem compilar ao mesmo tempo, baseado no consumo de mem�ria, etc.)

        Ele tamb�m deixou uma estimativa de tempo at� determinado JOIN.
        Por exemplo, se quiser 1 segundo de compile time, comente do 5 join em didante (Deixando apenas os 4 primeiros).
        Obviamente, depende de cada m�quina, e voc� precisar� testar e observar o valor mais pr�ximo.

        E de quebra, ele deixou tamb�m algums Trace flags para voc� debugar o processo.
        Voc� poe comentar essa parte se n�o quiser ver detalhes ou se apens o tempo interessar.



        Obrigado Fabiano <3, essa query � muito boa!
*/


-- dbcc freeproccache
SET STATISTICS TIME ON
;WITH cte AS
(
  SELECT objects.* 
    FROM sys.objects
   INNER JOIN sys.indexes
      ON indexes.object_id = objects.object_id
   INNER JOIN sys.index_columns
      ON index_columns.object_id = indexes.object_id
     AND index_columns.index_id = indexes.index_id
   INNER JOIN sys.columns
      ON columns.object_id = index_columns.object_id
     AND columns.column_id = index_columns.column_id
)
SELECT TOP 100 *
FROM sys.objects
INNER JOIN cte AS cte1 ON objects.name = cte1.name /* compile time = 41ms */
INNER JOIN cte AS cte2 ON objects.name = cte2.name /* compile time = 125ms */ 
INNER JOIN cte AS cte3 ON objects.name = cte3.name /* compile time = 375ms */
INNER JOIN cte AS cte4 ON objects.name = cte4.name /* compile time = 1091ms */
INNER JOIN cte AS cte5 ON objects.name = cte5.name /* compile time = 3630ms */
INNER JOIN cte AS cte6 ON objects.name = cte6.name /* compile time = 7885ms */
INNER JOIN cte AS cte7 ON objects.name = cte7.name /* compile time = 19651ms */
INNER JOIN cte AS cte8 ON objects.name = cte8.name /* compile time = 35806ms */
INNER JOIN cte AS cte9 ON objects.name = cte9.name /* compile time = 67759ms */
INNER JOIN cte AS cte10 ON objects.name = cte10.name /* compile time = 120355ms */
OPTION
(
    RECOMPILE
    , QUERYTRACEON 3604
    , QUERYTRACEON 8675 /* Show optimization stage */
    --, QUERYTRACEON 8780 /* Disable timeout, uncomment this if you want it to get even worse...*/
)
SET STATISTICS TIME OFF
GO