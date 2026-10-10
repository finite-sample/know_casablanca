source(file.path("../..", "scripts", "00_config.R"))
purrr::walk(list.files(file.path("../..", "R"), full.names = TRUE), source)

test_that("historical missing responses stay out of DK and denominators", {
  data <- tibble::tibble(
    study = "toy", item = "a", key = "archived", party_basis = "contemporaneous", party = c("rep", "dem", NA),
    response = c("cor", "dk", NA_character_)
  )
  result <- historical_distributions(data) |> dplyr::filter(party == "all")
  expect_equal(result$count, c(1L, 0L, 1L))
  expect_equal(result$share, c(.5, 0, .5))
  expect_true(all(result$missing == 1L & result$answered == 2L & result$total == 3L))
})

test_that("named multinomial scenarios change predictions and delta gradients match finite differences", {
  data <- read_historical("nes88")
  data <- data[stats::complete.cases(data[c("m.infls", "know", "r.min.d.therm")]), ]
  fit <- nnet::multinom(m.infls ~ r.min.d.therm * know, data = data, trace = FALSE, Hess = TRUE, maxit = 2000)
  changed <- data
  changed$r.min.d.therm <- 0
  actual <- multinomial_average(fit, changed)
  expect_gt(max(abs(actual$summary$estimate - colMeans(predict(fit, type = "probs")))), .001)
  beta <- stats::coef(fit)
  x <- stats::model.matrix(~ r.min.d.therm * know, changed)
  evaluate <- function(b) {
    linear <- cbind(0, x %*% t(matrix(b, nrow = nrow(beta), byrow = TRUE)))
    probability <- exp(linear - apply(linear, 1, max))
    colMeans(probability / rowSums(probability))
  }
  b <- as.vector(t(beta))
  gradient <- vapply(seq_along(b), function(j) {
    plus <- minus <- b
    plus[j] <- plus[j] + 1e-5
    minus[j] <- minus[j] - 1e-5
    (evaluate(plus) - evaluate(minus)) / 2e-5
  }, numeric(nrow(beta) + 1))
  expect_equal(actual$gradient, gradient, tolerance = 1e-7, ignore_attr = TRUE)
  items <- historical_items() |> dplyr::filter(study == "nes88", item == "infl", key == "archived")
  result <- historical_scenarios(items)
  expect_equal(length(unique(result$n)), 1L)
  expect_gt(max(abs(result$difference[result$scenario == "neutral_partisanship"])), .001)
  expect_true(all(abs(result$difference[result$scenario == "observed"]) < 1e-12))
  expect_equal(sum(result$estimate[result$scenario == "zero_knowledge"]), 1, tolerance = 1e-8)
})

test_that("official annual benchmarks reverse the two archived 2004 keys", {
  items <- historical_items()
  distributions <- historical_distributions(items)
  get <- function(item, key) {
    dplyr::filter(
      distributions, study == "nes04", .data$item == .env$item, .data$key == .env$key,
      party == "all", response == "cor"
    )$share
  }
  expect_equal(get("unemp", "archived"), 501 / 1087)
  expect_equal(get("unemp", "annual_benchmark"), 266 / 1087)
  expect_equal(get("infl", "archived"), 55 / 1086)
  expect_equal(get("infl", "annual_benchmark"), 524 / 1086)
  btp <- dplyr::filter(items, study == "btp04")
  expect_gt(mean(abs(btp$knowledge - btp$knowledge_without_target), na.rm = TRUE), .01)
  expect_equal(sum(btp$response == "dk", na.rm = TRUE), 145L)
  expect_equal(sum(is.na(btp$response)), 2L)
})

test_that("latent response models respect the observable probability distribution", {
  cells <- expand.grid(
    a = c("cor", "incor", "same", "dk"), b = c("cor", "incor", "same", "dk"),
    c = c("cor", "incor", "same", "dk"), stringsAsFactors = FALSE
  )
  result <- latent_response_models(cells, c("a", "b", "c"), starts = 2, maxiter = 500)
  expect_equal(result$diagnostics$n, rep(64L, 3))
  expect_equal(result$diagnostics$parameters, c(9, 19, 29))
  expect_lt(result$diagnostics$joint_total_variation[1], 1e-10)
  expect_equal(sum(dplyr::filter(result$profiles, classes == 2, item == "a", response == "cor")$class_share), 1)
  expect_error(latent_response_models(cells, "a"), "At least three")
  cells$a[1] <- "unexpected"
  expect_error(latent_response_models(cells, c("a", "b", "c")), "Unknown")
})


test_that("1992 raw nonresponse is distinct from DK and party timing is explicit", {
  data <- historical_items() |> dplyr::filter(study == "nes92")
  x <- dplyr::filter(data, item == "econ4j", party_basis == "1990_panel")
  expect_equal(sum(x$response == "dk", na.rm = TRUE), 48L)
  expect_equal(sum(is.na(x$response)), 178L)
  expect_equal(sum(!is.na(x$response)), 2307L)
  current <- dplyr::filter(data, item == "econ4j", party_basis == "contemporaneous")
  expect_equal(sum(current$party == "rep", na.rm = TRUE), 929L)
  expect_equal(sum(current$party == "dem", na.rm = TRUE), 1229L)
  expect_equal(sum(x$party == "rep", na.rm = TRUE), 500L)
  expect_equal(sum(x$party == "dem", na.rm = TRUE), 710L)
  expect_equal(anyDuplicated(data[c("study", "respondent", "item", "key", "party_basis")]), 0L)
})


test_that("saved historical distributions reproduce apart from documented Independent cells", {
  comparison <- read_tab("historical_saved_comparison.csv")
  expect_equal(nrow(comparison), 132L)
  expect_equal(sum(comparison$matches), 127L)
  differences <- dplyr::filter(comparison, !matches)
  expect_true(all(differences$study == "nes00" & differences$party == "ind"))
})
