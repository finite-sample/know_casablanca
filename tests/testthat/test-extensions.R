source(file.path("../..", "scripts", "00_config.R"))
purrr::walk(list.files(file.path("../..", "R"), full.names = TRUE), source)

test_that("the historical schemes implement every boundary and reverse false propositions", {
  expected <- list(
    c("misinformation", rep("incorrect_belief", 3), rep("middle", 3), rep("correct_belief", 3), "knowledge"),
    c(
      rep("misinformation", 2), rep("incorrect_belief", 2), rep("middle", 3), rep("correct_belief", 2),
      rep("knowledge", 2)
    ),
    c(
      rep("misinformation", 2), rep("incorrect_belief", 3), "middle", rep("correct_belief", 3),
      rep("knowledge", 2)
    )
  )
  for (scheme in 1:3) {
    expect_identical(as.character(planned_belief_state(0:10, rep(TRUE, 11), scheme)), expected[[scheme]])
    expect_identical(as.character(planned_belief_state(10:0, rep(FALSE, 11), scheme)), expected[[scheme]])
    expect_true(is.na(planned_belief_state(NA_real_, TRUE, scheme)))
  }
  expect_error(planned_belief_state(11, TRUE, 1), "Ratings")
  expect_error(planned_belief_state(1.5, TRUE, 1), "Ratings")
  expect_error(planned_belief_state(5, TRUE, 4), "scheme")
})

test_that("respondent indices preserve missingness and give respondents equal weight", {
  ratings <- tibble::tibble(
    study = "toy", respondent = rep(c("a", "b", "c"), each = 2), prop_id = rep(c("p", "q"), 3),
    truth = rep(c(TRUE, FALSE), 3), rating = c(10, NA, 0, 5, NA, NA)
  )
  indices <- planned_indices(ratings)
  all <- dplyr::filter(indices, scheme == 1, kind == "all")
  expect_equal(all$answered, c(1L, 2L, 0L))
  expect_equal(all$knowledge, c(1, 0, NA))
  expect_equal(all$misinformation, c(0, .5, NA))
  samples <- index_samples(indices) |> dplyr::filter(scheme == 1, kind == "all")
  complete <- dplyr::filter(samples, sample == "complete_items")
  available <- dplyr::filter(samples, sample == "available_items")
  expect_equal(complete$respondent, "b")
  expect_equal(mean(available$knowledge), .5)
  expect_equal(rowSums(available[extension_states]), c(1, 1))
  distribution <- rating_distributions(ratings)
  expect_equal(nrow(distribution), 24L)
  expect_equal(sum(distribution$count), nrow(ratings))
  expect_equal(sum(distribution$count[is.na(distribution$score)]), 3)
  expect_error(planned_indices(dplyr::bind_rows(ratings, ratings[1, ])), "Duplicate")
})

test_that("HC3 direct contrasts agree with independent matrix algebra", {
  set.seed(430)
  shares <- matrix(rexp(400), ncol = 5)
  shares <- shares / rowSums(shares)
  data <- tibble::as_tibble(shares, .name_repair = \(x) extension_states)
  data$interest <- 3 + 2 * data$knowledge - data$misinformation + rnorm(nrow(data), sd = .2)
  result <- engagement_model(data, "interest")
  x <- cbind(1, as.matrix(data[setdiff(extension_states, "middle")]))
  inverse <- solve(crossprod(x))
  beta <- inverse %*% crossprod(x, data$interest)
  residual <- as.vector(data$interest - x %*% beta)
  leverage <- rowSums((x %*% inverse) * x)
  covariance <- inverse %*% crossprod(x, x * (residual / (1 - leverage))^2) %*% inverse
  contrast <- c(0, .1, 0, 0, -.1)
  direct <- dplyr::filter(result, term == "knowledge_minus_misinformation")
  expect_equal(direct$estimate, as.numeric(contrast %*% beta), tolerance = 1e-10)
  expect_equal(direct$std_error, sqrt(as.numeric(contrast %*% covariance %*% contrast)), tolerance = 1e-10)
  expect_true(all(result$status == "estimated"))
  expect_equal(direct$residual_df, nrow(data) - 5)
  data$interest[1:2] <- NA
  missing <- engagement_model(data, "interest")
  expect_true(all(missing$missing_outcome == 2 & missing$n == 78 & missing$eligible == 80))
  data$misinformation <- data$knowledge
  expect_true(all(engagement_model(data, "interest")$status == "rank_deficient"))
  expect_true(all(engagement_model(data[1:4, ], "interest")$status == "insufficient_data"))
})

test_that("partisan intensity is distance from neutrality, not party direction", {
  march <- read_mturk_march()
  july <- read_mturk_july()
  for (data in list(march, july)) {
    expect_equal(data$partisan_intensity, 2 * abs(data$partisan_position - 5))
    expect_true(all(data$partisan_intensity[data$partisan_position == 0] == 10, na.rm = TRUE))
    expect_true(all(data$partisan_intensity[data$partisan_position == 10] == 10, na.rm = TRUE))
    expect_true(all(data$partisan_intensity[data$partisan_position == 5] == 0, na.rm = TRUE))
    expect_true(all(is.na(data$voting_intention) | data$voting_intention %in% 0:10))
  }
})
