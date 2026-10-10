extension_states <- c("knowledge", "correct_belief", "middle", "incorrect_belief", "misinformation")
engagement_outcomes <- c("interest", "voting_intention", "partisan_intensity")

planned_belief_state <- function(rating, truth, scheme) {
  if (length(scheme) != 1L || !scheme %in% 1:3) stop("Unknown scoring scheme")
  if (any(!is.na(rating) & !rating %in% 0:10)) stop("Ratings must be integers from 0 to 10")
  score <- toward_truth(rating, truth)
  edge <- if (scheme == 1) 0 else 1
  middle_low <- if (scheme == 3) 5 else 4
  middle_high <- if (scheme == 3) 5 else 6
  state <- dplyr::case_when(
    score >= 10 - edge ~ "knowledge",
    score <= edge ~ "misinformation",
    score > middle_high ~ "correct_belief",
    score < middle_low ~ "incorrect_belief",
    !is.na(score) ~ "middle"
  )
  factor(state, levels = extension_states)
}

rating_distributions <- function(ratings) {
  ratings |>
    dplyr::mutate(score = toward_truth(rating, truth)) |>
    dplyr::count(study, prop_id, truth, score, name = "count") |>
    dplyr::group_by(study, prop_id, truth) |>
    tidyr::complete(score = c(0:10, NA_real_), fill = list(count = 0L)) |>
    dplyr::mutate(total = sum(count), share = count / total) |>
    dplyr::ungroup()
}

planned_indices <- function(ratings) {
  if (anyDuplicated(ratings[c("study", "respondent", "prop_id")])) stop("Duplicate respondent-item rows")
  split <- dplyr::bind_rows(
    dplyr::mutate(ratings, kind = "all"),
    dplyr::mutate(ratings, kind = dplyr::if_else(truth, "denial", "invention"))
  )
  purrr::map(1:3, function(scheme) {
    split |>
      dplyr::mutate(state = planned_belief_state(rating, truth, scheme)) |>
      dplyr::group_by(study, respondent, kind) |>
      dplyr::group_modify(function(data, key) {
        answered <- sum(!is.na(data$state))
        shares <- vapply(extension_states, function(state) {
          if (answered == 0) NA_real_ else sum(data$state == state, na.rm = TRUE) / answered
        }, numeric(1))
        dplyr::bind_cols(
          tibble::tibble(items = nrow(data), answered = answered),
          tibble::as_tibble_row(shares)
        )
      }) |>
      dplyr::ungroup() |>
      dplyr::mutate(scheme = scheme)
  }) |>
    purrr::list_rbind()
}

index_samples <- function(indices) {
  dplyr::bind_rows(
    indices |>
      dplyr::filter(answered == items, answered > 0) |>
      dplyr::mutate(sample = "complete_items"),
    indices |>
      dplyr::filter(answered > 0) |>
      dplyr::mutate(sample = "available_items")
  )
}

engagement_model <- function(data, outcome) {
  predictors <- setdiff(extension_states, "middle")
  contrasts <- c(predictors, "knowledge_minus_misinformation")
  eligible <- nrow(data)
  missing_outcome <- sum(is.na(data[[outcome]]))
  data <- data[stats::complete.cases(data[c(outcome, predictors)]), ]
  n <- nrow(data)
  mean_outcome <- if (n > 0) mean(data[[outcome]]) else NA_real_
  result <- tibble::tibble(
    outcome = outcome, term = contrasts, eligible = eligible, missing_outcome = missing_outcome, n = n,
    outcome_mean = mean_outcome,
    estimate = NA_real_, std_error = NA_real_, lower = NA_real_, upper = NA_real_,
    p_value = NA_real_, residual_df = NA_real_, max_leverage = NA_real_, status = "insufficient_data"
  )
  if (n <= length(predictors) + 1) {
    return(result)
  }
  fit <- stats::lm(stats::reformulate(predictors, outcome), data = data)
  result$residual_df <- stats::df.residual(fit)
  result$max_leverage <- max(stats::hatvalues(fit))
  if (fit$rank < length(predictors) + 1) {
    result$status <- "rank_deficient"
    return(result)
  }
  if (result$max_leverage[1] >= 1 - 1e-8) {
    result$status <- "unit_leverage"
    return(result)
  }
  if (stats::sd(data[[outcome]]) == 0) {
    result$status <- "constant_outcome"
    return(result)
  }
  covariance <- sandwich::vcovHC(fit, type = "HC3")
  if (any(!is.finite(covariance))) {
    result$status <- "nonfinite_covariance"
    return(result)
  }
  weights <- matrix(0, nrow = length(contrasts), ncol = length(stats::coef(fit)))
  colnames(weights) <- names(stats::coef(fit))
  weights[cbind(seq_along(predictors), match(predictors, colnames(weights)))] <- 0.1
  weights[5, "knowledge"] <- 0.1
  weights[5, "misinformation"] <- -0.1
  result$estimate <- as.vector(weights %*% stats::coef(fit))
  result$std_error <- sqrt(pmax(0, diag(weights %*% covariance %*% t(weights))))
  critical <- stats::qt(0.975, stats::df.residual(fit))
  result$lower <- result$estimate - critical * result$std_error
  result$upper <- result$estimate + critical * result$std_error
  result$p_value <- 2 * stats::pt(-abs(result$estimate / result$std_error), stats::df.residual(fit))
  result$status <- "estimated"
  result
}

engagement_correlations <- function(data) {
  tidyr::expand_grid(outcome = engagement_outcomes, state = extension_states) |>
    dplyr::rowwise() |>
    dplyr::mutate(result = list({
      pairs <- data[stats::complete.cases(data[c(outcome, state)]), c(outcome, state)]
      n <- nrow(pairs)
      varying <- n > 2 && all(vapply(pairs, stats::sd, numeric(1)) > 0)
      tibble::tibble(n = n, correlation = if (varying) stats::cor(pairs[[1]], pairs[[2]]) else NA_real_)
    })) |>
    dplyr::ungroup() |>
    tidyr::unnest(result)
}

write_extension_summary <- function(shares, coverage, models) {
  shares <- dplyr::filter(shares, kind == "all")
  coverage <- dplyr::filter(coverage, kind == "all", scheme == 1)
  contrasts <- models |>
    dplyr::filter(kind == "all", outcome == "voting_intention", term == "knowledge_minus_misinformation") |>
    dplyr::filter(status == "estimated")
  sample_labels <- c(complete_items = "Complete items", available_items = "Available items")
  lines <- c(
    "# Belief-state extension results",
    "",
    "Generated by `make analysis`. These are exploratory associations within convenience samples.",
    "The [analysis plan](belief_state_extensions.md) defines scoring, missingness, and inference.",
    "",
    "## Item completeness",
    "",
    "Complete-item indices require every retained proposition; available-item indices require at least one.",
    "Respondents with missing items can differ systematically from complete responders.",
    "",
    "| Study | Scale respondents | Complete | Some missing | No ratings |",
    "|---|---:|---:|---:|---:|",
    sprintf(
      "| %s | %d | %d | %d | %d |", study_labels[coverage$study], coverage$respondents,
      coverage$complete, coverage$incomplete, coverage$no_ratings
    ),
    "",
    "## Belief-state shares",
    "",
    "Entries are percentages, averaged equally over respondents, using all retained propositions.",
    "All five states sum to 100%; the remaining share below comprises correct and incorrect mere belief.",
    "Scheme 1 uses endpoints and middle 4–6; Scheme 2 broadens endpoints; Scheme 3 also narrows middle to 5.",
    "These classification labels do not independently validate knowledge or ignorance.",
    "",
    "| Study | Scheme | Sample | Respondents | Knowledge (%) | Middle (%) | Misinformation (%) |",
    "|---|---:|---|---:|---:|---:|---:|",
    sprintf(
      "| %s | %d | %s | %d | %.1f | %.1f | %.1f |", study_labels[shares$study], shares$scheme,
      sample_labels[shares$sample], shares$n, 100 * shares$knowledge, 100 * shares$middle,
      100 * shares$misinformation
    ),
    "",
    "## Voting intention: knowledge versus misinformation",
    "",
    "Outcome: intended likelihood of voting in the next congressional election, on a 0–10 scale.",
    "Each estimate replaces 10 percentage points of the misinformation share with knowledge,",
    "holding the other shares fixed. This is an association, not a turnout effect.",
    "Intervals use HC3 covariance and residual-df t critical values and are not simultaneous.",
    "Holm p-values account for all estimable contrasts and specifications within voting intention.",
    "",
    "| Study | Scheme | Sample | n | Difference (0–10 points) | 95% interval | Holm p |",
    "|---|---:|---|---:|---:|---|---:|",
    sprintf(
      "| %s | %d | %s | %d | %.2f | [%.2f, %.2f] | %.3f |",
      study_labels[contrasts$study], contrasts$scheme, sample_labels[contrasts$sample], contrasts$n,
      contrasts$estimate, contrasts$lower, contrasts$upper, contrasts$p_holm
    ),
    "",
    "Interest, partisan intensity, each state-versus-middle coefficient, and true/false splits",
    "are in [the model table](../tabs/belief_engagement_models.csv). Descriptive Pearson correlations",
    "are in [the correlation table](../tabs/belief_engagement_correlations.csv). Models lacking",
    "outcome data are flagged. Recovered 2010 voting measures and panel attachment are analyzed separately",
    "in [the reconstruction](reconstructed_results.md); panel attachment is not MTurk partisan extremity."
  )
  writeLines(lines, project_file("docs", "belief_extension_results.md"))
}
