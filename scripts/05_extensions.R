prepared <- readRDS(prepared_data_file)
indices <- planned_indices(prepared$ratings)
samples <- index_samples(indices)
covariates <- prepared$frame |>
  dplyr::select(study, respondent, dplyr::all_of(engagement_outcomes), partisan_position)
samples <- samples |>
  dplyr::left_join(covariates, by = c("study", "respondent"), relationship = "many-to-one")

write_output <- \(x, name) readr::write_csv(x, file.path(table_dir, name), na = "")
write_output(rating_distributions(prepared$ratings), "rating_distributions.csv")
indices |>
  dplyr::group_by(study, scheme, kind) |>
  dplyr::summarise(
    respondents = dplyr::n(), no_ratings = sum(answered == 0),
    incomplete = sum(answered > 0 & answered < items), complete = sum(answered == items),
    min_items = min(items), max_items = max(items), .groups = "drop"
  ) |>
  write_output("belief_index_coverage.csv")
samples |>
  dplyr::group_by(study, scheme, kind, sample) |>
  dplyr::summarise(
    n = dplyr::n(), mean_answered = mean(answered),
    dplyr::across(dplyr::all_of(extension_states), mean), .groups = "drop"
  ) |>
  write_output("belief_scheme_shares.csv")

models <- samples |>
  dplyr::group_by(study, scheme, kind, sample) |>
  dplyr::group_modify(\(data, key) {
    purrr::map(engagement_outcomes, \(outcome) engagement_model(data, outcome)) |>
      purrr::list_rbind()
  }) |>
  dplyr::ungroup() |>
  dplyr::group_by(outcome) |>
  dplyr::mutate(p_holm = stats::p.adjust(p_value, method = "holm", n = sum(!is.na(p_value)))) |>
  dplyr::ungroup()
write_output(models, "belief_engagement_models.csv")
samples |>
  dplyr::group_by(study, scheme, kind, sample) |>
  dplyr::group_modify(\(data, key) engagement_correlations(data)) |>
  dplyr::ungroup() |>
  write_output("belief_engagement_correlations.csv")
saveRDS(samples, file.path(derived_dir, "belief_indices.rds"))
write_extension_summary(read_tab("belief_scheme_shares.csv"), read_tab("belief_index_coverage.csv"), models)
write_extension_paper()
