#!/usr/bin/env Rscript
# Method feasibility only; not a validated clinical prediction model.
# Fully nested, stratified cross-validation prevents reuse of evaluation-fold
# labels when estimating convex ensemble weights.
options(stringsAsFactors=FALSE, scipen=999)
args <- commandArgs(trailingOnly=TRUE)
if (length(args)!=1L || !file.exists(args[1]))
  stop('Usage: Rscript analysis_super_learner_feasibility.R coded_data.csv')
if (!requireNamespace('rpart',quietly=TRUE)) stop('rpart is required')
d <- read.csv(args[1], check.names=FALSE, fileEncoding='UTF-8-BOM')
stopifnot(nrow(d)==301L,ncol(d)==42L,sum(is.na(d))==0L)
d$use <- as.integer(d[['Have you used AI tools in clinical practice']]==3)
d$willing <- as.integer(d[['Willingness to base definitive diagnosis on AI generated']]==1)
d$older <- as.integer(d[['Age']]>=2)
d$female <- as.integer(d[['Gender']]==2)
d$general <- as.integer(d[['Primary Dental Specialisation']]==2)
d$familiar <- as.integer(d[["Are you familiar with AI and its' concepts?"]] %in% c(3,4))
d$setting <- factor(ifelse(d[['Type of dental practice']]==1,'Public',
                     ifelse(d[['Type of dental practice']]==2,'Private',
                     ifelse(d[['Type of dental practice']]==3,'Academic','Mixed'))),
                    levels=c('Academic','Public','Private','Mixed'))

clip <- function(p) {
  p[p<.001] <- .001
  p[p>.999] <- .999
  p
}
learners <- function(train,test) {
  null <- rep(mean(train$willing),nrow(test))
  base <- suppressWarnings(glm(willing~use+older+female+setting+general+familiar,
                               family=binomial(),data=train))
  interact <- suppressWarnings(glm(willing~use*(female+setting)+older+general+familiar,
                                   family=binomial(),data=train))
  tree <- rpart::rpart(factor(willing,levels=0:1)~use+older+female+setting+general+familiar,
                       data=train,method='class',control=rpart::rpart.control(
                         cp=.02,minsplit=40,minbucket=20,maxdepth=2,xval=0))
  p <- cbind(null=null,
             logistic=predict(base,newdata=test,type='response'),
             interaction=predict(interact,newdata=test,type='response'),
             shallow_tree=predict(tree,newdata=test,type='prob')[,'1'])
  if (any(!is.finite(p))) stop('Nonfinite learner prediction')
  clip(p)
}

folds <- function(y,k=5L) {
  f <- integer(length(y))
  for (v in 0:1) {
    idx <- sample(which(y==v))
    f[idx] <- rep(seq_len(k),length.out=length(idx))
  }
  f
}
loss <- function(p,y) -mean(y*log(clip(p))+(1-y)*log1p(-clip(p)))
weights <- function(p,y) {
  objective <- function(theta) {
    raw <- exp(c(theta,0)); w<-raw/sum(raw)
    loss(drop(p%*%w),y)
  }
  fit <- optim(rep(0,ncol(p)-1L),objective,method='BFGS',
               control=list(maxit=300,reltol=1e-10))
  raw <- exp(c(fit$par,0)); raw/sum(raw)
}
auc <- function(p,y) {
  r<-rank(p,ties.method='average')
  (sum(r[y==1])-sum(y==1)*(sum(y==1)+1)/2)/(sum(y==1)*sum(y==0))
}

set.seed(20260926)
all_results <- list()
for (rep in seq_len(3L)) {
  outer <- folds(d$willing)
  pred <- matrix(NA_real_,nrow(d),5L,
                 dimnames=list(NULL,c('null','logistic','interaction','shallow_tree','ensemble')))
  weight_record <- matrix(NA_real_,5L,4L)
  for (j in seq_len(5L)) {
    train <- d[outer!=j,,drop=FALSE]
    test <- d[outer==j,,drop=FALSE]
    inner <- folds(train$willing)
    oof <- matrix(NA_real_,nrow(train),4L)
    for (h in seq_len(5L))
      oof[inner==h,] <- learners(train[inner!=h,,drop=FALSE],
                                train[inner==h,,drop=FALSE])
    stopifnot(all(is.finite(oof)))
    w <- weights(oof,train$willing)
    weight_record[j,] <- w
    candidate <- learners(train,test)
    pred[outer==j,1:4] <- candidate
    pred[outer==j,5] <- drop(candidate%*%w)
  }
  stopifnot(all(is.finite(pred)))
  out <- data.frame(rep_id=rep,learner=colnames(pred),
                    Brier=apply(pred,2,function(p) mean((d$willing-p)^2)),
                    log_loss=apply(pred,2,loss,y=d$willing),
                    AUC=apply(pred,2,auc,y=d$willing))
  all_results[[rep]] <- out
  cat('\nREPEAT',rep,'nested five-fold evaluation\n')
  print(out,row.names=FALSE,digits=4)
  cat('Mean convex ensemble weights (null, logistic, interaction, shallow tree):\n')
  print(round(colMeans(weight_record),3))
}
results <- do.call(rbind,all_results)
cat('\nMEAN OF THREE REPEATED FIVE-FOLD EVALUATIONS (descriptive only)\n')
print(aggregate(results[,c('Brier','log_loss','AUC')],
                by=list(learner=results$learner),FUN=mean),row.names=FALSE,digits=4)
cat('\nLIMIT: all predictors and hypothetical willingness were recorded concurrently; source agreement for the coded use response is unverified; there is no target deployment population, pre-outcome predictor set, or external dataset. These scores cannot support clinical prediction claims.\n')
