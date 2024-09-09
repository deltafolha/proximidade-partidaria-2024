# Espectro Político-Partidário Brasileiro em 2024

## Sobre o Projeto

Este projeto visa analisar e quantificar a proximidade dos partidos políticos brasileiros em diferentes dimensões, utilizando dados públicos. A análise busca capturar as relações entre os partidos em várias esferas de atuação política, fornecendo uma visão multidimensional das proximidades partidárias.

## Metodologia

Utilizamos quatro fontes principais de dados para nossa análise:

1. **Migração Partidária**: Analisamos os padrões de mudança de partido entre os políticos usando dados do TSE para as eleições de 2020 e 2024.

2. **Frentes Parlamentares**: Examinamos a participação dos partidos em diferentes frentes temáticas na Câmara dos Deputados da 57ª legislatura.

3. **Coligações Eleitorais**: Observamos as alianças formadas pelos partidos nas eleições municipais de 2024, utilizando dados do TSE.

4. **Votações na Câmara**: Analisamos o padrão das votações dos deputados de acordo com o partido, usando dados da Câmara dos Deputados.

Para as três primeiras fontes, aplicamos a técnica de Análise de Correspondência (CA) para reduzir a dimensionalidade dos dados e extrair as principais tendências de posicionamento dos partidos.

Para as votações na Câmara, utilizamos MCMC IRT (Markov Chain Monte Carlo Item Response Theory) para obter o posicionamento, considerando a ausência de dados em votações e a natureza binária dos dados.

Para combinar as quatro medidas, o código segue os seguintes passos:

1. Para cada medida, os partidos são classificados (ranked) com base em sua posição relativa.
2. Esses rankings são então normalizados para uma escala de 1 a 100, onde 1 representa a posição mais à esquerda e 100 a posição mais à direita no espectro político.
3. O posicionamento final de cada partido é determinado pela média aritmética simples dos quatro rankings normalizados.
4. Os partidos são então ordenados com base nessa média e categorizados em grupos no espectro político.

É importante notar que este método preserva a ordem relativa dos partidos em cada medida, mas não leva em conta a magnitude das diferenças entre eles nas medidas originais.

## Interpretando os Resultados

É crucial entender que cada dimensão analisada (migração partidária, frentes parlamentares, coligações eleitorais e votações na Câmara) reflete diferentes aspectos da proximidade entre os partidos. Embora todas essas dimensões sejam influenciadas, em algum grau, pela ideologia política, cada uma também possui suas próprias peculiaridades e é afetada por fatores específicos.

Por exemplo, a participação em frentes parlamentares pode refletir afinidades ideológicas, mas também desejo de visibildiade política e influência legislativa, enquanto as votações na Câmara são frequentemente influenciadas por dinâmicas políticas conjunturais. As migrações partidárias podem ser motivadas tanto por afinidades ideológicas quanto por interesses práticos individuais, e as coligações eleitorais frequentemente equilibram ideologia com estratégia eleitoral.


## Limitações e Considerações

- O método de ranking e normalização usado para combinar as medidas preserva a ordem, mas não a magnitude das diferenças entre os partidos.
- A interpretação dos resultados deve sempre considerar o contexto político mais amplo e as características específicas de cada dimensão analisada.

## Reproduzindo os Resultados

1. Clone o repositório:

```
git clone https://github.com/deltafolha/proximidade-partidaria-2024.git
``` 

3. Vá para a pasta da análise
``` 
cd proximidade-partidaria-2024/
``` 

2. No R instale os pacotes que vamos utilizar:

```
packages <- c("dplyr", "stringr", "purrr", "data.table", "tidyr", "tibble", 
              "ca", "magrittr", "glue", "rvest", "jsonlite", "httr", "lubridate", 
              "MCMCpack", "scales")
install.packages(packages)

```

3. (opcional). Caso queira reproduzir os dados da matéria, e não atualizar a  análise com dados mais atuais, baixe os dados brutos utilizados na época

```
pip install gdown
mkdir ./dados/
gdown 1qubWwJqNr-iVjsXErnzn3DlgSTw_J1mn -O ./dados/brutos.zip
unzip ./dados/brutos.zip -d ./dados/
```

altere a seguinte linha presente nos códigos `02_frentes_parlamentares` e `04_votacoes_deputados`:

de 

```
baixar_novos_dados <- TRUE
``` 

para 

```
baixar_novos_dados <- FALSE
```

4. Execute os scripts presentes na pasta `codigos` pela ordem:

```
Rscript codigos/01_migracao_partidaria.R
Rscript codigos/02_frentes_parlamentares.R
Rscript codigos/03_coligacoes.R
Rscript codigos/04_votacoes_deputados.R
Rscript codigos/05_juntando_tudo.R
```

Após isso será criado a tabela `dados/processado/tabela_final.csv` com os seguintes dados:


|partido       | migracao| frentes| coligacao| votacao| migracao_rank| frentes_rank| coligacao_rank| votacao_rank| media_rank|label      |
|:-------------|--------:|-------:|---------:|-------:|-------------:|------------:|--------------:|------------:|----------:|:----------|
|PSTU          |   -41.73|      NA|     -7.14|      NA|          1.00|           NA|           1.00|           NA|       1.00|esquerda_1 |
|UP            |       NA|      NA|     -6.39|      NA|            NA|           NA|           4.67|           NA|       4.67|esquerda_1 |
|PSOL          |    -9.28|   -2.33|     -2.92|   -1.24|          4.96|         1.00|          12.00|        11.42|       7.35|esquerda_1 |
|PCB           |       NA|      NA|     -5.96|      NA|            NA|           NA|           8.33|           NA|       8.33|esquerda_2 |
|PT            |    -2.57|   -1.95|     -1.63|   -1.54|         16.84|         6.21|          19.33|         1.00|      10.85|esquerda_2 |
|PC do B       |    -3.29|   -1.87|     -1.63|   -1.47|          8.92|        11.42|          19.33|         6.21|      11.47|esquerda_2 |
|REDE          |    -2.74|   -1.32|     -2.92|   -1.24|         12.88|        16.63|          12.00|        16.63|      14.54|esquerda_2 |
|PV            |    -0.56|   -0.91|     -1.63|   -1.18|         28.72|        21.84|          19.33|        21.84|      22.93|esquerda_3 |
|PSB           |    -0.75|   -0.72|     -0.16|   -0.86|         24.76|        27.05|          30.33|        27.05|      27.30|esquerda_3 |
|PDT           |    -0.99|   -0.51|      0.00|   -0.80|         20.80|        32.26|          34.00|        32.26|      29.83|esquerda_3 |
|SOLIDARIEDADE |     0.04|   -0.21|      0.35|   -0.31|         40.60|        37.47|          45.00|        47.89|      42.74|centro_1   |
|AVANTE        |    -0.19|    0.00|      0.45|   -0.36|         32.68|        53.11|          48.67|        37.47|      42.98|centro_1   |
|PSD           |     0.12|    0.17|      0.30|   -0.27|         52.48|        58.32|          41.33|        53.11|      51.31|centro_2   |
|MDB           |     0.09|    0.23|      0.26|   -0.22|         48.52|        63.53|          37.67|        58.32|      52.01|centro_2   |
|MOBILIZA      |    -0.08|      NA|      0.60|      NA|         36.64|           NA|          70.67|           NA|      53.65|centro_2   |
|PMB           |     0.09|      NA|      0.67|      NA|         44.56|           NA|          74.33|           NA|      59.45|centro_3   |
|PODE          |     0.41|    0.28|      0.58|   -0.33|         72.28|        68.74|          59.67|        42.68|      60.84|centro_3   |
|PP            |     0.14|    0.37|      0.49|   -0.17|         56.44|        79.16|          52.33|        63.53|      62.86|centro_3   |
|AGIR          |     0.20|      NA|      0.59|      NA|         60.40|           NA|          67.00|           NA|      63.70|centro_3   |
|REPUBLICANOS  |     0.35|    0.36|      0.52|   -0.12|         68.32|        73.95|          56.00|        68.74|      66.75|direita_1  |
|CIDADANIA     |     0.25|    0.00|      0.78|    0.06|         64.36|        47.89|          81.67|        84.37|      69.57|direita_1  |
|PSDB          |     0.60|   -0.07|      0.78|    0.02|         88.12|        42.68|          85.33|        73.95|      72.52|direita_1  |
|UNIÃO         |     0.56|    0.43|      0.58|    0.03|         84.16|        84.37|          63.33|        79.16|      77.75|direita_2  |
|DC            |     0.41|      NA|      0.79|      NA|         76.24|           NA|          89.00|           NA|      82.62|direita_2  |
|PRD           |     0.47|    0.46|      0.74|    0.30|         80.20|        89.58|          78.00|        89.58|      84.34|direita_2  |
|PRTB          |     1.15|      NA|      0.94|      NA|         96.04|           NA|          92.67|           NA|      94.35|direita_3  |
|PL            |     0.69|    1.16|      1.08|    1.51|         92.08|        94.79|          96.33|        94.79|      94.50|direita_3  |
|NOVO          |     1.51|    1.21|      1.39|    1.54|        100.00|       100.00|         100.00|       100.00|     100.00|direita_3  |






