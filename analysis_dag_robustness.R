#!/usr/bin/env Rscript
# Observed-node DAG audit. These are associations, not tests of causal arrows.
options(stringsAsFactors=FALSE, scipen=999)
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1L || !file.exists(args[1]))
  stop('Usage: Rscript analysis_dag_robustness.R approved_analytic_data.csv')
d <- read.csv(args[1], check.names=FALSE, fileEncoding='UTF-8-BOM')
stopifnot(nrow(d)==301L, ncol(d)==42L, sum(is.na(d))==0L)

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

pair <- table(use=d$use,willing=d$willing)
stopifnot(sum(pair)==301L, all(dim(pair)==2L))
crude_or <- unname((pair[2,2]*pair[1,1])/(pair[2,1]*pair[1,2]))
cat('PAIRED USE-WILLINGNESS TABLE\n'); print(pair)
cat('Unadjusted OR',crude_or,'\n')
cat('Unadjusted risk difference',mean(d$willing[d$use==1])-mean(d$willing[d$use==0]),'\n')
cat('FAMILIARITY BY CODED COMBINED CLINICAL-USE RESPONSE\n'); print(table(familiar=d$familiar,use=d$use))

fit <- function(formula,data=d) {
  m <- glm(formula,data=data,family=binomial())
  stopifnot(m$converged, all(is.finite(coef(m))))
  m
}
base_use <- fit(use ~ older+female+setting+general)
familiar_use <- fit(use ~ older+female+setting+general+familiar)
base_willing <- fit(willing ~ use+older+female+setting+familiar)
extended_willing <- fit(willing ~ use+older+female+setting+general+familiar)
no_familiar_willing <- fit(willing ~ use+older+female+setting+general)
reverse_use <- fit(use ~ willing+older+female+setting+general)
familiar_willing <- fit(willing ~ familiar+older+female+setting+general)

one <- function(model,term,label) {
  s <- coef(summary(model))[term,]
  c(model=label,term=term,OR=exp(s[1]),low=exp(s[1]-qnorm(.975)*s[2]),
    high=exp(s[1]+qnorm(.975)*s[2]),p=s[4])
}
cat('\nKEY CONDITIONAL ASSOCIATIONS\n')
for (line in list(one(base_willing,'use','reported primary model'),
                  one(extended_willing,'use','plus general status'),
                  one(no_familiar_willing,'use','without concurrent familiarity'),
                  one(reverse_use,'willing','reverse-outcome model'),
                  one(familiar_use,'familiar','familiarity-use association'),
                  one(familiar_willing,'familiar','familiarity association'))) print(line)
cat('\nALL BACKGROUND COEFFICIENTS, USE MODEL\n');
print(round(cbind(OR=exp(coef(base_use)),
                  exp(confint.default(base_use))),4))
cat('\nALL BACKGROUND COEFFICIENTS, EXTENDED WILLINGNESS MODEL\n');
print(round(cbind(OR=exp(coef(extended_willing)),
                  exp(confint.default(extended_willing))),4))
cat('\nOBSERVED PATHWAY COMPONENT ASSOCIATIONS ONLY\n')
for (line in list(one(base_use,'settingMixed','mixed setting to coded use'),
                  one(extended_willing,'settingMixed','mixed setting to willingness conditional on use'),
                  one(base_use,'general','general status to coded use'),
                  one(extended_willing,'general','general status to willingness conditional on use'),
                  one(extended_willing,'use','coded use to willingness conditional on recorded attributes'))) print(line)
cat('This pathway audit does not estimate a causal indirect effect or proportion mediated. A separate script reports descriptive decompositions only; use and willingness were simultaneous, and prior interest, tool access, original use response and selection mechanism are unavailable.\n')

standardize <- function(m,data,exposure='use') {
  x1<-data; x1[[exposure]]<-1
  x0<-data; x0[[exposure]]<-0
  p1<-mean(predict(m,newdata=x1,type='response'))
  p0<-mean(predict(m,newdata=x0,type='response'))
  c(p1=p1,p0=p0,difference=p1-p0)
}
cat('\nSAMPLE-STANDARDIZED ASSOCIATIONS\n')
print(standardize(base_willing,d))
print(standardize(extended_willing,d))
print(standardize(no_familiar_willing,d))

cat('\nSETTING-STRATIFIED 2x2 TABLES (descriptive, no pooled causal claim)\n')
for (s in levels(d$setting)) {
  ds<-d[d$setting==s,]
  cat(s,'n',nrow(ds),'\n')
  print(table(use=factor(ds$use,levels=0:1),
              willing=factor(ds$willing,levels=0:1)))
}
cat('\nGENDER-STRATIFIED RESPONSE SHARES\n')
for (g in 0:1) for (u in 0:1) {
  ds<-d[d$female==g & d$use==u,]
  cat('female',g,'use',u,'n',nrow(ds),'willing',sum(ds$willing),
      'share',mean(ds$willing),'\n')
}

interaction <- fit(willing ~ use*female+older+setting+general+familiar)
cat('\nEXPLORATORY USE-BY-GENDER INTERACTION LRT\n')
print(anova(extended_willing,interaction,test='Chisq'))
cat('interaction OR',exp(coef(interaction)['use:female']),'\n')
setting_interaction <- fit(willing ~ use*setting+older+female+general+familiar)
cat('\nEXPLORATORY USE-BY-SETTING INTERACTION LRT\n')
print(anova(extended_willing,setting_interaction,test='Chisq'))

cat('\nOVERLAP OF OBSERVED USE CODES\n')
ps <- fitted(base_use)
print(quantile(ps,c(0,.01,.05,.5,.95,.99,1)))
cat('n predicted use <.1',sum(ps<.1),' >.9',sum(ps>.9),'\n')

cat('\nLEAVE-ONE-RECORD-OUT INFLUENCE FOR EXTENDED ASSOCIATION\n')
loo <- vapply(seq_len(nrow(d)),function(i) {
  m<-try(glm(willing ~ use+older+female+setting+general+familiar,
             data=d[-i,],family=binomial()),silent=TRUE)
  if (inherits(m,'try-error') || !m$converged) return(NA_real_)
  exp(coef(m)['use'])
},numeric(1))
cat('valid',sum(is.finite(loo)),'range',range(loo,na.rm=TRUE),
    'median',median(loo,na.rm=TRUE),'\n')

cat('\nIDENTIFICATION LIMITS\n')
cat('Unavailable: untouched original use responses, pre-survey AI interest, pre-use tool access, site and selection probabilities, measured temporal order.\n')
cat('Observed conditional associations and their stability do not identify the direction use -> willingness or willingness -> use.\n')
