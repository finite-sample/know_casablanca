verify_sources()
frame <- dplyr::bind_rows(read_alumni(), read_staff(), read_mturk_march(), read_mturk_july())
propositions <- read_propositions()
ratings <- scale_ratings(frame, propositions)
mc <- mc_responses(frame, read_mc_options())
by_question <- scale_by_question(ratings)

saveRDS(list(
  frame = frame, propositions = propositions, ratings = ratings, mc = mc, by_question = by_question
), prepared_data_file)
