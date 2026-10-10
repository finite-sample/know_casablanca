write_reconstruction_paper <- function() {
  number <- \(x) formatC(x, format = "f", digits = 2)
  percent <- \(x) formatC(100 * x, format = "f", digits = 1)
  ci <- \(lo, hi) paste0("[", number(lo), ", ", number(hi), "]")
  p_format <- \(x) ifelse(x < .001, "$<0.001$", formatC(x, format = "f", digits = 3))
  names <- c(alumni = "Alumni", staff = "Staff", mturk_march = "March", mturk_july = "July")
  states <- c(
    knowledge = "Knowledge", correct_belief = "Correct belief", incorrect_belief = "Incorrect belief",
    misinformation = "Misinformation", knowledge_minus_misinformation = "K minus M"
  )
  voting <- read_tab("panel_voting_models.csv") |>
    dplyr::filter(kind == "all", sample == "complete_items", scheme == 1)
  voting |>
    dplyr::transmute(
      study = names[study], state = states[term], n, mean = number(outcome_mean),
      estimate = number(estimate), interval = ci(lower, upper), p = p_format(p_holm)
    ) |>
    write_table(
      file.path(table_dir, "panel_voting.tex"), "llrrrrr",
      c("Study", "State", "$n$", "Mean", "Diff.", "95\\% interval", "$p_H$")
    )
  correlations <- read_tab("belief_covariate_correlations.csv") |>
    dplyr::filter(kind == "all", sample == "complete_items", scheme == 1, n > 0)
  correlations |>
    dplyr::select(study, covariate, state, n, correlation) |>
    tidyr::pivot_wider(names_from = state, values_from = correlation) |>
    dplyr::mutate(study = factor(names[study], levels = names)) |>
    dplyr::arrange(study, covariate) |>
    dplyr::transmute(study, covariate, n, dplyr::across(dplyr::all_of(extension_states), number)) |>
    write_table(
      file.path(table_dir, "demographic_correlations.tex"), "llrrrrrr",
      c("Study", "Measure", "$n$", "K", "CB", "Mid.", "IB", "M")
    )
  groups <- read_tab("belief_covariate_groups.csv") |>
    dplyr::filter(kind == "all", sample == "complete_items", scheme == 1, covariate == "attachment")
  groups |>
    dplyr::transmute(study = names[study], category, n, dplyr::across(dplyr::all_of(extension_states), percent)) |>
    write_table(
      file.path(table_dir, "attachment_states.tex"), "llrrrrrr",
      c("Study", "Attachment", "$n$", "K", "CB", "Mid.", "IB", "M")
    )
  historical_names <- c(
    nes88 = "ANES 1988", nes92 = "ANES 1992", nes00 = "ANES 2000", nes04 = "ANES 2004",
    nes08 = "ANES 2008", gss06 = "GSS 2006", nic2 = "NIC", btp04 = "BTP 2004"
  )
  item_names <- c(
    infl = "Inflation", unemp = "Unemployment", envir = "Environment", defense = "Defense",
    deficit = "Deficit", econ = "Economy", econ4j = "Economy since July", econ1 = "Economy past year",
    crime = "Crime", rich = "Inequality", scientific_consensus = "Scientific consensus",
    warming_cause = "Warming cause", iraq911 = "Iraq/9-11"
  )
  gaps <- read_tab("historical_partisan_gaps.csv") |>
    dplyr::filter(stringr::str_starts(study, "nes"))
  gaps |>
    dplyr::arrange(factor(study, levels = names(historical_names)), item, key, party_basis) |>
    dplyr::transmute(
      study = historical_names[study], item = item_names[item],
      key = dplyr::case_when(
        study == "ANES 1992" & party_basis == "1990_panel" ~ "1990 PID",
        study == "ANES 1992" ~ "1992 PID",
        key == "archived" ~ "Archive",
        .default = "Benchmark"
      ),
      nr = answered_rep, nd = answered_dem, gap = number(100 * gap), interval = ci(100 * lower, 100 * upper)
    ) |>
    write_table(file.path(table_dir, "historical_gaps.tex"), "lllrrrr",
      c("Study", "Item", "Definition", "$n_R$", "$n_D$", "R minus D", "95\\% interval"),
      caption = "Historical partisan gaps in keyed-correct responses, percentage points", label = "tab:historicalgaps"
    )
  scenarios <- dplyr::bind_rows(read_tab("historical_party_scenarios.csv"), read_tab("historical_scenarios.csv"))
  scenarios |>
    dplyr::filter(response == "cor") |>
    dplyr::mutate(value = paste0(percent(estimate), " [", percent(lower), ", ", percent(upper), "]")) |>
    dplyr::select(study, item, specification, knowledge_index, n, scenario, value) |>
    tidyr::pivot_wider(names_from = scenario, values_from = value) |>
    dplyr::arrange(specification, factor(study, levels = names(historical_names)), item, knowledge_index) |>
    dplyr::transmute(
      study = historical_names[study],
      item = paste0(item_names[item], dplyr::if_else(knowledge_index == "target_excluded", "*", "")),
      model = dplyr::if_else(specification == "party_three", "Party", "Affect"), n,
      observed, neutral_partisanship, zero_knowledge
    ) |>
    write_table(file.path(table_dir, "historical_predictions.tex"), "lllrrrr",
      c("Study", "Item", "Model", "$n$", "Observed", "Neutral", "Zero K"),
      caption = "Mean predicted percentages of keyed-correct responses (95\\% intervals)",
      label = "tab:historicalpredictions"
    )
  latent <- read_tab("historical_latent_fit.csv")
  latent |>
    dplyr::transmute(
      study = historical_names[study], classes, n, bic = number(bic),
      repeats = paste0(starts_at_best, "/", starts), smallest = percent(min_class_share),
      boundary = boundary_probabilities, tv = number(joint_total_variation)
    ) |>
    write_table(
      file.path(table_dir, "latent_models.tex"), "lrrrrrrr",
      c("Study", "Classes", "$n$", "BIC", "Best starts", "Min. share", "Boundary", "TV")
    )
  get_vote <- function(study_id, state) dplyr::filter(voting, study == study_id, term == state)
  values <- c()
  for (study in c("alumni", "staff")) {
    for (state in c("knowledge", "knowledge_minus_misinformation")) {
      row <- get_vote(study, state)
      stopifnot(nrow(row) == 1)
      name <- paste0("new", study, if (state == "knowledge") "VoteK" else "VoteDiff")
      values <- c(values, stats::setNames(
        c(number(row$estimate), ci(row$lower, row$upper)), c(name, paste0(name, "CI"))
      ))
    }
  }
  for (item in c("unemp", "infl")) {
    for (key in c("archived", "annual_benchmark")) {
      row <- dplyr::filter(gaps, study == "nes04", .data$item == .env$item, .data$key == .env$key)
      values[paste0("hist", item, key)] <- number(100 * row$gap)
    }
  }
  for (study in c("nes88", "nes08")) {
    row <- dplyr::filter(latent, .data$study == .env$study) |> dplyr::slice_min(bic, n = 1)
    values[paste0("latent", study, "Classes")] <- row$classes
    values[paste0("latent", study, "Smallest")] <- pct(row$min_class_share, 1)
  }
  write_macros(values, file.path(table_dir, "reconstruction_macros.tex"))
  lines <- c(
    "# Reconstructed analyses", "", "Generated by `make analysis`. All comparisons are exploratory.", "",
    "## Panel voting intention", "",
    "Scheme 1, all propositions, complete items. Estimates replace ten percentage points of the middle.",
    "HC3 pointwise intervals; Holm adjustment is over the separate panel-voting family.", "",
    "| Study | Contrast | n | Estimate | 95% interval | Holm p |", "|---|---|---:|---:|---|---:|",
    sprintf(
      "| %s | %s | %d | %.2f | [%.2f, %.2f] | %.3f |", voting$study, voting$term, voting$n,
      voting$estimate, voting$lower, voting$upper, voting$p_holm
    ), "",
    "## Historical models", "",
    "Eleven three-category party models and eight four-category affect models use named predictors.",
    "BTP additionally excludes the target item from its knowledge index. Full probabilities, modal shares, contrasts,",
    "and conditional model-based intervals are in `tabs/historical_party_scenarios.csv`",
    "and `tabs/historical_scenarios.csv`.",
    "Partisan gaps, the 2004 key sensitivity, and 1990 versus 1992 party groupings are in",
    "`tabs/historical_partisan_gaps.csv`. The 1992 raw codes distinguish DK from missing/not-asked.", "",
    "## Latent response patterns", "",
    "| Study | Classes | n | BIC | Best starts | Smallest class (%) | Boundary probabilities |",
    "|---|---:|---:|---:|---|---:|---:|",
    sprintf(
      "| %s | %d | %d | %.2f | %d/%d | %.1f | %d |", latent$study, latent$classes, latent$n, latent$bic,
      latent$starts_at_best, latent$starts, 100 * latent$min_class_share, latent$boundary_probabilities
    ), "",
    "These are response profiles under historical answer keys, not identified knowledge or misinformation classes.",
    "See [measures and limits](recovered_measures.md) and [the plan](historical_analysis_plan.md)."
  )
  writeLines(lines, project_file("docs", "reconstructed_results.md"))
}
