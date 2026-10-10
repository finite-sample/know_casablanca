source(file.path("../..", "scripts", "00_config.R"))
purrr::walk(list.files(file.path("../..", "R"), full.names = TRUE), source)

binary_channels <- function(arms, alpha, beta) {
  lo <- array(0, c(arms, 2, 2))
  hi <- array(1, c(arms, 2, 2))
  lo[, 1, 1] <- 1 - alpha
  hi[, 2, 1] <- alpha
  hi[, 1, 2] <- beta
  lo[, 2, 2] <- 1 - beta
  list(lo = lo, hi = hi)
}

test_that("binary bounds handle endpoints, domains and empty intersections", {
  b <- binary_error_bounds(.3, alpha = .1, beta = .2)
  expect_equal(b$joint$lower, 2 / 9)
  expect_equal(b$joint$upper, .375)
  expect_true(b$joint$feasible)
  expect_equal(binary_error_bounds(c(0, 1))$joint$lower, 0)
  expect_equal(binary_error_bounds(c(0, 1))$joint$upper, 1)
  expect_equal(binary_error_bounds(0, alpha = 0, beta = 0)$joint$upper, 0)
  expect_equal(binary_error_bounds(1, alpha = 0, beta = 0)$joint$lower, 1)
  incompatible <- binary_error_bounds(c(.2, .5), alpha = 0, beta = 0)$joint
  expect_false(incompatible$feasible)
  expect_gt(incompatible$lower, incompatible$upper)
  expect_error(binary_error_bounds(NA_real_), "finite probabilities")
  expect_error(binary_error_bounds(.3, alpha = -.1), "finite probabilities")
  expect_error(binary_error_bounds(.3, beta = 1.1), "finite probabilities")
  expect_error(binary_error_bounds(c(.2, .3), alpha = c(.1, .2, .3)), "lengths")
  expect_error(binary_error_bounds(.5, .3), "Lower response")
})

test_that("the finite-state LP reproduces sharp binary bounds including error sums above one", {
  for (alpha in c(0, .1, .7, 1)) {
    for (beta in c(0, .2, .8, 1)) {
      q <- c(.2, .3)
      channels <- binary_channels(2, alpha, beta)
      lp <- finite_state_bounds(cbind(1 - q, q), channels$lo, channels$hi, target = 2)
      closed <- binary_error_bounds(q, alpha = alpha, beta = beta)$joint
      expect_identical(lp$feasible, closed$feasible)
      if (closed$feasible) {
        expect_equal(lp$lower, closed$lower, tolerance = 1e-7)
        expect_equal(lp$upper, closed$upper, tolerance = 1e-7)
      }
    }
  }
})

test_that("known channels identify state shares and unrestricted channels do not", {
  channels <- array(0, c(2, 3, 3), dimnames = list(NULL, NULL, c("K", "M", "I")))
  for (i in 1:3) channels[, i, i] <- 1
  q <- rbind(c(.2, .3, .5), c(.2, .3, .5))
  point <- finite_state_bounds(q, channels, channels, target = "M")
  expect_true(point$feasible)
  expect_equal(point$lower, .3)
  expect_equal(point$upper, .3)
  combined <- finite_state_bounds(q, channels, channels, target = c("K", "I"))
  expect_equal(combined$lower, .7)
  expect_equal(combined$upper, .7)
  unrestricted <- finite_state_bounds(q, channels * 0, channels * 0 + 1, target = "M")
  expect_equal(unrestricted$lower, 0)
  expect_equal(unrestricted$upper, 1)
  incompatible <- finite_state_bounds(rbind(c(.2, .3, .5), c(.3, .3, .4)), channels, channels, target = 2)
  expect_false(incompatible$feasible)
  expect_true(is.na(incompatible$lower))
  expect_true(is.na(incompatible$upper))
  expect_error(finite_state_bounds(q, channels, channels, target = "absent"), "Target")
})

test_that("invalid zero-mass channels cannot hide impossible stochastic restrictions", {
  channels <- binary_channels(1, 0, 0)
  channels$hi[1, , 2] <- 0
  channels$lo[1, , 2] <- 0
  expect_error(finite_state_bounds(matrix(c(1, 0), 1), channels$lo, channels$hi, target = 2), "stochastic")
  channels$lo[1, , 2] <- .6
  channels$hi[1, , 2] <- 1
  expect_error(finite_state_bounds(matrix(c(1, 0), 1), channels$lo, channels$hi, target = 2), "stochastic")
  expect_error(finite_state_bounds(
    matrix(c(.8, .8), 1), array(0, c(1, 2, 2)), array(1, c(1, 2, 2)),
    target = 1
  ), "probability distribution")
})

test_that("wider response and error restrictions cannot narrow feasible prevalence", {
  tight <- binary_error_bounds(c(.25, .3), alpha = .1, beta = .2)$joint
  wider <- binary_error_bounds(c(.2, .25), c(.3, .35), alpha = .2, beta = .3)$joint
  expect_lte(wider$lower, tight$lower)
  expect_gte(wider$upper, tight$upper)
  channels <- binary_channels(2, .2, .3)
  lp <- finite_state_bounds(cbind(1 - c(.3, .35), c(.2, .25)), channels$lo, channels$hi,
    target = 2, q_upper = cbind(1 - c(.2, .25), c(.3, .35))
  )
  expect_equal(lp$lower, wider$lower, tolerance = 1e-7)
  expect_equal(lp$upper, wider$upper, tolerance = 1e-7)
})

test_that("simultaneous response intervals retain missing outcomes and boundary counts", {
  x <- response_intervals(c(0, 8), c(2, 2), c(10, 10))
  expect_equal(x$q_lower, c(0, .8))
  expect_equal(x$q_upper, c(.2, 1))
  expect_equal(x$tail_probability, c(.0125, .0125))
  expect_equal(x$confidence_lower[1], 0)
  expect_equal(x$confidence_upper[2], 1)
  expect_equal(x$confidence_lower[2], qbeta(.0125, 8, 3))
  expect_equal(x$confidence_upper[1], qbeta(.9875, 3, 8))
  expect_error(response_intervals(9, 2, 10), "Invalid")
  expect_error(response_intervals(0, 0, 0), "Invalid")
})

test_that("distinct prevalence constructions reproduce every arm response rate", {
  for (q in list(c(.2, .3), c(0, 1), c(0, 0), c(1, 1))) {
    x <- equivalent_response_models(q)
    expect_equal(x$reconstructed_q, rep(q, 2))
    expect_true(all(x$sensitivity >= 0 & x$sensitivity <= 1))
    expect_true(all(x$false_positive >= 0 & x$false_positive <= 1))
    expect_lt(x$prevalence[1], x$prevalence[length(q) + 1])
  }
})

test_that("the illustration counts the named option without reinterpreting unselected options", {
  prepared <- readRDS(prepared_data_file)
  illustration <- identification_illustration(prepared)
  expect_identical(illustration$counts$arm, c("mc", "scale"))
  expect_equal(illustration$counts$total, c(557, 502))
  expect_equal(illustration$counts$positive[1], 125)
  expect_equal(illustration$counts$missing, c(0, 0))
  raw <- read_qualtrics("mturk_march_2017.csv")
  raw <- raw[raw$reticence_guessing == "scale" & !is.na(raw$reticence_guessing), ]
  expect_equal(illustration$counts$positive[2], sum(raw$rg_s_aca_2 == "10", na.rm = TRUE))
  expect_equal(sum(illustration$joint$n), 502)
  expect_equal(sum(illustration$joint$share), 1)
  expect_equal(unique(illustration$joint$excluded), 0)
  modified <- prepared
  target <- which(modified$ratings$study == "mturk_march" & modified$ratings$prop_id == "m_aca_single_payer")[1]
  modified$ratings$rating[target] <- NA_real_
  missing <- identification_illustration(modified)
  expect_equal(missing$counts$missing, c(0, 1))
  expect_equal(sum(missing$joint$n), 501)
  expect_equal(unique(missing$joint$excluded), 1)
  expect_equal(missing$counts$q_upper[2] - missing$counts$q_lower[2], 1 / 502)
})

test_that("distinct five-state mixtures yield the same known three-category response distribution", {
  channel <- rbind(c(1, 1, 0, 0, 0), c(0, 0, 1, 0, 0), c(0, 0, 0, 1, 1))
  first <- c(.4, 0, .3, 0, .3)
  second <- c(.1, .3, .3, .3, 0)
  expect_equal(drop(channel %*% first), c(.4, .3, .3))
  expect_equal(drop(channel %*% second), c(.4, .3, .3))
  restriction <- array(channel, c(1, 3, 5))
  bounds <- finite_state_bounds(matrix(c(.4, .3, .3), 1), restriction, restriction, target = 5)
  expect_true(bounds$feasible)
  expect_equal(bounds$lower, 0)
  expect_equal(bounds$upper, .3)
})


test_that("illustration rejects key changes and accounts for completely absent rating records", {
  prepared <- readRDS(prepared_data_file)
  target <- which(prepared$ratings$study == "mturk_march" & prepared$ratings$prop_id == "m_aca_single_payer")[1]
  modified <- prepared
  modified$ratings$truth[target] <- TRUE
  expect_error(identification_illustration(modified), "false answer key")
  respondent <- prepared$ratings$respondent[target]
  modified <- prepared
  modified$ratings <- dplyr::filter(modified$ratings, respondent != !!respondent)
  result <- identification_illustration(modified)
  expect_equal(result$counts$total, c(557, 502))
  expect_equal(result$counts$missing, c(0, 1))
  expect_equal(unique(result$joint$excluded), 1)
  expect_equal(sum(result$joint$n), 501)
})


test_that("rank-deficient channels can identify a target or a boundary composition", {
  target_channel <- array(rbind(c(1, 1, 1, 1, 0), c(0, 0, 0, 0, 1)), c(1, 2, 5))
  target <- finite_state_bounds(matrix(c(.7, .3), 1), target_channel, target_channel, target = 5)
  expect_equal(target$lower, .3)
  expect_equal(target$upper, .3)
  other <- finite_state_bounds(matrix(c(.7, .3), 1), target_channel, target_channel, target = 1)
  expect_equal(other$lower, 0)
  expect_equal(other$upper, .7)
  boundary_channel <- array(rbind(c(1, 0, 0), c(0, 1, 1)), c(1, 2, 3))
  for (state in 1:3) {
    boundary <- finite_state_bounds(matrix(c(1, 0), 1), boundary_channel, boundary_channel, target = state)
    expect_equal(boundary$lower, as.numeric(state == 1))
    expect_equal(boundary$upper, as.numeric(state == 1))
  }
})
