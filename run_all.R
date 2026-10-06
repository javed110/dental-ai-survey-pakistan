#!/usr/bin/env Rscript
# Single entry point for the frozen local manuscript reproducibility package.
# Base R only for manuscript statistics. Pillow/Python is used for S2 Fig.
# Usage: Rscript run_all.R [output_directory] [--with-pilot]
options(stringsAsFactors=FALSE, scipen=999, width=140)
if (.Platform$OS.type=='windows') {
  locale_result <- Sys.setlocale('LC_CTYPE', '.UTF-8')
  if (!nzchar(locale_result)) stop('A UTF-8 locale is required to read the codebook.')
}
full_args <- commandArgs(trailingOnly=FALSE)
file_arg <- grep('^--file=', full_args, value=TRUE)
if (length(file_arg)!=1L) stop('Run with Rscript run_all.R, rather than source().')
root <- dirname(normalizePath(sub('^--file=', '', file_arg), mustWork=TRUE))
args <- commandArgs(trailingOnly=TRUE)
with_pilot <- '--with-pilot' %in% args
args <- args[args!='--with-pilot']
if (length(args)>1L) stop('Usage: Rscript run_all.R [output_directory] [--with-pilot]')
outdir <- if(length(args)) args[1] else file.path(root, 'results')
dir.create(outdir, recursive=TRUE, showWarnings=FALSE)
outdir <- normalizePath(outdir, mustWork=TRUE)
data_file <- file.path(root, 'data', 'dental_ai_complete_clean.csv')
read <- function(path) read.csv(path, check.names=FALSE, fileEncoding='UTF-8-BOM')
emit <- function(x, filename) write.csv(x, file.path(outdir, filename), row.names=FALSE, na='')

# Verify the frozen input and all codebook files before any analysis.
hashes <- read(file.path(root, 'data', 'checksums.csv'))
actual_hash <- unname(tools::md5sum(file.path(root, 'data', hashes$file)))
stopifnot(!anyNA(actual_hash), identical(actual_hash, hashes$md5))
d <- read(data_file)
book <- read(file.path(root, 'data', 'codebook.csv'))
labels <- read(file.path(root, 'data', 'value_labels.csv'))
stopifnot(nrow(d)==301L, ncol(d)==42L, identical(names(d), book$variable),
          sum(is.na(d))==0L, all(vapply(d, is.numeric, logical(1L))),
          all(vapply(d, function(x) all(x==as.integer(x)), logical(1L))))
for (j in seq_len(ncol(d))) {
  allowed <- book$valid_codes[j]
  if (!is.na(allowed) && nzchar(allowed))
    stopifnot(all(d[[j]] %in% as.integer(strsplit(allowed, '|', fixed=TRUE)[[1]])))
}
stopifnot(sum(duplicated(d))==1L)
derived <- read(file.path(root, 'data', 'derived_analysis_variables.csv'))
stopifnot(identical(derived$data_row, seq_len(nrow(d))),
  all(derived$clinical_tool_use == as.integer(d[[8]]==3)),
  all(derived$academic_tool_use == as.integer(d[[7]]==3)),
  all(derived$diagnostic_confidence == as.integer(d[[36]] %in% c(3,4))),
  all(derived$diagnostic_willingness == as.integer(d[[42]]==1)),
  all(derived$selected_barrier_item_count == rowSums(d[,15:21]==1)),
  all(derived$selected_training_method_count == rowSums(d[,29:34]==1)))
cat('Input checks passed: 301 rows, 42 source fields, no missing/invalid codes; source responses unchanged.\n')

run_script <- function(filename) {
  cat('Running', filename, '\n')
  env <- new.env(parent=globalenv())
  # Each legacy script sees its documented data-path argument in an isolated environment.
  env$commandArgs <- function(trailingOnly=TRUE) data_file
  log <- file(file.path(outdir, sub('\\.R$', '_results.txt', filename)), open='wt')
  sink(log); sink(log, type='message')
  on.exit({sink(type='message'); sink(); close(log)}, add=TRUE)
  sys.source(file.path(root, filename), envir=env, keep.source=FALSE)
  env
}
main <- run_script('analysis_main.R')
paired <- run_script('analysis_paired.R')
dag <- run_script('analysis_dag_robustness.R')
med <- run_script('analysis_mediation_decomposition.R')

# Tidy machine-readable outputs supplement the full printed regression logs.
distribution <- do.call(rbind, lapply(names(d), function(v) {
  t <- table(d[[v]])
  codes <- as.integer(names(t))
  lv <- labels[labels$variable==v,]
  text <- lv$display_label[match(codes, lv$code)]
  text[is.na(text)] <- as.character(codes[is.na(text)])
  data.frame(variable=v, code=codes, label=text, n=as.integer(t),
             denominator=nrow(d), percent=100*as.integer(t)/nrow(d))
}))
emit(distribution, 'all_42_field_distributions.csv')
emit(distribution[distribution$variable %in% names(d)[c(1,2,4,5)],], 'table1_participant_characteristics.csv')
emit(data.frame(variable='Years of clinical practice', n=nrow(d),
     median=median(d[[3]]), q1=unname(quantile(d[[3]], .25)),
     q3=unname(quantile(d[[3]], .75)), minimum=min(d[[3]]), maximum=max(d[[3]])),
     'practice_years_summary.csv')

barrier_columns <- names(d)[c(15,16,17,19,20,18,21)]
item_names <- c('AI familiarity', 'Diagnostic confidence', 'Academic tool use', 'Clinical tool use',
                'Education willingness', 'Diagnostic willingness', barrier_columns)
item_values <- c(sum(derived$familiarity_positive), sum(derived$diagnostic_confidence), sum(derived$academic_tool_use),
                 sum(derived$clinical_tool_use), sum(derived$education_willingness),
                 sum(derived$diagnostic_willingness), colSums(d[,barrier_columns]==1))
table2 <- data.frame(item=item_names, t(vapply(item_values, main$wilson, numeric(5), n=nrow(d))))
stopifnot(nrow(table2)==13L)
emit(table2, 'table2_responses_and_barriers.csv')
coef_table <- function(model, name) {
  s <- coef(summary(model))
  data.frame(model=name, term=rownames(s), coefficient=s[,1], standard_error=s[,2],
    odds_ratio=exp(s[,1]), lower=exp(s[,1]-qnorm(.975)*s[,2]),
    upper=exp(s[,1]+qnorm(.975)*s[,2]), p_value=s[,4], row.names=NULL)
}
table3 <- rbind(coef_table(main$m_use, 'Clinical tool use'),
                coef_table(main$m_diag, 'Diagnostic willingness'))
emit(table3, 'table3_complete_regression_coefficients.csv')
models4 <- c('base_use','familiar_use','base_willing','extended_willing',
             'no_familiar_willing','reverse_use','familiar_willing')
emit(do.call(rbind, lapply(models4, function(nm) coef_table(dag[[nm]], nm))),
     'table4_robustness_complete_coefficients.csv')
table5 <- med$out
numeric_components <- c('total','total_low','total_high','direct','direct_low',
                       'direct_high','indirect','indirect_low','indirect_high')
table5[,numeric_components] <- 100*table5[,numeric_components]
names(table5)[match(numeric_components,names(table5))] <- paste0(numeric_components, '_pp')
emit(table5, 'table5_all_descriptive_pathways.csv')
diagnostics <- do.call(rbind, lapply(med$diagnostics, function(x)
  data.frame(order=x$panel, contrast=x$contrast, point_flagged=x$point_extreme,
             flagged_bootstrap=x$flagged_replicates, valid_bootstrap=x$valid_replicates,
             maximum_absolute_coefficient=x$max_abs_coefficient,
             maximum_endpoint_shift_pp=x$max_endpoint_shift_pp)))
emit(diagnostics, 'bootstrap_numerical_diagnostics.csv')
emit(as.data.frame(table(confidence=paired$trust, willingness=paired$diag)), 'figure1_paired_cells.csv')
emit(data.frame(contrast='Confidence minus willingness', difference_pp=100*mean(paired$trust-paired$diag),
     lower_pp=100*unname(quantile(paired$boot,.025)), upper_pp=100*unname(quantile(paired$boot,.975)),
     bootstrap_samples=length(paired$boot)), 'paired_difference.csv')
emit(data.frame(contrast='Clinical tool use positive versus negative',
     predicted_positive=main$p1, predicted_negative=main$p0,
     difference_pp=100*(main$p1-main$p0),
     lower_pp=100*unname(quantile(main$boot_diff,.025,na.rm=TRUE)),
     upper_pp=100*unname(quantile(main$boot_diff,.975,na.rm=TRUE)),
     valid_bootstrap=sum(is.finite(main$boot_diff))), 'standardized_use_association.csv')

# Locked manuscript checks test this package against the independently reviewed draft.
reference <- read(file.path(root,'reference_table5.csv'))
stopifnot(identical(table5$panel, reference$panel), identical(table5$contrast, reference$contrast))
observed <- as.matrix(table5[,paste0(numeric_components,'_pp')])
expected <- as.matrix(reference[,paste0(numeric_components,'_pp')])
stopifnot(all(abs(observed-expected)<=.05000001),
  sum(derived$clinical_tool_use)==110L, sum(derived$diagnostic_willingness)==155L,
  sum(derived$diagnostic_confidence)==216L,
  identical(as.integer(table(paired$trust,paired$diag)), c(59L,87L,26L,129L)),
  abs(exp(coef(main$m_diag)['clinical_use'])-1.9783)<.0001,
  all(med$out$bootstrap_valid==1000L), sum(diagnostics$flagged_bootstrap)==45L,
  max(abs(med$out$total-med$out$direct-med$out$indirect))<1e-12)
writeLines(c('PASS: frozen data integrity, schema and recodes',
  'PASS: 108 manuscript Table 5 values match to reported rounding',
  'PASS: paired cells, response totals and primary adjusted odds ratio',
  'PASS: 12000 converged finite decomposition bootstrap replicates; 45 numerical flags',
  'PASS: overall = direct + indirect for all 12 descriptive contrasts',
  'Scope: computational reproducibility of supplied coded data; not original-response validation'),
  file.path(outdir, 'reproduction_checks.txt'))
saveRDS(list(clinical_use_model=main$m_use, willingness_model=main$m_diag,
             standardized_bootstrap=main$boot_diff, paired_bootstrap=paired$boot,
             pathway_estimates=med$out, pathway_diagnostics=med$diagnostics),
        file.path(outdir, 'analysis_objects.rds'), version=3)

figure_env <- new.env(parent=globalenv())
figure_env$data_file <- data_file
figure_env$output_dir <- outdir
sys.source(file.path(root, 'render_figures.R'), envir=figure_env)
python <- Sys.getenv('DENTAL_AI_PYTHON')
if (!nzchar(python)) {
  candidates <- Sys.which(c('python3','python'))
  candidates <- candidates[nzchar(candidates)]
  if (length(candidates)) python <- unname(candidates[1])
}
if (!nzchar(python)) stop('Statistics complete. Set DENTAL_AI_PYTHON to Python with Pillow to reproduce S2 Fig.')
status <- system2(python, c(shQuote(file.path(root,'build_dags.py')), shQuote(outdir)))
if (!identical(status, 0L)) stop('S2 figure failed. Install Pillow in the selected Python environment and rerun.')
if (with_pilot) {
  if (!requireNamespace('rpart', quietly=TRUE)) stop('Optional pilot requires the recommended R package rpart.')
  pilot <- run_script('analysis_super_learner_feasibility.R')
}
capture.output(sessionInfo(), file=file.path(outdir, 'session_info.txt'))
writeLines(c(paste('RNG:',paste(RNGkind(),collapse=', ')),
  'Main standardized bootstrap: seed 20260925, B=2000',
  'Paired bootstrap: seed 20260925, B=5000',
  'Pathway bootstrap: seed 20260926, B=1000 for each of 12 contrasts',
  paste('Input MD5:', unname(tools::md5sum(data_file))),
  'No network access, submission, email, or publication is performed by these scripts.'),
  file.path(outdir, 'run_details.txt'))
cat('COMPLETE:', outdir, '\n')
