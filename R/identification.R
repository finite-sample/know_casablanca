validate_probability <- function(x, name) {
  if (!is.numeric(x) || length(x) == 0 || any(!is.finite(x)) || any(x < 0 | x > 1)) {
    stop(name, " must contain finite probabilities in [0, 1]")
  }
  invisible(TRUE)
}

binary_error_bounds <- function(q_lower, q_upper = q_lower, alpha = 1, beta = 1) {
  n <- length(q_lower)
  values <- list(q_lower = q_lower, q_upper = q_upper, alpha = alpha, beta = beta)
  for (name in names(values)) {
    validate_probability(values[[name]], name)
    if (!length(values[[name]]) %in% c(1L, n)) stop("Incompatible vector lengths")
  }
  values <- lapply(values, rep_len, length.out = n)
  if (any(values$q_lower > values$q_upper)) stop("Lower response probabilities exceed upper probabilities")
  lower <- ifelse(values$alpha == 1, 0, pmax(0, (values$q_lower - values$alpha) / (1 - values$alpha)))
  upper <- ifelse(values$beta == 1, 1, pmin(1, values$q_upper / (1 - values$beta)))
  arms <- tibble::tibble(
    arm = seq_len(n), q_lower = values$q_lower, q_upper = values$q_upper,
    alpha = values$alpha, beta = values$beta, lower, upper
  )
  list(
    arms = arms,
    joint = tibble::tibble(feasible = max(lower) <= min(upper), lower = max(lower), upper = min(upper))
  )
}

finite_state_bounds <- function(q, lo, hi, target, q_upper = q) {
  if (!is.matrix(q) || !identical(dim(q), dim(q_upper))) stop("Response bounds must be matching matrices")
  if (length(dim(lo)) != 3 || !identical(dim(lo), dim(hi)) || !identical(dim(lo)[1:2], dim(q))) {
    stop("Response restrictions must be arm-by-response-by-state arrays")
  }
  for (name in c("q", "q_upper", "lo", "hi")) validate_probability(get(name), name)
  if (any(q > q_upper) || any(lo > hi)) stop("Lower restrictions exceed upper restrictions")
  if (any(rowSums(q) > 1 + 1e-10) || any(rowSums(q_upper) < 1 - 1e-10)) {
    stop("Response intervals cannot contain a probability distribution")
  }
  if (any(apply(lo, c(1, 3), sum) > 1 + 1e-10) || any(apply(hi, c(1, 3), sum) < 1 - 1e-10)) {
    stop("Every arm-state channel must admit a stochastic response distribution")
  }
  shape <- dim(lo)
  states <- shape[3]
  if (is.character(target)) target <- match(target, dimnames(lo)[[3]])
  if (length(target) == 0 || anyNA(target) || any(!target %in% seq_len(states)) || anyDuplicated(target)) {
    stop("Target must select distinct existing states")
  }
  masses <- array(states + seq_len(prod(shape)), dim = shape)
  variables <- states + prod(shape)
  constraints <- new.env(parent = emptyenv())
  constraints$matrix <- list()
  constraints$directions <- character()
  constraints$rhs <- numeric()
  add <- function(indices, coefficients, direction, value) {
    row <- numeric(variables)
    row[indices] <- coefficients
    constraints$matrix[[length(constraints$matrix) + 1L]] <- row
    constraints$directions <- c(constraints$directions, direction)
    constraints$rhs <- c(constraints$rhs, value)
  }
  add(seq_len(states), rep(1, states), "=", 1)
  for (z in seq_len(shape[1])) {
    for (s in seq_len(states)) {
      add(c(masses[z, , s], s), c(rep(1, shape[2]), -1), "=", 0)
      for (r in seq_len(shape[2])) {
        add(c(masses[z, r, s], s), c(1, -lo[z, r, s]), ">=", 0)
        add(c(masses[z, r, s], s), c(1, -hi[z, r, s]), "<=", 0)
      }
    }
    for (r in seq_len(shape[2])) {
      add(masses[z, r, ], rep(1, states), ">=", q[z, r])
      add(masses[z, r, ], rep(1, states), "<=", q_upper[z, r])
    }
  }
  objective <- numeric(variables)
  objective[target] <- 1
  solve <- function(direction) {
    lpSolve::lp(direction, objective, do.call(rbind, constraints$matrix), constraints$directions, constraints$rhs)
  }
  lower <- solve("min")
  upper <- solve("max")
  status <- c(lower$status, upper$status)
  if (any(!status %in% c(0L, 2L))) stop("LP solver failed with status ", paste(status, collapse = ", "))
  feasible <- all(status == 0)
  tibble::tibble(
    feasible,
    lower = if (feasible) max(0, lower$objval) else NA_real_,
    upper = if (feasible) min(1, upper$objval) else NA_real_,
    lower_status = status[1], upper_status = status[2]
  )
}

response_intervals <- function(positive, missing, total, coverage = .95) {
  if (length(positive) == 0 || length(missing) != length(positive) || length(total) != length(positive)) {
    stop("Counts must have matching nonzero lengths")
  }
  counts <- c(positive, missing, total)
  invalid <- any(!is.finite(counts)) || any(counts < 0 | counts != floor(counts))
  if (invalid || any(total == 0) || any(positive + missing > total)) {
    stop("Invalid response counts")
  }
  if (length(coverage) != 1 || !is.finite(coverage) || coverage <= 0 || coverage >= 1) {
    stop("Coverage must lie strictly between zero and one")
  }
  arms <- length(positive)
  tail <- (1 - coverage) / (2 * arms)
  tibble::tibble(
    positive, missing, total,
    q_lower = positive / total, q_upper = (positive + missing) / total,
    confidence_lower = vapply(seq_len(arms), function(i) {
      stats::binom.test(positive[i], total[i], conf.level = 1 - 2 * tail)$conf.int[1]
    }, numeric(1)),
    confidence_upper = vapply(seq_len(arms), function(i) {
      stats::binom.test(positive[i] + missing[i], total[i], conf.level = 1 - 2 * tail)$conf.int[2]
    }, numeric(1)),
    simultaneous_coverage = coverage, tail_probability = tail
  )
}

equivalent_response_models <- function(q) {
  validate_probability(q, "q")
  low <- min(q) / 2
  high <- (1 + max(q)) / 2
  dplyr::bind_rows(
    tibble::tibble(
      construction = "low prevalence", arm = seq_along(q), prevalence = low,
      sensitivity = 1, false_positive = (q - low) / (1 - low)
    ),
    tibble::tibble(
      construction = "high prevalence", arm = seq_along(q), prevalence = high,
      sensitivity = q / high, false_positive = 0
    )
  ) |>
    dplyr::mutate(reconstructed_q = prevalence * sensitivity + (1 - prevalence) * false_positive)
}

identification_illustration <- function(prepared) {
  frame <- prepared$frame |>
    dplyr::filter(study == "mturk_march", arm %in% c("mc", "scale")) |>
    dplyr::select(respondent, arm)
  target_option <- "replace private health insurance with a single payer system"
  mc <- prepared$mc |>
    dplyr::filter(study == "mturk_march", question == "aca1", arm == "mc") |>
    dplyr::transmute(
      respondent, arm,
      positive = dplyr::if_else(is.na(response), NA, normalize_text(response) == target_option)
    )
  target <- prepared$ratings |>
    dplyr::filter(study == "mturk_march", prop_id == "m_aca_single_payer")
  if (any(is.na(target$truth) | target$truth)) stop("The target proposition must have a false answer key")
  scale <- target |> dplyr::transmute(respondent, arm = "scale", positive = rating == 10)
  observed <- dplyr::bind_rows(mc, scale)
  if (anyDuplicated(observed[c("respondent", "arm")]) || anyDuplicated(frame$respondent)) {
    stop("Duplicate assigned-arm outcomes")
  }
  if (nrow(dplyr::anti_join(observed, frame, by = c("respondent", "arm"))) > 0) {
    stop("Outcomes outside assigned arms")
  }
  assigned <- dplyr::left_join(frame, observed, by = c("respondent", "arm"), relationship = "one-to-one")
  counts <- assigned |>
    dplyr::group_by(arm) |>
    dplyr::summarise(
      missing = sum(is.na(positive)), positive = sum(positive, na.rm = TRUE),
      total = dplyr::n(), .groups = "drop"
    )
  intervals <- response_intervals(counts$positive, counts$missing, counts$total)
  counts <- dplyr::bind_cols(dplyr::select(counts, arm), intervals)
  counts <- counts |>
    dplyr::mutate(
      proposition = "m_aca_single_payer", answer_key = FALSE,
      sampling_assumption = "iid binomial within arm; Bonferroni Clopper-Pearson; not national estimates"
    )
  ratings <- prepared$ratings |>
    dplyr::filter(study == "mturk_march", question == "aca1")
  if (dplyr::n_distinct(ratings$prop_id) != 4 || anyDuplicated(ratings[c("respondent", "prop_id")])) {
    stop("Expected four distinct ACA propositions per respondent")
  }
  patterns <- ratings |>
    dplyr::group_by(respondent) |>
    dplyr::summarise(
      complete = dplyr::n() == 4 && all(!is.na(rating)),
      true_endpoint = any(truth & rating == 10, na.rm = TRUE),
      false_endpoint = any(!truth & rating == 10, na.rm = TRUE), .groups = "drop"
    )
  patterns <- frame |>
    dplyr::filter(arm == "scale") |>
    dplyr::left_join(patterns, by = "respondent", relationship = "one-to-one") |>
    dplyr::mutate(complete = dplyr::coalesce(complete, FALSE))
  complete <- dplyr::filter(patterns, complete)
  joint <- complete |>
    dplyr::count(true_endpoint, false_endpoint, name = "n") |>
    tidyr::complete(true_endpoint = c(FALSE, TRUE), false_endpoint = c(FALSE, TRUE), fill = list(n = 0L)) |>
    dplyr::mutate(total = nrow(complete), excluded = sum(!patterns$complete), share = n / total)
  list(counts = counts, joint = joint)
}

identification_scenarios <- function(counts, grid = seq(0, 1, .05)) {
  validate_probability(grid, "grid")
  if (!identical(counts$arm, c("mc", "scale"))) stop("Expected MC and scale arms in that order")
  scenarios <- tidyr::expand_grid(alpha = grid, beta = grid)
  results <- lapply(seq_len(nrow(scenarios)), function(i) {
    alpha <- scenarios$alpha[i]
    beta <- scenarios$beta[i]
    point <- binary_error_bounds(counts$q_lower, counts$q_upper, alpha, beta)
    outer <- binary_error_bounds(counts$confidence_lower, counts$confidence_upper, alpha, beta)
    tibble::tibble(
      alpha, beta,
      mc_lower = point$arms$lower[1], mc_upper = point$arms$upper[1],
      scale_lower = point$arms$lower[2], scale_upper = point$arms$upper[2],
      feasible = point$joint$feasible, lower = point$joint$lower, upper = point$joint$upper,
      confidence_feasible = outer$joint$feasible,
      confidence_lower = outer$joint$lower, confidence_upper = outer$joint$upper
    )
  })
  dplyr::bind_rows(results)
}
