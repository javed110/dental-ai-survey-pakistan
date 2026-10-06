#!/usr/bin/env Rscript
# Descriptive standardization of observed-node chains, not causal mediation.
# Both DAG directions are evaluated because use and willingness were concurrent.
options(stringsAsFactors=FALSE, scipen=999)
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1L || !file.exists(args[1]))
  stop('Usage: Rscript analysis_mediation_decomposition.R approved_analytic_data.csv')
d <- read.csv(args[1], check.names=FALSE, fileEncoding='UTF-8-BOM')
stopifnot(nrow(d)==301L, ncol(d)==42L, sum(is.na(d))==0L)

d$use <- as.integer(d[['Have you used AI tools in clinical practice']]==3)
d$willing <- as.integer(d[['Willingness to base definitive diagnosis on AI generated']]==1)
d$older <- as.integer(d[['Age']]>=2)
d$female <- as.integer(d[['Gender']]==2)
d$general <- as.integer(d[['Primary Dental Specialisation']]==2)
d$setting <- factor(ifelse(d[['Type of dental practice']]==1,'Public',
                     ifelse(d[['Type of dental practice']]==2,'Private',
                     ifelse(d[['Type of dental practice']]==3,'Academic','Mixed'))),
                    levels=c('Academic','Public','Private','Mixed'))

# The functional F(x,xm) averages an outcome regression at exposure x over
# fitted mediator probabilities at exposure xm and the empirical covariate mix.
# Algebraically: total=direct+indirect on the risk-difference scale. This
# ordering-specific identity is descriptive and does not identify a mechanism.
# Direct = F(1,0)-F(0,0), indirect = F(1,1)-F(1,0), overall = F(1,1)-F(0,0).
# Each setting contrast averages over its own two-setting participant sample.
# Resampling whole respondent rows preserves the joint response pattern; it
# assumes independent respondents and cannot account for unrecorded site clusters.
functional <- function(dat, exposure, mediator, outcome, covars) {
  fm <- reformulate(c(exposure,covars), response=mediator)
  fy <- reformulate(c(paste0(exposure,'*',mediator),covars), response=outcome)
  mm <- suppressWarnings(glm(fm, data=dat, family=binomial()))
  ym <- suppressWarnings(glm(fy, data=dat, family=binomial()))
  if (!mm$converged || !ym$converged ||
      any(!is.finite(coef(mm))) || any(!is.finite(coef(ym))))
    return(rep(NA_real_,3L))
  g <- function(x,xm) {
    mn <- dat; mn[[exposure]] <- xm
    pm <- predict(mm,newdata=mn,type='response')
    y0 <- dat; y0[[exposure]] <- x; y0[[mediator]] <- 0L
    y1 <- dat; y1[[exposure]] <- x; y1[[mediator]] <- 1L
    py0 <- predict(ym,newdata=y0,type='response')
    py1 <- predict(ym,newdata=y1,type='response')
    mean((1-pm)*py0+pm*py1)
  }
  f00 <- g(0L,0L); f10 <- g(1L,0L); f11 <- g(1L,1L)
  ans <- c(total=f11-f00, direct=f10-f00, indirect=f11-f10)
  # Numerical screening is descriptive and never changes the returned estimates.
  # It is not a formal separation test and does not consume random draws.
  fit_extreme <- function(m)
    any(abs(coef(m))>15) || any(fitted(m)<1e-7 | fitted(m)>1-1e-7)
  attr(ans,'numerically_extreme') <- fit_extreme(mm) || fit_extreme(ym)
  attr(ans,'max_abs_coefficient') <- max(abs(c(coef(mm),coef(ym))))
  ans
}

specs <- list(
  list(label='Age 31-60 vs 20-30',x='older',subset=rep(TRUE,nrow(d)),
       z=c('female','general','setting')),
  list(label='Female vs male',x='female',subset=rep(TRUE,nrow(d)),
       z=c('older','general','setting')),
  list(label='General dentist vs other',x='general',subset=rep(TRUE,nrow(d)),
       z=c('older','female','setting')),
  list(label='Public vs academic-only',x='setting_exposure',
       subset=d$setting %in% c('Academic','Public'),z=c('older','female','general')),
  list(label='Private vs academic-only',x='setting_exposure',
       subset=d$setting %in% c('Academic','Private'),z=c('older','female','general')),
  list(label='Mixed vs academic-only',x='setting_exposure',
       subset=d$setting %in% c('Academic','Mixed'),z=c('older','female','general'))
)

set.seed(20260926)
B <- 1000L
results <- list()
diagnostics <- list()
for (panel in c('A','B')) {
  mediator <- if (panel=='A') 'use' else 'willing'
  outcome <- if (panel=='A') 'willing' else 'use'
  for (sp in specs) {
    dat <- d[sp$subset,,drop=FALSE]
    if (sp$x=='setting_exposure')
      dat$setting_exposure <- as.integer(dat$setting!='Academic')
    exposure <- sp$x
    stopifnot(all(table(dat[[exposure]])>0L))
    point <- functional(dat,exposure,mediator,outcome,sp$z)
    boot <- matrix(NA_real_,nrow=B,ncol=3L,
                   dimnames=list(NULL,c('total','direct','indirect')))
    boot_extreme <- logical(B)
    boot_max_coef <- rep(NA_real_,B)
    for (b in seq_len(B)) {
      ix <- sample.int(nrow(dat),nrow(dat),replace=TRUE)
      draw <- tryCatch(functional(dat[ix,,drop=FALSE],exposure,
                                  mediator,outcome,sp$z),
                       error=function(e) rep(NA_real_,3L))
      boot[b,] <- draw
      boot_extreme[b] <- isTRUE(attr(draw,'numerically_extreme'))
      mx <- attr(draw,'max_abs_coefficient')
      if (length(mx)==1L) boot_max_coef[b] <- mx
    }
    # Finite, converged output does not rule out sparse bootstrap fits. The
    # accompanying README documents a separate numerical-extremity diagnostic;
    # all primary replicates are retained rather than selectively discarded.
    valid <- complete.cases(boot)
    if (sum(valid)<950L) stop('Bootstrap instability: ',panel,' ',sp$label)
    stopifnot(isTRUE(all.equal(unname(point['total']),
                                unname(point['direct']+point['indirect']),
                                tolerance=1e-12)))
    ci <- apply(boot[valid,,drop=FALSE],2L,quantile,
                probs=c(.025,.975),names=FALSE)
    # Retain every valid replicate in the primary percentile interval. The
    # omission calculation only measures endpoint sensitivity to this screen.
    stable <- valid & !boot_extreme
    stable_ci <- if (sum(stable)>=2L)
      apply(boot[stable,,drop=FALSE],2L,quantile,
            probs=c(.025,.975),names=FALSE) else matrix(NA_real_,2L,3L)
    diagnostics[[length(diagnostics)+1L]] <- list(
      panel=panel, contrast=sp$label,
      point_extreme=isTRUE(attr(point,'numerically_extreme')),
      flagged_replicates=sum(boot_extreme & valid),
      valid_replicates=sum(valid),
      max_abs_coefficient=max(c(attr(point,'max_abs_coefficient'),
                                boot_max_coef),na.rm=TRUE),
      primary_ci=ci, diagnostic_ci=stable_ci,
      max_endpoint_shift_pp=100*max(abs(ci-stable_ci),na.rm=TRUE))
    results[[length(results)+1L]] <- data.frame(
      panel=panel, contrast=sp$label,n=nrow(dat),
      x0=sum(dat[[exposure]]==0L),x1=sum(dat[[exposure]]==1L),
      total=point['total'],total_low=ci[1,'total'],total_high=ci[2,'total'],
      direct=point['direct'],direct_low=ci[1,'direct'],
      direct_high=ci[2,'direct'],indirect=point['indirect'],
      indirect_low=ci[1,'indirect'],indirect_high=ci[2,'indirect'],
      bootstrap_valid=sum(valid),row.names=NULL)
  }
}
out <- do.call(rbind,results)
print(out,row.names=FALSE,digits=5)
cat('\nAll values are risk differences. Multiply by 100 for percentage points.\n')
cat('Panel A treats the coded combined clinical-use response as the intermediate variable and willingness as outcome.\n')
cat('Panel B reverses those roles; these two fits cannot determine time order.\n')
cat('Total = direct + indirect by algebraic construction for each fitted model.\n')
cat('Percentile intervals come from 1000 respondent bootstrap samples.\n')
cat('These are observational regression-standardization functionals, not natural/interventional causal effects.\n')
cat('Unknown time order, source-to-code agreement for use, prior interest, pre-use tool access and selection prevent causal mediation identification.\n')


cat('\nNUMERICAL BOOTSTRAP DIAGNOSTICS: primary estimates above retain all valid replicates.\n')
cat('Screen: absolute coefficient >15 or fitted probability <0.0000001 or >0.9999999; this is not a formal separation test.\n')
for (dg in diagnostics) {
  cat('Diagnostic:',dg$panel,dg$contrast,
      '; point flagged =',dg$point_extreme,
      '; bootstrap flagged =',dg$flagged_replicates,'of',dg$valid_replicates,
      '; maximum absolute coefficient =',format(dg$max_abs_coefficient,digits=8),
      '; maximum endpoint shift (pp) =',format(dg$max_endpoint_shift_pp,digits=8),'\n')
  if (dg$flagged_replicates>0L) {
    for (j in seq_len(3L))
      cat('Diagnostic interval:',dg$panel,dg$contrast,
          colnames(dg$primary_ci)[j],'; primary (pp) =',
          paste(format(100*dg$primary_ci[,j],digits=8),collapse=' to '),
          '; omission sensitivity only (pp) =',
          paste(format(100*dg$diagnostic_ci[,j],digits=8),collapse=' to '),'\n')
  }
}
cat('Diagnostic total flagged bootstrap replicates =',
    sum(vapply(diagnostics,function(x) x$flagged_replicates,integer(1L))),'\n')
cat('Diagnostic-only omission is not used as the analysis estimator; sparse-fit sensitivity remains a limitation.\n')
