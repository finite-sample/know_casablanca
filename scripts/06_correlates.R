prepared <- readRDS(prepared_data_file)
covariates <- read_correlates(prepared$frame)
write_output <- \(x, name) readr::write_csv(x, file.path(table_dir, name), na = "")
write_output(covariates$conflicts, "demographic_conflicts.csv")
covariates$data |>
  dplyr::filter(arm == "scale") |>
  dplyr::group_by(study) |>
  dplyr::summarise(
    respondents = dplyr::n(),
    intake_matches = if (all(is.na(intake_match))) NA_integer_ else sum(intake_match, na.rm = TRUE),
    dplyr::across(
      c(age, ideology, gender, education, race, hispanic, attachment, voting_intention_2010),
      \(x) sum(!is.na(x))
    ), .groups = "drop"
  ) |>
  write_output("covariate_coverage.csv")
samples <- readRDS(file.path(derived_dir, "belief_indices.rds")) |>
  dplyr::left_join(covariates$data, by = c("study", "respondent"), relationship = "many-to-one")
keys <- c("study", "scheme", "kind", "sample")
samples |>
  dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
  dplyr::group_modify(\(data, key) covariate_correlations(data)) |>
  dplyr::ungroup() |>
  write_output("belief_covariate_correlations.csv")
samples |>
  tidyr::pivot_longer(
    c(gender, education, race, hispanic, attachment, party), names_to = "covariate", values_to = "category"
  ) |>
  dplyr::filter(!is.na(category)) |>
  dplyr::group_by(dplyr::across(dplyr::all_of(c(keys, "covariate", "category")))) |>
  dplyr::summarise(n = dplyr::n(), dplyr::across(dplyr::all_of(extension_states), mean), .groups = "drop") |>
  write_output("belief_covariate_groups.csv")
samples |>
  dplyr::filter(study %in% c("alumni", "staff")) |>
  dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
  dplyr::group_modify(\(data, key) engagement_model(data, "voting_intention_2010")) |>
  dplyr::ungroup() |>
  dplyr::mutate(p_holm = stats::p.adjust(p_value, method = "holm", n = sum(!is.na(p_value)))) |>
  write_output("panel_voting_models.csv")
stopifnot(identical(samples$voting_intention_2010, samples$voting_rescaled))
saveRDS(samples, file.path(derived_dir, "correlate_indices.rds"))
