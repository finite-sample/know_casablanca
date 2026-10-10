source("scripts/00_config.R")
for (module in c("sources.R", "beliefs.R", "analysis.R", "paper.R", "extensions.R")) {
  source(project_file("R", module))
}
for (path in c(derived_dir, table_dir, figure_dir)) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
for (stage in c("01_prepare_data.R", "02_estimate.R", "03_figures.R", "04_tables.R", "05_extensions.R")) {
  sys.source(project_file("scripts", stage), envir = new.env(parent = globalenv()))
}
