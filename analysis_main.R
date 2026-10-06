options(stringsAsFactors=FALSE, scipen=999)
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1L || !file.exists(args[1])) stop('Usage: Rscript analysis_main.R path/to/approved_analytic_data.csv')
analysis_file <- args[1]
d <- read.csv(analysis_file, check.names=FALSE, fileEncoding='UTF-8-BOM')
n <- nrow(d)

# The Jamovi file labels combined digital-tools-and-AI use codes 1=No, 3=Yes.
# The formatted administered questionnaire has binary options. Other historical
# materials have different options, so no particular transformation is assumed.
# These analyses reproduce the coded answers; source-to-code agreement needs
# the original responses and respondent-linked coding history. A positive
# combined-item answer does not establish AI-specific use.
d$clinical_use <- as.integer(d[['Have you used AI tools in clinical practice']]==3)
d$academic_use <- as.integer(d[['Have you used AI tools in dental academics']]==3)
d$familiar_high <- as.integer(d[["Are you familiar with AI and its' concepts?"]] %in% c(3,4))
d$diagnosis_yes <- as.integer(d[['Willingness to base definitive diagnosis on AI generated']]==1)
d$curriculum_yes <- as.integer(d[['Willingness for integration in dental education']]==1)
d$age_older <- as.integer(d[['Age']]>=2)
d$female <- as.integer(d[['Gender']]==2)
d$general_dentist <- as.integer(d[['Primary Dental Specialisation']]==2)
d$practice_grp <- factor(ifelse(d[['Type of dental practice']]==1,'Public',ifelse(d[['Type of dental practice']]==2,'Private',ifelse(d[['Type of dental practice']]==3,'Academic','Mixed'))),levels=c('Academic','Public','Private','Mixed'))
wilson <- function(x,n) {z<-qnorm(.975);p<-x/n;den<-1+z*z/n;mid<-(p+z*z/(2*n))/den;half<-z*sqrt(p*(1-p)/n+z*z/(4*n*n))/den;c(count=x,n=n,percent=100*p,low=100*(mid-half),high=100*(mid+half))}
cat('N=',n,'\n')
for (v in c('familiar_high','academic_use','clinical_use','curriculum_yes','diagnosis_yes')) print(c(variable=v,wilson(sum(d[[v]]),n)))
cat('\nGender diagnosis table (female=1, yes=1)\n'); print(table(d$female,d$diagnosis_yes)); print(chisq.test(table(d$female,d$diagnosis_yes),correct=FALSE))
cat('\nTraining interest (rows: 1-4 agreement scale) vs curricular willingness (columns: 1=yes, 2=no)\n'); print(table(d[['Will you be interested in AI training and education']], d[['Willingness for integration in dental education']]))
cat('\nBARRIER PREVALENCES\n')
for (v in c('High cost of AI technologies','Insufficient knowledge about AI','Lack of technical support','Uncertainty about the benefits of AI','Concerns about patient data privacy','Regulatory and legal challenges','Low efficiency of technology')) print(c(variable=v,wilson(sum(d[[v]]==1),n)))
show_model <- function(m,name) {
  cat('\nMODEL',name,'\n')
  print(summary(m))
  s<-coef(summary(m)); z<-qnorm(.975)
  tab<-cbind(OR=exp(s[,1]),lower=exp(s[,1]-z*s[,2]),upper=exp(s[,1]+z*s[,2]),p=s[,4])
  print(round(tab,4))
  cat('AIC',AIC(m),'null.deviance',m$null.deviance,'residual.deviance',m$deviance,'\n')
  cat('fitted range',range(fitted(m)),'\n')
}
m_use<-glm(clinical_use ~ age_older + female + practice_grp + general_dentist,data=d,family=binomial())
show_model(m_use,'combined clinical digital-tools-and-AI use response')
m_diag<-glm(diagnosis_yes ~ clinical_use + age_older + female + practice_grp + familiar_high,data=d,family=binomial())
show_model(m_diag,'willingness for definitive diagnosis from AI output')
counter<-d
counter$clinical_use<-1
p1<-mean(predict(m_diag,newdata=counter,type='response'))
counter$clinical_use<-0
p0<-mean(predict(m_diag,newdata=counter,type='response'))
cat('Sample-standardized probabilities for clinical-use association:',round(p1,4),round(p0,4),'difference',round(p1-p0,4),'\n')
set.seed(20260925)
boot_diff<-rep(NA_real_,2000)
for(i in seq_along(boot_diff)) {
  di<-d[sample.int(n,n,replace=TRUE),]
  mi<-try(suppressWarnings(glm(diagnosis_yes ~ clinical_use + age_older + female + practice_grp + familiar_high,data=di,family=binomial())),silent=TRUE)
  if (inherits(mi,'try-error')) next
  c1<-di;c1$clinical_use<-1;c0<-di;c0$clinical_use<-0
  boot_diff[i]<-mean(predict(mi,newdata=c1,type='response'))-mean(predict(mi,newdata=c0,type='response'))
}
cat('Bootstrap risk-difference quantiles',quantile(boot_diff,c(.025,.5,.975),na.rm=TRUE),'valid',sum(!is.na(boot_diff)),'\n')

# An identical response pattern need not represent the same person. Report the
# influence of omitting one copy without treating it as a confirmed duplicate.
is_repeat <- duplicated(d)
cat('\nSENSITIVITY: exact repeated response patterns',sum(is_repeat),'\n')
if (sum(is_repeat)>0) {
  ds <- d[!is_repeat,]
  ms_use <- glm(clinical_use ~ age_older + female + practice_grp + general_dentist,
                data=ds,family=binomial())
  ms_diag <- glm(diagnosis_yes ~ clinical_use + age_older + female + practice_grp + familiar_high,
                 data=ds,family=binomial())
  cat('N after omitting one copy of each repeat',nrow(ds),'\n')
  cat('Clinical use share, full/sensitivity',mean(d$clinical_use),mean(ds$clinical_use),'\n')
  cat('Diagnosis willingness share, full/sensitivity',mean(d$diagnosis_yes),mean(ds$diagnosis_yes),'\n')
  cat('Model A mixed practice OR, full/sensitivity',exp(coef(m_use)['practice_grpMixed']),exp(coef(ms_use)['practice_grpMixed']),'\n')
  cat('Model A general dentist OR, full/sensitivity',exp(coef(m_use)['general_dentist']),exp(coef(ms_use)['general_dentist']),'\n')
  cat('Model B clinical use OR, full/sensitivity',exp(coef(m_diag)['clinical_use']),exp(coef(ms_diag)['clinical_use']),'\n')
  cat('Model B female OR, full/sensitivity',exp(coef(m_diag)['female']),exp(coef(ms_diag)['female']),'\n')
}
