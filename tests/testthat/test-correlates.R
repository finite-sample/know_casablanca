source(file.path("../..", "scripts", "00_config.R"))
purrr::walk(list.files(file.path("../..", "R"), full.names = TRUE), source)

test_that("intake conflicts are resolved by field and cannot multiply respondents", {
  intake <- tibble::tibble(
    respondent = c("a", "a", "b", "b", NA), year = c("1946", "1957", "1980", NA, "1990"),
    gender = c("Female", "Male", "Female", "Female", "Male"), race = c("White", "White", NA, NA, "White")
  )
  result <- collapse_intake(intake)
  expect_equal(sum(result$conflict), 2L)
  expect_true(all(is.na(result$value[result$conflict])))
  expect_equal(result$value[result$respondent == "a" & result$field == "race"], "White")
  expect_equal(result$value[result$respondent == "b" & result$field == "year"], "1980")
  expect_equal(nrow(result), 6L)
  expect_equal(strict_rating(c("5", "50", "90", "10", "refused")), c(5, NA, NA, 10, NA))
  expect_equal(
    race_selections(data.frame(a = c(NA, "White", "White"), b = c(NA, NA, "Black"))),
    c(NA, "White", "Multiple races")
  )
})

test_that("verified panel measures and linkage retain their documented samples", {
  prepared <- readRDS(prepared_data_file)
  result <- read_correlates(prepared$frame)
  expect_equal(nrow(result$data), nrow(prepared$frame))
  expect_equal(anyDuplicated(result$data[c("study", "respondent")]), 0L)
  alumni <- dplyr::filter(result$data, study == "alumni", arm == "scale")
  staff <- dplyr::filter(result$data, study == "staff", arm == "scale")
  expect_equal(sum(alumni$intake_match), 147L)
  expect_equal(sum(!is.na(alumni$age)), 145L)
  expect_equal(sum(!is.na(alumni$ideology)), 158L)
  expect_equal(sum(!is.na(staff$ideology)), 88L)
  expect_true(all(is.na(alumni$age[alumni$respondent == "FY947737"])))
  expect_equal(sum(!is.na(alumni$voting_intention_2010)), 160L)
  expect_equal(sum(!is.na(staff$voting_intention_2010)), 90L)
  expect_identical(alumni$voting_intention_2010, alumni$voting_rescaled)
  expect_identical(staff$voting_intention_2010, staff$voting_rescaled)
})
