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

Para as votações na Câmara, utilizamos MCMC IRT (Markov Chain Monte Carlo Item Response Theory) para obter o posicionamento, considerando a ausência de dados para todos deputados em todas votações.

Para combinar as quatro medidas, o código segue os seguintes passos:

1. Para cada medida, os partidos são classificados (ranked) com base em sua posição relativa.
2. Esses rankings são então normalizados para uma escala de 1 a 100, onde 1 representa a posição mais à esquerda e 100 a posição mais à direita no espectro político.
3. O posicionamento final de cada partido é determinado pela média aritmética simples dos quatro rankings normalizados.
4. Os partidos são então ordenados com base nessa média e categorizados em grupos no espectro político.

É importante notar que este método preserva a ordem relativa dos partidos em cada medida, mas não leva em conta a magnitude das diferenças entre eles nas medidas originais.

## Interpretando os Resultados

É crucial entender que cada dimensão analisada (migração partidária, frentes parlamentares, coligações eleitorais e votações na Câmara) reflete diferentes aspectos da proximidade entre os partidos. Embora todas essas dimensões sejam influenciadas, em algum grau, pela ideologia política, cada uma também possui suas próprias peculiaridades e é afetada por fatores específicos.

Por exemplo, a participação em frentes parlamentares pode refletir afinidades ideológicas, mas também desejo de visibildiade política e influência legislativa, enquanto as votações na Câmara são frequentemente influenciadas por dinâmicas políticas conjunturais. As migrações partidárias podem ser motivadas tanto por afinidades ideológicas quanto por interesses práticos, e as coligações eleitorais frequentemente equilibram ideologia com estratégia eleitoral.

A combinação dessas diferentes dimensões busca oferecer uma visão mais completa e matizada das proximidades partidárias, capturando tanto as tendências ideológicas quanto as complexidades da prática política.

## Limitações e Considerações

- O método de ranking e normalização usado para combinar as medidas preserva a ordem, mas não a magnitude das diferenças entre os partidos.
- A interpretação dos resultados deve sempre considerar o contexto político mais amplo e as características específicas de cada dimensão analisada.

## Reproduzindo os Resultados

Para reproduzir os resultados deste projeto, siga estas etapas:

1. Clone este repositório.
2. Instale as dependências necessárias. Os pacotes R utilizados estão listados no início de cada script.
3. Execute os scripts na seguinte ordem:
   - `01_migracao_partidaria.R`
   - `02_frentes_parlamentares.R`
   - `03_coligacoes.R`
   - `04_votacoes_deputados.R`
   - `05_juntando_tudo.R`

Cada script gera resultados intermediários que são salvos na pasta dados/interim/resultados/. O script final 05_juntando_tudo.R combina todos os resultados para produzir a classificação final dos partidos.

Note que os scripts fazem download de dados do TSE e da Câmara dos Deputados. Para garantir a reprodutibilidade exata dos resultados apresentados nesta análise, disponibilizamos um arquivo com os dados brutos utilizados na época do estudo. Você pode acessar esses dados através do seguinte [link](https://drive.google.com/file/d/1qubWwJqNr-iVjsXErnzn3DlgSTw_J1mn/view?usp=drive_link)


Ao usar estes dados, você poderá replicar os resultados exatos da análise original. Se optar por baixar dados atualizados diretamente das fontes, os resultados podem variar devido a atualizações nas informações.
