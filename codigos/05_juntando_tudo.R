# pacotes -----------------------------------------------------------------
library(dplyr)
library(magrittr)
library(data.table)
library(ggplot2)
library(scales)
library(tidyr)
library(glue)
library(purrr)

# variaveis ---------------------------------------------------------------
migracao_path <- "dados/interim/resultados/d1_migracao_partidaria.csv"
frentes_path <- "dados/interim/resultados/d1_frentes_politicos.csv"
coligacoes_path <- "dados/interim/resultados/d1_coligacoes.csv"
votacoes_path <- "dados/interim/resultados/d1_ponto_ideal_partidos.csv"
dir_resultado <- "dados/interim/resultados/"
dir_processado <- "dados/processado/"

# cria diretório ----------------------------------------------------------
if(!dir.exists(dir_processado)) dir.create(dir_processado, recursive = TRUE)

# junta -------------------------------------------------------------------
migracao <- migracao_path %>% 
  fread() %>% 
  set_colnames(c("partido", "migracao")) %>% 
  # garante que a esquerda estara com os menores números, logo na esquerda
  mutate(migracao = ifelse(rep(migracao[partido == "PT"] > 0, n()), 
                           migracao * -1, 
                           migracao))

frente <- frentes_path%>% 
  fread() %>% 
  set_colnames(c("partido", "frentes")) %>% 
  # Para ficar igual as outras tabelas
  mutate(partido = recode(partido, "PCdoB" = "PC do B")) %>% 
  # garante que a esquerda estara com os menores números, logo na esquerda
  mutate(frentes = ifelse(rep(frentes[partido == "PT"] > 0, n()), 
                          frentes * -1, 
                          frentes))

coligacao <- coligacoes_path%>% 
  fread() %>% 
  set_colnames(c("partido", "coligacao")) %>% 
  # garante que a esquerda estara com os menores números, logo na esquerda
  mutate(coligacao = ifelse(rep(coligacao[partido == "PT"] > 0, n()), 
                            coligacao * -1, 
                            coligacao))

votacao <- votacoes_path %>% 
  fread() %>% 
  set_colnames(c("partido", "votacao")) %>%
  # Para ficar igual as outras tabelas
  mutate(partido = recode(partido, "PCdoB" = "PC do B")) %>% 
  # garante que a esquerda estara com os menores números, logo na esquerda
  mutate(votacao = ifelse(rep(votacao[partido == "PT"] > 0, n()), 
                          votacao * -1, 
                          votacao))

# junta -------------------------------------------------------------------
tudo <- list(migracao, frente, coligacao, votacao) %>%  
  # Junta as tabelas pela coluna "partido
  reduce(full_join, by = "partido") %>% 
  # Faz um ranking de cada variável
  mutate(across(c(migracao, frentes, coligacao, votacao),
                ~ rank(., ties.method = "min", na.last = "keep"),
                .names = "{.col}_rank")) %>% 
  # Normaliza os rankings entre 1 e 100
  mutate_at(vars(ends_with("_rank")), rescale, to = c(1, 100)) %>%
  # Faz a média dos ranking
  rowwise() %>%
  mutate(media_rank = mean(c(migracao_rank, frentes_rank, coligacao_rank, 
                             votacao_rank), na.rm = TRUE)) %>%
  ungroup() %>% 
  # Adiciona os labels
  arrange(media_rank) %>%   
  mutate(label = c(rep("esquerda_1", 3),
                   rep("esquerda_2", 4),
                   rep("esquerda_3", 3),
                   rep("centro_1", 2),
                   rep("centro_2", 3),
                   rep("centro_3", 4),
                   rep("direita_1", 3),
                   rep("direita_2", 3),
                   rep("direita_3", 3)))


  
  # salva -------------------------------------------------------------------
path_resultado <- glue("{dir_processado}/tabela_final.csv")
write.csv(tudo, file = path_resultado, row.names = FALSE)