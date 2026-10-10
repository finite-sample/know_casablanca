project_root <- rprojroot::find_root(rprojroot::has_file("DESCRIPTION"))
project_file <- function(...) file.path(project_root, ...)
raw_dir <- project_file("data", "raw")
derived_dir <- project_file("data", "derived")
table_dir <- project_file("tabs")
figure_dir <- project_file("figs")
prepared_data_file <- file.path(derived_dir, "prepared_data.rds")
figure_sizes <- list(format = c(width = 6.5, height = 6.2), partisan_gaps = c(width = 6.5, height = 7.6))
figure_dpi <- 180
reference_colour <- "grey60"
table_style <- list(
  TableStyle = list(font_size = "small", column_padding = "6pt", row_stretch = 1),
  BeliefTableStyle = list(font_size = "footnotesize", column_padding = "2pt", row_stretch = 1),
  PropositionTableStyle = list(font_size = "footnotesize", column_padding = "3pt", row_stretch = 1)
)

raw_files <- c(
  alumni_2010.csv = "7baf68c339ab36d99eac7ff018c6c4e1179b13443dd8450f1d0d1c6b13ab6c82",
  staff_2010.csv = "891f04e9cfe768d0b666a3133a23da05478b90c4a6653285fe197d263e7fb5c2",
  mturk_march_2017.csv = "845864d3861868f27a781aa3ed5875e77b5d8587f216eff22930416521808f02",
  mturk_july_2017.csv = "62aa2380baf0fcb4ca7aeb64d552de597c2927d61289d27146072e70f329fa67"
)

study_labels <- c(
  alumni = "Alumni 2010",
  staff = "Staff 2010",
  mturk_march = "MTurk March 2017",
  mturk_july = "MTurk July 2017"
)

question_labels <- c(
  aca1 = "ACA: coverage, taxes, screening", aca2 = "ACA: Medicare",
  birth = "Obama born in the U.S.", religion = "Obama is a Muslim",
  illegal = "ACA helps illegal immigrants buy insurance", death = "ACA creates death panels",
  increase = "Warming is human-caused", science = "Most scientists doubt warming",
  fraud = "Trump won most legal votes", mmr = "MMR vaccine causes autism",
  deficit = "Deficit has risen since 2012"
)
measure_labels <- c(
  mc_media = "Media-poll wording, no DK",
  mc = "Multiple choice with DK",
  scale_lenient = "0-10 scale, lenient",
  scale_strict = "0-10 scale, strict"
)
measure_colours <- c(
  mc_media = "grey55", mc = "grey20", scale_lenient = "#6BAED6", scale_strict = "#08519C"
)

congenial_labels <- c(
  R = "error congenial to Republicans", D = "error congenial to Democrats", none = "congenial to neither"
)

theme_paper <- function() {
  ggplot2::theme_minimal(base_size = 11, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0),
      plot.title.position = "plot"
    )
}
