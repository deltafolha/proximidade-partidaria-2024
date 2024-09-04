  # pacotes -----------------------------------------------------------------
library(glue)
library(stringr)
library(dplyr)
library(purrr)
library(data.table)
library(magrittr)
library(tibble)
library(tidyr)
library(ca)

# variáveis ---------------------------------------------------------------
dir_coligacoes <- "dados/brutos/coligacoes/"
dir_resultado <- "dados/interim/resultados/"
path_candidatos <- "dados/brutos/candidatos/consulta_cand_2024_BRASIL.csv"

# cria diretorios ---------------------------------------------------------
if(!dir.exists(dir_coligacoes)) dir.create(dir_coligacoes, recursive = TRUE)

# baixa dados -------------------------------------------------------------
url_coligacao <- paste0("https://cdn.tse.jus.br/estatistica/",
                        "sead/odsele/consulta_coligacao/consulta_coligacao_", 
                        "2024.zip")
path_coligacao_zip <- str_replace(url_coligacao, ".*/", dir_coligacoes)
#if(!file.exists(path_coligacao_zip)){
  download.file(url_coligacao, path_coligacao_zip)
#}
unzip(zipfile = path_coligacao_zip, exdir = dir_coligacoes)



# lê os dados -------------------------------------------------------------
coligacoes_com_candidatos <- path_candidatos %>% 
  fread(select = "SQ_COLIGACAO", colClasses = "character") %>% 
  distinct()

# Essa tabela vai ter um partido por linha e o ID da coligação que ele 
# faz parte
coligacao <-  list.files("dados/brutos/coligacoes/", 
                         full.names = TRUE, recursive = TRUE, 
                         pattern = "BRASIL.csv") %>%
  map(fread, colClasses = "character", encoding = "Latin-1") %>% 
  bind_rows() %>%
  filter(DS_CARGO ==  "PREFEITO") %>%
  # Algumas coligações não estavam presentes na tabela de candidatos
  # isso assegura que todas estejam
  inner_join(coligacoes_com_candidatos) %>% 
  # Algumas coligacoes aparecem mais de uma vez com sequencial diferentes
  # por isso criamos um ID novo para elas. Esse é composto pela 
  # concatenação em ordem alfabética dos partidos e o código da  UE
  group_by(SQ_COLIGACAO) %>% 
  mutate(id_fix = paste(sort(SG_PARTIDO), collapse = "_")) %>%
  ungroup() %>% 
  mutate(id_coligacao = paste0(id_fix, "_", SG_UE)) %>%
  select(id_coligacao, SG_PARTIDO) %>% 
  distinct()


# analise -----------------------------------------------------------------

tbl_coligacoes <- coligacao %>% 
  # Cria todos os pares de partido dentro de uma mesma coligação
  left_join(coligacao, by = "id_coligacao", relationship = "many-to-many") %>%
  # Para não contar pares idênticos, mas com ordem trocada
  filter(SG_PARTIDO.x < SG_PARTIDO.y) %>% 
  # Tabula quantas vezes cada par de partido apareceu
  group_by(SG_PARTIDO.x, SG_PARTIDO.y) %>% 
  summarise(n_coligacoes = n()) %>% 
  ungroup() %>% 
  # Nome mais simpático
  rename(partido_1 = SG_PARTIDO.x, 
         partido_2 = SG_PARTIDO.y)

# Faz uma matriz com a quantidade de coligação entre partidos
ca_data <- tbl_coligacoes %>% 
  # faz umat tabela que inverte partido 1 e 2 e junta 
  # (para termos os dois triangulos da matrix) 
  bind_rows(set_colnames(tbl_coligacoes, c("partido_2", "partido_1",
                                           "n_coligacoes")))  %>% 
  pivot_wider(names_from = partido_2, values_from = n_coligacoes, 
              values_fill = 0) %>%
  column_to_rownames("partido_1") %>% 
  as.matrix()


# Faz a matriz ser simétrica na ordem das linhas e colunas
ca_data <- ca_data[rownames(ca_data), rownames(ca_data)]

# As diagonais (o partido com ele mesmo) vai ser a soma de todas as migrações 
# Dessa forma todos os partidos tem uma relação proporcional consigo mesmo
# em função do total de migrações
diag(ca_data) <- colSums(ca_data)

# Faz a análise
ca_result <- ca(ca_data)

# salva o resultado -------------------------------------------------------
resultado_d1 <- ca_result %>%
  extract2("rowcoord") %>%
  as.data.frame() %>% 
  rownames_to_column("partido") %>% 
  select(partido, Dim1) %>% 
  arrange(Dim1) %>% 
  mutate(partido = str_remove(partido, "/\\d+"))


path_resultado <- glue("{dir_resultado}/d1_coligacoes.csv")
write.csv(resultado_d1, path_resultado, row.names = FALSE)

path_coligacoes_tbl <- glue("{dir_resultado}/tbl_coligacoes.csv")
write.csv(tbl_coligacoes, path_coligacoes_tbl, row.names = FALSE)

# Para fazer o grafo no final
path_ca_result <- glue("{dir_resultado}/ca_result_coligacoes.csv")
write.csv(ca_result$rowcoord, path_ca_result)
