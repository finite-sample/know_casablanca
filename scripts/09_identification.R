illustration <- identification_illustration(readRDS(prepared_data_file))
counts <- illustration$counts
joint <- illustration$joint
bounds <- identification_scenarios(counts)
selected <- bounds |>
  dplyr::filter(abs(alpha - beta) < 1e-10, round(alpha, 2) %in% c(0, .05, .10, .20, .50, 1))
equivalence <- equivalent_response_models((counts$q_lower + counts$q_upper) / 2) |>
  dplyr::mutate(arm = counts$arm[arm])
write_identification <- function(data, name) {
  readr::write_csv(data, file.path(table_dir, paste0("identification_", name, ".csv")), na = "")
}
write_identification(counts, "counts")
write_identification(bounds, "bounds")
write_identification(selected, "selected")
write_identification(equivalence, "equivalence")
write_identification(joint, "joint_patterns")

interval_text <- function(lower, upper, feasible = lower <= upper) {
  ifelse(feasible, paste0(
    "[", formatC(100 * lower, format = "f", digits = 1), ", ",
    formatC(100 * upper, format = "f", digits = 1), "]"
  ), "$\\varnothing$")
}
counts |>
  dplyr::transmute(
    arm = c("Multiple choice", "Scale endpoint"), total, positive, missing,
    observed = interval_text(q_lower, q_upper),
    uncertainty = interval_text(confidence_lower, confidence_upper)
  ) |>
  write_table(
    file.path(table_dir, "identification_counts.tex"), "lrrrrr",
    c("Format", "$N$", "Positive", "Missing", "Response rate (\\%)", "Simultaneous interval")
  )
selected |>
  dplyr::transmute(
    cap = pct(alpha), mc = interval_text(mc_lower, mc_upper), scale = interval_text(scale_lower, scale_upper),
    joint = interval_text(lower, upper, feasible),
    uncertainty = interval_text(confidence_lower, confidence_upper, confidence_feasible)
  ) |>
  write_table(
    file.path(table_dir, "identification_bounds.tex"), "lrrrr",
    c("Error cap", "MC bounds", "Scale bounds", "Joint bounds", "95\\% outer set")
  )
equivalence |>
  dplyr::transmute(
    construction,
    arm = ifelse(arm == "mc", "Multiple choice", "Scale endpoint"),
    prevalence = pct(prevalence, 1), sensitivity = pct(sensitivity, 1),
    false_positive = pct(false_positive, 1), response = pct(reconstructed_q, 1)
  ) |>
  write_table(
    file.path(table_dir, "identification_equivalence.tex"), "llrrrr",
    c("Construction", "Format", "$p$", "$s$", "$f$", "$q$")
  )
joint |>
  dplyr::transmute(
    true_endpoint = ifelse(true_endpoint, "Yes", "No"),
    false_endpoint = ifelse(false_endpoint, "Yes", "No"), n, share = pct(share, 1)
  ) |>
  write_table(
    file.path(table_dir, "identification_joint_patterns.tex"), "llrr",
    c("True statement at 10", "Any false statement at 10", "$n$", "Percent")
  )

diagonal <- bounds |> dplyr::filter(abs(alpha - beta) < 1e-10)
plot_data <- dplyr::bind_rows(
  diagonal |> dplyr::transmute(alpha, lower, upper, feasible, interval = "Plug-in bounds"),
  diagonal |> dplyr::transmute(alpha,
    lower = confidence_lower, upper = confidence_upper,
    feasible = confidence_feasible, interval = "95% outer confidence set"
  )
) |>
  dplyr::mutate(interval = factor(interval, levels = c("Plug-in bounds", "95% outer confidence set")))
plot <- ggplot2::ggplot(dplyr::filter(plot_data, feasible), ggplot2::aes(alpha, ymin = lower, ymax = upper)) +
  ggplot2::geom_ribbon(fill = "#6BAED6", alpha = .5) +
  ggplot2::geom_line(ggplot2::aes(y = lower), colour = "#08519C") +
  ggplot2::geom_line(ggplot2::aes(y = upper), colour = "#08519C") +
  ggplot2::geom_point(data = dplyr::filter(plot_data, !feasible), ggplot2::aes(y = 0), shape = 4, size = 2) +
  ggplot2::facet_wrap(~interval, nrow = 1) +
  ggplot2::scale_x_continuous(labels = scales::label_percent(), breaks = seq(0, 1, .25), limits = c(0, 1)) +
  ggplot2::scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  ggplot2::labs(
    x = "Common upper bound on each arm's false-positive and false-negative rates",
    y = "Shared misinformation prevalence",
    caption = "Crosses denote empty sets. Shading depends on the stated error restrictions."
  ) +
  theme_paper()
save_figure(plot, "identification_sensitivity")

pick <- function(cap) dplyr::filter(selected, abs(alpha - cap) < 1e-10)
ten <- pick(.10)
twenty <- pick(.20)
write_macros(c(
  idMcN = count(counts$total[1]), idScaleN = count(counts$total[2]),
  idMcPositive = count(counts$positive[1]), idScalePositive = count(counts$positive[2]),
  idMcMissing = count(counts$missing[1]), idScaleMissing = count(counts$missing[2]),
  idMcRate = pct(counts$q_lower[1], 1), idScaleRate = pct(counts$q_lower[2], 1),
  idLowPrevalence = pct(equivalence$prevalence[1], 1), idHighPrevalence = pct(equivalence$prevalence[3], 1),
  idTenBounds = interval_text(ten$lower, ten$upper, ten$feasible),
  idTenOuter = interval_text(ten$confidence_lower, ten$confidence_upper, ten$confidence_feasible),
  idTwentyBounds = interval_text(twenty$lower, twenty$upper, twenty$feasible),
  idTwentyOuter = interval_text(twenty$confidence_lower, twenty$confidence_upper, twenty$confidence_feasible),
  idJointComplete = count(joint$total[1]), idJointExcluded = count(joint$excluded[1]),
  idBothEndpoints = pct(joint$share[joint$true_endpoint & joint$false_endpoint], 1)
), file.path(table_dir, "identification_macros.tex"))
