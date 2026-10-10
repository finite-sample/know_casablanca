sources <- readr::read_csv(project_file("docs", "historical_sources.csv"), show_col_types = FALSE)
hashes <- purrr::map_chr(sources$extract, \(path) digest::digest(file = project_file(path), algo = "sha256"))
stopifnot(all(hashes == sources$extract_sha256))
write_output <- \(x, name) readr::write_csv(x, file.path(table_dir, name), na = "")
items <- historical_items()
write_output(historical_distributions(items), "historical_distributions.csv")
items |>
  dplyr::filter(!is.na(response)) |>
  tidyr::pivot_longer(c(knowledge, knowledge_without_target), names_to = "index", values_to = "knowledge_score") |>
  dplyr::group_by(study, item, key, party_basis, response, index) |>
  dplyr::summarise(
    n = sum(!is.na(knowledge_score)), mean = mean(knowledge_score, na.rm = TRUE),
    std_error = stats::sd(knowledge_score, na.rm = TRUE) / sqrt(n), .groups = "drop"
  ) |>
  write_output("historical_knowledge_means.csv")
distributions <- read_tab("historical_distributions.csv")
distributions |>
  dplyr::filter(party %in% c("rep", "dem"), response == "cor") |>
  dplyr::select(study, item, key, party_basis, party, answered, share) |>
  tidyr::pivot_wider(names_from = party, values_from = c(answered, share)) |>
  dplyr::mutate(
    gap = share_rep - share_dem,
    std_error = sqrt(share_rep * (1 - share_rep) / answered_rep + share_dem * (1 - share_dem) / answered_dem),
    lower = gap - stats::qnorm(.975) * std_error, upper = gap + stats::qnorm(.975) * std_error
  ) |>
  write_output("historical_partisan_gaps.csv")
items |>
  dplyr::filter(key == "archived", study %in% c("nes88", "nes00", "nes08"), !is.na(response4)) |>
  dplyr::group_by(study, item) |>
  dplyr::group_modify(\(data, key) historical_scenarios(data)) |>
  dplyr::ungroup() |>
  write_output("historical_scenarios.csv")
core <- items |>
  dplyr::filter(
    key == "archived",
    study %in% c("gss06", "nic2", "btp04") |
      (study %in% c("nes88", "nes00", "nes08") & !is.na(response4))
  )
party_models <- core |>
  dplyr::group_by(study, item) |>
  dplyr::group_modify(\(data, key) historical_scenarios(data, "party_three")) |>
  dplyr::ungroup()
leave_out <- historical_scenarios(dplyr::filter(core, study == "btp04"), "party_three", leave_target_out = TRUE) |>
  dplyr::mutate(study = "btp04", item = "iraq911")
write_output(dplyr::bind_rows(party_models, leave_out), "historical_party_scenarios.csv")
reference <- read.csv(project_file("data", "historical", "reference_tab1.csv")) |>
  dplyr::mutate(
    study = rep(c("gss06", "nic2", "btp04", rep("nes88", 3), rep("nes00", 2), rep("nes08", 3)), each = 4),
    item = rep(c(
      "scientific_consensus", "warming_cause", "iraq911", "infl", "unemp", "envir", "deficit", "crime",
      "unemp", "infl", "rich"
    ), each = 4),
    party = rep(c("rep", "ind", "dem", "all"), 11)
  ) |>
  dplyr::select(study, item, party, cor, incor, dk) |>
  tidyr::pivot_longer(c(cor, incor, dk), names_to = "response", values_to = "saved") |>
  dplyr::mutate(saved = readr::parse_number(saved)) |>
  dplyr::left_join(dplyr::filter(distributions, key == "archived"),
    by = c("study", "item", "party", "response"), relationship = "one-to-one"
  ) |>
  dplyr::mutate(
    reconstructed = round(100 * share, 2), difference = reconstructed - saved,
    matches = abs(difference) < 1e-8
  )
write_output(reference, "historical_saved_comparison.csv")
latent <- purrr::map(c("nes88", "nes08"), function(study) {
  columns <- if (study == "nes88") c("m.infls", "m.unemps", "m.envirs") else c("m.infls", "m.unemps", "m.richs")
  result <- latent_response_models(as.data.frame(read_historical(study)), columns)
  lapply(result, \(x) dplyr::mutate(x, study = study, .before = 1))
})
write_output(dplyr::bind_rows(lapply(latent, `[[`, "diagnostics")), "historical_latent_fit.csv")
write_output(dplyr::bind_rows(lapply(latent, `[[`, "profiles")), "historical_latent_profiles.csv")
saveRDS(items, file.path(derived_dir, "historical_items.rds"))
