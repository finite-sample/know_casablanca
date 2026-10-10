latent_response_models <- function(data, items, starts = 100, maxiter = 10000, seed = 4102018) {
  if (length(items) < 3) stop("At least three response indicators are required")
  labels <- c("cor", "incor", "same", "dk")
  if (any(!is.na(as.matrix(data[items])) & !as.matrix(data[items]) %in% labels)) {
    stop("Unknown historical response category")
  }
  complete <- stats::complete.cases(data[items])
  responses <- data[complete, items, drop = FALSE]
  encoded <- as.data.frame(lapply(responses, \(x) match(x, labels)))
  if (any(vapply(encoded, \(x) length(unique(x)), integer(1)) != length(labels))) {
    stop("All four response categories must occur in each indicator")
  }
  formula <- stats::as.formula(paste0("cbind(", paste(items, collapse = ","), ") ~ 1"))
  fits <- lapply(1:3, function(classes) {
    set.seed(seed + classes)
    poLCA::poLCA(
      formula, encoded,
      nclass = classes, nrep = starts, maxiter = maxiter,
      tol = 1e-8, verbose = FALSE, calc.se = FALSE
    )
  })
  diagnostics <- purrr::map2(fits, 1:3, function(fit, classes) {
    cells <- expand.grid(rep(list(seq_along(labels)), length(items)))
    probabilities <- apply(cells, 1, function(cell) {
      sum(vapply(seq_len(classes), function(k) {
        fit$P[k] * prod(vapply(seq_along(items), \(j) fit$probs[[j]][k, cell[j]], numeric(1)))
      }, numeric(1)))
    })
    encode <- \(x) apply(x, 1, paste, collapse = ":")
    observed <- table(factor(encode(encoded), levels = encode(cells))) / nrow(encoded)
    attempts <- if (length(fit$attempts)) fit$attempts else fit$llik
    tibble::tibble(
      classes,
      total = nrow(data), n = nrow(encoded), excluded = sum(!complete),
      parameters = fit$npar, log_likelihood = fit$llik, aic = fit$aic, bic = fit$bic,
      iterations = fit$numiter, iteration_limit = maxiter,
      converged = fit$numiter < maxiter, starts = length(attempts),
      starts_at_best = sum(abs(attempts - fit$llik) < 1e-5),
      worst_start_loglik = min(attempts), min_class_share = min(fit$P),
      boundary_probabilities = sum(unlist(fit$probs) < 1e-6 | unlist(fit$probs) > 1 - 1e-6),
      joint_total_variation = sum(abs(as.numeric(observed) - probabilities)) / 2,
      max_cell_discrepancy = max(abs(as.numeric(observed) - probabilities))
    )
  }) |>
    purrr::list_rbind()
  profiles <- purrr::map2(fits, 1:3, function(fit, classes) {
    correct <- rowMeans(do.call(cbind, lapply(fit$probs, \(p) p[, 1])))
    order <- order(correct, decreasing = TRUE)
    purrr::map(seq_along(items), function(j) {
      tibble::tibble(
        classes,
        class = rep(seq_len(classes), each = length(labels)), item = items[j],
        response = rep(labels, times = length(fit$P)),
        probability = as.vector(t(fit$probs[[j]][order, , drop = FALSE])),
        class_share = rep(fit$P[order], each = length(labels))
      )
    }) |>
      purrr::list_rbind()
  }) |>
    purrr::list_rbind()
  list(diagnostics = diagnostics, profiles = profiles)
}
