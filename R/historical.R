read_historical <- function(name) {
  readr::read_csv(project_file("data", "historical", paste0(name, ".csv")), show_col_types = FALSE)
}

historical_items <- function() {
  definitions <- list(
    nes88 = c("infl", "unemp", "envir", "defense", "deficit"),
    nes92 = c("unemp", "infl", "econ", "econ4j", "econ1"),
    nes00 = c("deficit", "crime", "econ"),
    nes04 = c("unemp", "infl", "econ", "rich"),
    nes08 = c("infl", "unemp", "rich")
  )
  anes <- purrr::imap(definitions, function(items, study) {
    data <- read_historical(study)
    purrr::map(items, function(item) {
      y3 <- paste0("m.", item, "r")
      y4 <- paste0("m.", item, "s")
      raw_response <- as.character(data[[paste0("m.", item)]])
      knowledge <- if ("know" %in% names(data)) data$know else NA_real_
      affect <- if ("r.min.d.therm" %in% names(data)) data$r.min.d.therm else NA_real_
      party_current <- if ("party_current" %in% names(data)) data$party_current else as.character(data$pid3)
      party_basis <- if (study == "nes92") "1990_panel" else "contemporaneous"
      tibble::tibble(
        study,
        respondent = seq_len(nrow(data)), item,
        response = dplyr::if_else(is.na(raw_response), NA_character_, data[[y3]]),
        response4 = if (y4 %in% names(data)) {
          dplyr::if_else(is.na(raw_response), NA_character_, data[[y4]])
        } else {
          NA_character_
        },
        raw_response,
        knowledge,
        party = as.character(data$pid3), party_current, party_basis,
        affect,
        knowledge_without_target = NA_real_
      )
    }) |>
      purrr::list_rbind()
  }) |>
    purrr::list_rbind()
  others <- purrr::map(c("gss06", "nic2", "btp04"), function(study_id) {
    data <- read_historical(study_id)
    raw <- switch(study_id,
      gss06 = as.character(data$sciagrgw),
      nic2 = data$warm,
      btp04 = data$w4b62
    )
    correct <- switch(study_id,
      gss06 = "1",
      nic2 = "human",
      btp04 = "false"
    )
    incorrect <- switch(study_id,
      gss06 = as.character(2:5),
      nic2 = c("not", "natural"),
      btp04 = "true"
    )
    dk <- switch(study_id,
      gss06 = "8",
      nic2 = "dk",
      btp04 = "don't know"
    )
    response <- dplyr::case_when(raw == correct ~ "cor", raw %in% incorrect ~ "incor", raw == dk ~ "dk")
    other_knowledge <- if (study_id == "btp04") {
      rowMeans(data[paste0("w4b", c(60, 68, 61, 63, 64, 65, 66, 69), "r")], na.rm = TRUE)
    } else {
      rep(NA_real_, nrow(data))
    }
    tibble::tibble(
      study = study_id, party_basis = "contemporaneous",
      respondent = seq_len(nrow(data)),
      item = switch(study_id,
        gss06 = "scientific_consensus",
        nic2 = "warming_cause",
        btp04 = "iraq911"
      ),
      response,
      response4 = if (study_id == "gss06") dplyr::if_else(raw == "3", "same", response) else NA_character_,
      raw_response = raw,
      knowledge = switch(study_id,
        gss06 = data$inf,
        nic2 = data$kn_ind2c,
        btp04 = data$t1know
      ),
      party = as.character(if (study_id == "btp04") data$pid3 else data$rid), affect = NA_real_,
      knowledge_without_target = other_knowledge
    )
  }) |>
    purrr::list_rbind()
  out <- dplyr::bind_rows(anes, others) |> dplyr::mutate(key = "archived")
  stopifnot(all(is.na(out$response) | out$response %in% c("cor", "incor", "dk")))
  contemporaneous <- out |>
    dplyr::filter(study == "nes92") |>
    dplyr::mutate(party = party_current, party_basis = "contemporaneous")
  benchmark <- out |>
    dplyr::filter(study == "nes04", item %in% c("unemp", "infl")) |>
    dplyr::mutate(
      key = "annual_benchmark",
      response = dplyr::case_when(
        is.na(raw_response) ~ NA_character_, raw_response == "dk" ~ "dk",
        item == "unemp" & raw_response == "btr" ~ "cor",
        item == "infl" & raw_response == "wrse" ~ "cor",
        .default = "incor"
      )
    )
  dplyr::bind_rows(out, benchmark, contemporaneous)
}

historical_distributions <- function(data) {
  data |>
    dplyr::group_by(study, item, key, party_basis) |>
    dplyr::group_modify(function(data, key) {
      purrr::map(c("all", "rep", "ind", "dem"), function(party) {
        sub <- if (party == "all") data else data[!is.na(data$party) & data$party == party, ]
        n <- sum(!is.na(sub$response))
        tibble::tibble(
          party,
          total = nrow(sub), answered = n, missing = nrow(sub) - n,
          response = c("cor", "incor", "dk"),
          count = vapply(
            c("cor", "incor", "dk"), \(x) sum(sub$response == x, na.rm = TRUE), integer(1),
            USE.NAMES = FALSE
          )
        ) |> dplyr::mutate(share = dplyr::if_else(answered > 0, count / answered, NA_real_))
      }) |>
        purrr::list_rbind()
    }) |>
    dplyr::ungroup()
}

multinomial_average <- function(fit, data) {
  probability <- predict(fit, newdata = data, type = "probs")
  x <- stats::model.matrix(stats::delete.response(stats::terms(fit)), data)
  categories <- colnames(probability)
  gradient <- t(vapply(seq_along(categories), function(c) {
    unlist(lapply(2:length(categories), function(j) {
      colMeans(x * as.vector(probability[, c] * ((c == j) - probability[, j])))
    }))
  }, numeric(ncol(x) * (length(categories) - 1))))
  estimate <- colMeans(probability)
  covariance <- stats::vcov(fit)
  standard_error <- sqrt(pmax(0, diag(gradient %*% covariance %*% t(gradient))))
  modal <- table(factor(categories[max.col(probability, ties.method = "first")], levels = categories)) / nrow(data)
  list(
    summary = tibble::tibble(
      response = categories, estimate, std_error = standard_error,
      lower = pmax(0, estimate - stats::qnorm(.975) * standard_error),
      upper = pmin(1, estimate + stats::qnorm(.975) * standard_error), modal_share = as.numeric(modal)
    ),
    gradient = gradient
  )
}

historical_scenarios <- function(data, specification = "affect_four", leave_target_out = FALSE) {
  data$outcome <- if (specification == "affect_four") data$response4 else data$response
  data$predictor <- if (specification == "affect_four") {
    data$affect
  } else {
    factor(data$party, levels = c("dem", "ind", "rep"))
  }
  if (leave_target_out) data$knowledge <- data$knowledge_without_target
  data <- data[stats::complete.cases(data[c("outcome", "knowledge", "predictor")]), ]
  if (nrow(data) == 0) {
    return(tibble::tibble())
  }
  categories <- if (specification == "affect_four") c("cor", "incor", "same", "dk") else c("cor", "incor", "dk")
  data$outcome <- factor(data$outcome, levels = categories)
  if (any(table(data$outcome) == 0)) stop("Missing outcome category")
  fit <- nnet::multinom(outcome ~ predictor * knowledge, data = data, trace = FALSE, Hess = TRUE, maxit = 2000)
  if (fit$convergence != 0) stop("Historical multinomial model did not converge")
  observed <- multinomial_average(fit, data)
  neutral_outside <- if (specification == "affect_four") {
    min(data$affect) > 0 | max(data$affect) < 0
  } else {
    !any(data$party == "ind")
  }
  purrr::map(c("observed", "neutral_partisanship", "zero_knowledge"), function(scenario) {
    new <- data
    if (scenario == "neutral_partisanship") {
      new$predictor <- if (specification == "affect_four") {
        0
      } else {
        factor(rep("ind", nrow(data)), levels = levels(data$predictor))
      }
    }
    if (scenario == "zero_knowledge") new$knowledge <- 0
    result <- multinomial_average(fit, new)
    gradient <- result$gradient - observed$gradient
    difference_se <- sqrt(pmax(0, diag(gradient %*% stats::vcov(fit) %*% t(gradient))))
    result$summary |>
      dplyr::mutate(
        specification,
        knowledge_index = if (leave_target_out) "target_excluded" else "archived",
        scenario, n = nrow(data), difference = estimate - observed$summary$estimate,
        difference_se = difference_se,
        difference_lower = difference - stats::qnorm(.975) * difference_se,
        difference_upper = difference + stats::qnorm(.975) * difference_se,
        observed_share = as.numeric(prop.table(table(data$outcome))),
        knowledge_min = min(data$knowledge), knowledge_max = max(data$knowledge),
        outside_marginal_support = (scenario == "zero_knowledge" & min(data$knowledge) > 0) |
          (scenario == "neutral_partisanship" & neutral_outside)
      )
  }) |>
    purrr::list_rbind()
}
