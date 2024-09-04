
library(dplyr)
library(stringr)
library(purrr)
library(data.table)
library(tidyr)
library(tibble)
library(ca)
library(magrittr)
library(glue)

# variavies ---------------------------------------------------------------
dir_candidatos <- "dados/brutos/candidatos/"
dir_resultado <- "dados/interim/resultados/"


# cria diretorios ---------------------------------------------------------
dirs <- c(dir_resultado, dir_candidatos)
for(dir in dirs){
  if(!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}



# baixa dados -------------------------------------------------------------
for(ano in c(2020, 2024)){
  url_candidato <- glue("https://cdn.tse.jus.br/estatistica/",
                        "sead/odsele/consulta_cand/consulta_cand_{ano}.zip")
  path_candidato_zip <- str_replace(url_candidato, ".*/", dir_candidatos)
  # if(!file.exists(path_candidato_zip)){
  #   download.file(url_candidato, path_candidato_zip)
  # }
  unzip(zipfile = path_candidato_zip, exdir = dir_candidatos)
}



# lê e formata os dados ---------------------------------------------------
candidatos <- list.files(dir_candidatos, 
                         full.names = TRUE, recursive = TRUE, 
                         pattern = "BRASIL.csv") %>% 
  map(fread, colClasses = "character", 
      select = c("DT_NASCIMENTO", "NR_CPF_CANDIDATO", "ANO_ELEICAO",
                 "NR_TITULO_ELEITORAL_CANDIDATO",  "SG_UF_NASCIMENTO", 
                 "NM_CANDIDATO", "SG_PARTIDO"),
      encoding = "Latin-1") %>% 
  bind_rows() %>% 
  # ID único entre diferentes eleicoes
  # Se tiver o CPF nos dois anos usamos ele 
  # Se não, usa o título de eleitor
  # Se não tiver o título usa o nome completo, data de nascimento e UF de 
  # nascimento
  mutate(DT_NASCIMENTO = as.Date(DT_NASCIMENTO, "%d/%m/%Y")) %>% 
  mutate(NR_CPF_CANDIDATO = ifelse(NR_CPF_CANDIDATO == "-4", NA, 
                                   NR_CPF_CANDIDATO)) %>%
  group_by(NR_TITULO_ELEITORAL_CANDIDATO) %>%
  mutate(ID_temp = cur_group_id()) %>%
  ungroup() %>%
  group_by(NR_CPF_CANDIDATO) %>%
  mutate(ID_temp = if(all(is.na(NR_TITULO_ELEITORAL_CANDIDATO))) 
    cur_group_id() + max(tab_tse$ID_temp, na.rm = TRUE) 
    else ID_temp) %>%
  ungroup() %>%
  group_by(NM_CANDIDATO, SG_UF_NASCIMENTO, DT_NASCIMENTO) %>%
  mutate(ID_temp = if(all(is.na(NR_TITULO_ELEITORAL_CANDIDATO)) && all(is.na(NR_CPF_CANDIDATO))) 
    cur_group_id() + max(tab_tse$ID_temp, na.rm = TRUE) 
    else ID_temp) %>%
  ungroup() %>%
  mutate(ID = as.character(ID_temp)) %>%
  select(-ID_temp) %>% 
  # Partidos que fundiram/mudaram de nome
  mutate(SG_PARTIDO = recode(SG_PARTIDO, 
                             "DEM" = "UNIÃO",
                             "PSL" = "UNIÃO",
                             "PATRIOTA" = "PRD", 
                             "PMN" = "MOBILIZA",
                             "PTC" = "AGIR",
                             "PTB" = "PRD",
                             "PODE" = "PODE", 
                             "PSC" = "PODE",
                             "PROS" = "SOLIDARIEDADE"))  %>% 
  # Mantem uma linha por candidato para cada eleicao
  distinct(ANO_ELEICAO, ID, .keep_all = TRUE) %>%
  # mantêm somente as colunas de interesse
  select(ANO_ELEICAO, ID, SG_PARTIDO)


# tabulação ---------------------------------------------------------------

# Gera uma tabela com uma linha por candidato com o partido anterior e posterior
antes_e_depois <- candidatos %>% 
  arrange(ID, ANO_ELEICAO) %>% 
  group_by(ID) %>%
  mutate(
    ano_1 = lag(ANO_ELEICAO),
    ano_2 = ANO_ELEICAO,
    partido_antes = lag(SG_PARTIDO),
    partido_depois = SG_PARTIDO
  ) %>%
  ungroup() %>% 
  # Remove as linha de candidatos que não concoreram nas duas eleições, assim
  # como as linhas que ano_1 são 2020 (logo não tem ano antes)
  drop_na

# Faz a tabulação antes e depois
mudancas_tbl <- antes_e_depois %>% 
  mutate_at(vars(ano_1, ano_2), as.numeric) %>%
  group_by(ano_1, ano_2, partido_antes, partido_depois) %>% 
  summarise(n = n()) %>% 
  ungroup()  %>% 
  # Como não importa a ordem (indo ou vindo e sim o par, vamos criar um ID
  # para cada par que é o mesmo indepedente da direção)
  group_by(partido_antes, partido_depois) %>% 
  mutate(id_par = paste(sort(c(partido_antes, partido_depois)), 
                        collapse = "/")) %>% 
  ungroup() %>% 
  group_by(id_par) %>% 
  summarise(n = sum(n)) %>% 
  ungroup() %>% 
  # Separa o ID em duas colunas
  separate(id_par, into = c("partido_1", "partido_2"), sep = "/")

# filtro de partidos ------------------------------------------------------

# Remove partidos com menos de 10 migrações
partidoss_remover <- mudancas_tbl %>%
  filter(partido_1 != partido_2) %>%
  pivot_longer(cols = c(partido_1, partido_2)) %>%
  group_by(value) %>%
  summarise(n = sum(n)) %>%
  arrange(desc(n)) %>%
  filter(n <= 10) %>%
  pull(value)


mudancas_tbl <- mudancas_tbl %>%
  filter(!partido_1 %in% partidoss_remover) %>%
  filter(!partido_2 %in% partidoss_remover)




# análise de correspondência ----------------------------------------------

# Faz a matriz
ca_data <- mudancas_tbl %>%
  # faz umat tabela que inverte partido 1 e 2 e junta 
  # (para termos os dois triangulos da matrix) 
  bind_rows(set_colnames(mudancas_tbl, c("partido_2", "partido_1", "n")))  %>%
  # Remove os que ficaram no mesmo partido 
  # (vamos lidar com isso lá embaixo, na diagonal da matrix)
  filter(partido_1 != partido_2) %>% 
  pivot_wider(names_from = partido_2, values_from = n, values_fill = 0) %>%
  column_to_rownames("partido_1") %>% 
  as.matrix()

# Faz a matriz ser simétrica na ordem das linhas e colunas
ca_data <- ca_data[rownames(ca_data), rownames(ca_data)]


# As diagonais (o partido com ele mesmo) vai ser a soma de todas as migrações 
# envolvendo o partido
# Dessa forma todos os partidos tem uma relação proporcional consigo mesmo
# em função do total de migrações
diag(ca_data) <- 0
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

path_resultado <- glue("{dir_resultado}/d1_migracao_partidaria.csv")
write.csv(resultado_d1, path_resultado, row.names = FALSE)

path_migracao_tbl <- glue("{dir_resultado}/tbl_migracao_partidaria.csv")
write.csv(mudancas_tbl, path_migracao_tbl, row.names = FALSE)

path_ca_result <- glue("{dir_resultado}/ca_result_migracao_partidaria.csv")
write.csv(ca_result$rowcoord, path_ca_result)

