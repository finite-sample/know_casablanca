strict_rating <- function(x) {
  value <- suppressWarnings(as.numeric(x))
  dplyr::if_else(value %in% 0:10, value, NA_real_)
}

collapse_intake <- function(data) {
  data |>
    dplyr::filter(!is.na(respondent), respondent != "") |>
    tidyr::pivot_longer(-respondent, names_to = "field", values_to = "value") |>
    dplyr::mutate(value = dplyr::na_if(stringr::str_trim(value), "")) |>
    dplyr::group_by(respondent, field) |>
    dplyr::summarise(
      distinct_values = dplyr::n_distinct(value, na.rm = TRUE),
      value = if (distinct_values == 1) unique(stats::na.omit(value)) else NA_character_,
      conflict = distinct_values > 1, .groups = "drop"
    )
}

race_selections <- function(data) {
  apply(data, 1, function(row) {
    selected <- row[!is.na(row) & row != ""]
    if (length(selected) == 0) NA_character_ else if (length(selected) > 1) "Multiple races" else selected
  })
}

read_correlates <- function(frame) {
  intake <- readr::read_csv(raw_path("alumni_2010_demographics.csv"), col_types = readr::cols(.default = "c")) |>
    dplyr::rename(respondent = arep.id) |>
    dplyr::mutate(dplyr::across(-respondent, \(x) dplyr::if_else(x %in% c("Unknown", "#NAME?"), NA_character_, x)))
  collapsed <- collapse_intake(intake)
  demo <- collapsed |>
    dplyr::select(respondent, field, value) |>
    tidyr::pivot_wider(names_from = field, values_from = value) |>
    dplyr::mutate(intake_match = TRUE)
  ideology_levels <- c(
    "Very liberal", "Liberal", "Slightly liberal", "Moderate", "Slightly conservative", "Conservative",
    "Very conservative"
  )
  panels <- purrr::map(c("alumni", "staff"), function(study) {
    data <- read_panel_records(paste0(study, "_2010.csv"), if (study == "alumni") "FY" else "srep")
    data <- data |> dplyr::rename(respondent = userid)
    if (study == "alumni") {
      data <- dplyr::left_join(data, demo, by = "respondent", relationship = "one-to-one")
      birth_year <- suppressWarnings(as.numeric(data$year))
      gender <- data$gender
      education <- data$educ
      race <- data$ethnic
      hispanic <- rep(NA_character_, nrow(data))
      linked <- !is.na(data$intake_match)
    } else {
      birth_year <- suppressWarnings(as.numeric(data$year.born))
      gender <- data$sex
      education <- data$educ.s
      race <- race_selections(data[c("white", "black", "native", "asian", "pacific", "other.race")])
      hispanic <- data$hispanic
      linked <- rep(NA, nrow(data))
    }
    strength <- dplyr::case_when(data$pid1 == "Democrat" ~ data$pid2.d, data$pid1 == "Republican" ~ data$pid2.r)
    tibble::tibble(
      study,
      respondent = data$respondent, age = 2010 - birth_year, gender, education, race, hispanic,
      ideology = match(data$ideology, ideology_levels),
      attachment = dplyr::if_else(strength %in% c("Strong", "Not very strong"), strength, NA_character_),
      voting_intention_2010 = strict_rating(data$vote.2010),
      voting_rescaled = parse_rating(data$vote.2010), intake_match = linked
    )
  }) |>
    purrr::list_rbind()
  mturk <- purrr::map(c("march", "july"), function(month) {
    data <- read_qualtrics(paste0("mturk_", month, "_2017.csv"))
    tibble::tibble(
      study = paste0("mturk_", month), respondent = data$ResponseId,
      age = 2017 - suppressWarnings(as.numeric(data$age)),
      gender = data$gender, education = data$educ,
      race = dplyr::if_else(stringr::str_detect(data$race, ","), "Multiple races", data$race),
      hispanic = data$hisla
    )
  }) |>
    purrr::list_rbind()
  covariates <- dplyr::bind_rows(panels, mturk) |>
    dplyr::mutate(age = dplyr::if_else(age >= 18 & age <= 110, age, NA_real_))
  out <- frame |>
    dplyr::select(study, respondent, arm, party) |>
    dplyr::left_join(covariates, by = c("study", "respondent"), relationship = "one-to-one")
  stopifnot(nrow(out) == nrow(frame))
  list(data = out, conflicts = dplyr::filter(collapsed, conflict))
}

covariate_correlations <- function(data) {
  purrr::map(c("age", "ideology"), function(covariate) {
    purrr::map(extension_states, function(state) {
      pair <- data[stats::complete.cases(data[c(covariate, state)]), c(covariate, state)]
      n <- nrow(pair)
      varying <- n > 3 && all(vapply(pair, stats::sd, numeric(1)) > 0)
      correlation <- if (varying) stats::cor(pair[[1]], pair[[2]]) else NA_real_
      tibble::tibble(covariate, state, n, correlation)
    }) |>
      purrr::list_rbind()
  }) |>
    purrr::list_rbind()
}
