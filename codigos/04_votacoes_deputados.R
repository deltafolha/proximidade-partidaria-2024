# pacotes -----------------------------------------------------------------
library(stringr)
library(dplyr)
library(jsonlite)
library(httr)
library(lubridate)
library(glue)
library(purrr)
library(data.table)
library(magrittr)
library(tibble)
library(tidyr)
library(MCMCpack)

# variáveis ---------------------------------------------------------------
dir_lista_votacoes <- "dados/brutos/votacoes_camara/list/"
dir_votacao <- "dados/brutos/votacoes_camara/votos/"
dir_resultado <- "dados/interim/resultados/"
dir_detalhes_votacao <- "dados/brutos/votacoes_camara/detalhes/"

# cria diretorios ---------------------------------------------------------
dirs <- c(dir_lista_votacoes, dir_votacao)
for(dir in dirs){
  if(!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}

# baixa as votacoes -------------------------------------------------------
for(ano in 2023:2024){
  cat(ano, "\n")
  meses <- seq(1, 12) %>% 
    str_pad(width = 2, pad = "0")
  
  data_inicio <- paste0(ano, "-01-01") %>% 
    as.Date()
  data_fim <- paste0(ano, "-12-31") %>% 
    as.Date()
  
  range_meses <- seq.Date(data_inicio, data_fim, by = "day") %>% 
    as_tibble() %>% 
    mutate(mes = month(value)) %>%
    group_by(mes) %>% 
    filter(value %in% range(value))
  
  
  votacoes_no_mes <- list()
  for(mes_vot in meses){
    cat("    |-", mes_vot, "\n")
    path_lista_votacoes_mes <- glue("{dir_lista_votacoes}/{ano}_{mes_vot}.csv")
    if(file.exists(path_lista_votacoes_mes)) next
    
    range_mes <- range_meses %>% 
      filter(mes == as.numeric(mes_vot)) %>% 
      pull(value)
    
    pagina <- 1
    repeat{
      cat("         |- Pagina:", pagina, "\n")
      url <- paste0("https://dadosabertos.camara.leg.br/api/v2/votacoes?",
                    "dataInicio=", range_mes[1],
                    "&dataFim=", range_mes[2],
                    "&ordem=ASC",
                    "&ordenarPor=dataHoraRegistro",
                    "&pagina=", pagina,
                    "&itens=200") 
      for(attempt in 1:10) {
        cat("            |- Tentativa", attempt, "\n")
        response <- GET(url, timeout(60))
        content <- content(response, "text", encoding = "UTF-8")
        if(content == "upstream request timeout") next
        break
      }
      
      content_json <- content %>% 
        fromJSON()
      lista_votacoes <- content_json$dados
      if(length(lista_votacoes) == 0) break
      cat("      |- N linhas:", nrow(lista_votacoes), "\n")
      votacoes_no_mes[[length(votacoes_no_mes) + 1]] <- lista_votacoes 
      if(nrow(lista_votacoes) < 200)  break
      pagina <- pagina + 1
    }
    if(length(votacoes_no_mes) == 0) next
    votacoes_no_mes %>% 
      bind_rows() %>% 
      write.csv(path_lista_votacoes_mes, row.names = FALSE)
  }
}



# obtêm votações e os detalhes delas --------------------------------------

# ID das votações nominais
votacoes <- dir_lista_votacoes %>% 
  list.files(full.names = TRUE) %>% 
  map(fread) %>% 
  bind_rows() %>%
  # Somente as votações em plenário
  filter(siglaOrgao == "PLEN") %>%
  # Votações nominais tem sempre o total de votos na descrição
  filter(str_detect(descricao, "total")) %>% 
  pull(id) %>% 
  unique

n_votacoes <- length(votacoes)

for(i_votacao in seq_len(n_votacoes)){
  cat(i_votacao, "/", n_votacoes, "\n")
  id <- votacoes[i_votacao]
  path <- glue("{dir_votacao}/{id}.csv")
  if(!file.exists(path)) {
    url <- paste0("https://dadosabertos.camara.leg.br/api/v2/votacoes/",
                  id, "/votos")
    for(attempt in 1:10) {
      cat("    |- Tentativa", attempt, "\n")
      response <- GET(url, timeout(60))
      content <- content(response, "text", encoding = "UTF-8")
      if(content == "upstream request timeout") next
      break
    }
    
    content_json <- content %>% 
      fromJSON() %>% 
      extract2("dados")
    
    write.csv(content_json, path, row.names = FALSE)
  }
  path_detalhe <- glue("{dir_detalhes_votacao}/{id}.csv")
  if(!file.exists(path_detalhe)) {
    url <- paste0("https://dadosabertos.camara.leg.br/api/v2/votacoes/",
                  id)
    for(attempt in 1:10) {
      cat("    |- Tentativa", attempt, "\n")
      response <- GET(url, timeout(60))
      content <- content(response, "text", encoding = "UTF-8")
      if(content == "upstream request timeout") next
      break
    }
    
    content_json_dados <- content %>% 
      fromJSON() %>% 
      extract2("dados")
    pa <- content_json_dados %>% 
      extract2("proposicoesAfetadas")  
    if(length(pa)){
      pa <- pa %>% 
        rename_all(paste0, "_proposicoesAfetadas")
    }
    op <- content_json_dados %>% 
      extract2("objetosPossiveis") 
    if(length(op)){
      op <- op %>% 
        rename_all(paste0, "_objetosPossiveis")
    }
      
    n_op <- ifelse(is.null(nrow(op)), 0, nrow(op))
    n_pa <- ifelse(is.null(nrow(pa)), 0, nrow(pa))
    if(n_op > 1 & n_pa > 1){
      content_json <- bind_cols(pa)
    }else {
      content_json <- bind_cols(op, pa)  
    }
    content_json <- content_json %>% 
      mutate(id_votacao = id)
    write.csv(content_json, path_detalhe, row.names = FALSE)
  }
}



# formata -----------------------------------------------------------------

# Cada deputado como votou em cada votação
votacoes <- dir_votacao %>% 
  list.files(full.names = TRUE) %>% 
  map(~ fread(.x) %>% 
        mutate(path = .x)) %>% 
  bind_rows() %>%
  mutate(id_votacao = str_remove_all(path, ".*/|\\.csv")) %>% 
  dplyr::select(tipoVoto, deputado_.id, deputado_.nome, deputado_.siglaPartido, 
                deputado_.siglaUf, 
                id_votacao, dataRegistroVoto) %>% 
  mutate(deputado_.siglaPartido = recode(deputado_.siglaPartido,
                                         "PATRIOTA" = "AGIR", 
                                         "PTB" = "AGIR", 
                                         "PRN" ="AGIR", 
                                         "PROS" = "SOLIDARIEDADE", 
                                         "PSC" = "PODE"))  

# Tabela com os detalhes das votações 
# (para ilustrar o texto com as votações mais ou menos divididas)
detalhes_votacoes <- dir_detalhes_votacao %>% 
  list.files(full.names = TRUE) %>% 
  map(read.csv) %>% 
  bind_rows()

path_detalhe <- glue("{dir_resultado}/detalhes_votacao.csv")
write.csv(detalhes_votacoes, path_detalhe, row.names = FALSE)

# formata para analise ----------------------------------------------------

# Votação no formato binário quea função `MCMCirt1d` peder
votacoes_mtx <- votacoes %>% 
  dplyr::select(deputado_.id, tipoVoto, id_votacao) %>% 
  filter(tipoVoto %in% c("Sim", "Não")) %>% 
  mutate(tipoVoto = as.numeric(tipoVoto == "Sim")) %>% 
  pivot_wider(names_from = id_votacao, values_from = tipoVoto) %>% 
  column_to_rownames("deputado_.id") %>% 
  as.matrix()

# informação dos deputados, para anexar no resultado
info_deputados <- votacoes %>% 
  dplyr::select(deputado_.id, dataRegistroVoto, deputado_.nome, 
                deputado_.siglaPartido) %>% 
  arrange(desc(dataRegistroVoto)) %>%
  distinct(deputado_.id, .keep_all = TRUE) %>% 
  drop_na() %>% 
  dplyr::select(-dataRegistroVoto) %>% 
  rename(id_deputado = deputado_.id, 
         nome_deputado = deputado_.nome, 
         partido = deputado_.siglaPartido) %>% 
  mutate(id_deputado = as.character(id_deputado))


# Remove deputados com menos de 10% das votações
deputados_remover <- votacoes %>% 
  filter(tipoVoto %in% c("Sim", "Não")) %>% 
  mutate(n_votacoes = length(unique(id_votacao))) %>% 
  group_by(deputado_.id, deputado_.nome, n_votacoes) %>% 
  summarise(n_votacoes_dep = n()) %>% 
  ungroup() %>% 
  mutate(porcentagem_participacao = n_votacoes_dep/n_votacoes * 100) %>% 
  filter(porcentagem_participacao <= 10) %>% 
  pull(deputado_.id)

votacoes_mtx <- votacoes_mtx[!rownames(votacoes_mtx) %in% deputados_remover,]
info_deputados <- info_deputados %>% 
  filter(!id_deputado %in% deputados_remover)


# análise -----------------------------------------------------------------
mcmc_result <- MCMCirt1d(votacoes_mtx,  burnin = 2000,  mcmc = 10000, 
                         verbose = 500)


# Posição dos deputados
mc <- summary(mcmc_result)
ponto_ideal_deputados <- mc$statistics %>%
  as.data.frame() %>% 
  rownames_to_column("id_deputado") %>%
  dplyr::select(1:3) %>% 
  mutate(id_deputado = str_remove(id_deputado, "theta\\.")) %>% 
  left_join(info_deputados) %>% 
  arrange(Mean) %>% 
  mutate(escala_ranking = scales::rescale(Mean, to = c(1, 100)))

# Posição dos partidos
ponto_ideal_partidos <- ponto_ideal_deputados %>% 
  group_by(partido) %>% 
  summarise(ponto_ideal = median(Mean)) %>% 
  ungroup() %>% 
  arrange(ponto_ideal)

# Tabulação com a q uantidade de votos para cada lado em cada um dos partidos
votacoes_por_partido <- votacoes %>% 
  group_by(id_votacao, deputado_.siglaPartido, tipoVoto) %>% 
  summarise(n_votos = n()) %>% 
  ungroup() %>% 
  filter(tipoVoto %in% c("Sim", "Não")) %>% 
  set_colnames(c("id_votacao", "partido", "voto", "n_votos"))


# salva os resultados -----------------------------------------------------
path_resultado <- glue("{dir_resultado}/d1_ponto_ideal_partidos.csv")
write.csv(ponto_ideal_partidos, path_resultado, row.names = FALSE)

path_resultado_dep <- glue("{dir_resultado}/d1_ponto_ideal_deputados.csv")
write.csv(ponto_ideal_deputados, path_resultado_dep, row.names = FALSE)


path_votacoes <- glue("{dir_resultado}/votacoes_por_partido.csv")
write.csv(votacoes_por_partido, path_votacoes, row.names = FALSE)



