# pacotes -----------------------------------------------------------------
library(dplyr)
library(glue)
library(rvest)
library(stringr)
library(purrr)
library(magrittr)
library(tibble)
library(tidyr)
library(ca)

# variavies ---------------------------------------------------------------
dir_resultado <- "dados/interim/resultados/"
dir_frentes <- "dados/interim/frentes/"

# baixa dados das frentes -------------------------------------------------

# Página principal com o índice das frentes nessa legislatura
html_main <- "https://www.camara.leg.br/internet/deputado/frentes.asp?leg=57" %>% 
  read_html()

# IDs das frentes
id_frentes <- html_main %>% 
  html_nodes("a") %>% 
  html_attr("href") %>% 
  keep(str_detect, "frenteDetalhe") %>% 
  str_remove(".*=")

# Vai para a página da cada frente e baixa a lista de parlamentares
# presentes nelas
n_frentes <- length(id_frentes)
# Lista que vai receber as tabelas
tabelas_frentes <- vector("list", n_frentes)
for(i_frente in seq_len(n_frentes)){
  cat("   |- Frente:", i_frente, "/", n_frentes, "\n")
  id <- id_frentes[i_frente]
  path_frente <- glue("{dir_frentes}/{id}.csv")
  if(file.exists(path_frente)) next
  url_frente <- glue("https://www.camara.leg.br/internet/deputado/", 
                     "frenteDetalhe.asp?id={id}")
  html <- url_frente %>% 
    read_html()
  nome_frente <- html %>% 
    html_node("h3") %>%
    html_text()
  html %>% 
    html_table() %>% 
    extract2(1) %>% 
    mutate(frente_nome = nome_frente) %>% 
    mutate(frente_id = id) %>% 
    write.csv(path_frente, row.names = FALSE)
}


# junta e formata ---------------------------------------------------------

# Juntas asa tabelas. 
# No fim vamos ter uma tabela de parlamentares e seus partidos e das frentes que
# participam
frentes <- tabelas_frentes %>% 
  bind_rows()

# 1. Remove parlamentar sem partido e a linha que diz o total de parlamentares
# 2. Tabula a quantidade de parlamenatar por partido em cada frente
partidos_por_frente <- frentes %>% 
  filter(!str_detect(Partido, "Total: \\d+")) %>%
  filter(Partido != "S.PART.") %>% 
  group_by(frente_id, Partido, frente_nome) %>% 
  summarise(n = n()) %>% 
  ungroup()

# Faz a matriz com a frequência de partidos nas frentes
ca_data <-  partidos_por_frente %>% 
  select(-frente_nome) %>% 
  pivot_wider(names_from = frente_id, values_from = n, values_fill = 0) %>% 
  column_to_rownames("Partido") %>% 
  as.matrix()

# Análise
ca_result <- ca(ca_data)

# Resultado
resultado_d1_linhas <- ca_result %>%
  extract2("rowcoord") %>%
  as.data.frame() %>% 
  rownames_to_column("partido") %>% 
  select(partido, Dim1) %>% 
  arrange(Dim1) %>% 
  mutate(Dim1 = Dim1 * -1)

resultado_d1_colunas <- ca_result %>%
  extract2("colcoord") %>%
  as.data.frame() %>% 
  rownames_to_column("frente_id") %>% 
  select(frente_id, Dim1) %>% 
  arrange(Dim1) %>% 
  mutate(Dim1 = Dim1 * -1) %>% 
  left_join(distinct(frentes, frente_nome,frente_id)) %>% 
  select(frente_id, frente_nome, Dim1)

# Salva
path_resultado <- glue("{dir_resultado}/d1_frentes_politicos.csv")
write.csv(resultado_d1_linhas, path_resultado, row.names = FALSE)

path_resultado <- glue("{dir_resultado}/d1_frentes.csv")
write.csv(resultado_d1_colunas, path_resultado, row.names = FALSE)

path_partidos_por_frente <- glue("{dir_resultado}/partidos_por_frente.csv")
write.csv(partidos_por_frente, path_partidos_por_frente, row.names = FALSE)
