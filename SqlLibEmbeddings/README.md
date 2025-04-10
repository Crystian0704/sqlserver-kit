﻿# Embeddings do SQL Lib

Aproveitando o boom e estudos de AI, resolvi indexar todos esses scripts para que seja fáceis de ser procurados por AI.
Todos os scripts pertinentes a esse projeto, irei colocar aqui nesse diretório, o que servirá como guia!

Como é um projeto público, eu optei por tentar usar o máxio de recursos free ou barato possível.
Portanto, a estrutura do projeto é a seguinte:

- Irei usar o Azure SQL database, que já tem um suporte de vector (tentei usar o FREE Offer mas já nos testes expirou, então peguei por DTU).
- Sempre que este repositório for modificado, ele irá disparar um github action para atualizar o banco
- Um Space no Hugging Face vai me permitir consultar os scripts, conforme texto do usuário, usando algum serviço de LLM.

Com isso, eu consigo usar 100% de tecnologias com muito baixo custo e mantenho todo o código público!

Este diretório contém todos os scripts SQL que irei uar no Azure SQL Database

# Estrutura do Banco 

O banco terá uma tabela chamada Scripts, que irá conter todo o conteúdo dos scrips gerados.
Junto com o conteúdo, irei armazenar o caminho relativo ao root do projeto no GitHub.
E, para finalizar, uma coluna com os embeddings será usada para calcular os embeddings dos scripts.

Com isso, conseguiremos pesquisar usando os recuross de vector do sql!
Como ó esperado é menos de 1000 linhas, o que é relativamente pouco, então, o sql deve atender bem!


Todo o código e ferramenta da pesquisa estão nesse space do Hugging Face: https://huggingface.co/spaces/rrg92/sqlserver-lib-assistant






