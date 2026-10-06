options(stringsAsFactors=FALSE, scipen=999)
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 1L || !file.exists(args[1])) stop('Usage: Rscript analysis_paired.R path/to/approved_analytic_data.csv')
analysis_file <- args[1]
d <- read.csv(analysis_file, check.names=FALSE, fileEncoding='UTF-8-BOM')
n <- nrow(d)
trust <- as.integer(d[['Confidence in diagnostic accuracy of AI']] %in% c(3,4))
diag <- as.integer(d[['Willingness to base definitive diagnosis on AI generated']]==1)
clinical <- as.integer(d[['Have you used AI tools in clinical practice']]==3)

cat('N=',n,'\n')
cat('Confidence in diagnostic accuracy (agree/strongly agree):',sum(trust),n,mean(trust),'\n')
cat('Willing to base definitive diagnosis on AI:',sum(diag),n,mean(diag),'\n')
cat('Paired table accuracy-confidence rows, diagnostic willingness columns:\n')
print(table(trust=trust, willingness=diag))
discordant <- table(trust,diag)[2,1]+table(trust,diag)[1,2]
cat('Supplementary paired-symmetry p (not reported in manuscript):',binom.test(table(trust,diag)[1,2],discordant,.5)$p.value,'\n')
cat('Paired percentage-point difference:',100*mean(trust-diag),'\n')
set.seed(20260925)
boot <- replicate(5000,mean((trust-diag)[sample.int(n,n,replace=TRUE)]))
cat('Paired-difference percentile CI:',100*quantile(boot,c(.025,.975)),'\n')
cat('Willingness by four-level confidence:\n')
print(cbind(n=as.numeric(table(d[['Confidence in diagnostic accuracy of AI']])),
            willing=as.numeric(tapply(diag,d[['Confidence in diagnostic accuracy of AI']],sum)),
            percent=100*as.numeric(tapply(diag,d[['Confidence in diagnostic accuracy of AI']],mean))))

# Alternative experience adjustment: replacing age with practice years changes
# the adjustment variable; it is not a direct recoding of chronological age.
d$diagnosis_yes <- diag
d$clinical_use <- clinical
d$female <- as.integer(d[['Gender']]==2)
d$familiar_high <- as.integer(d[["Are you familiar with AI and its' concepts?"]] %in% c(3,4))
d$practice_grp <- factor(ifelse(d[['Type of dental practice']]==1,'Public',ifelse(d[['Type of dental practice']]==2,'Private',ifelse(d[['Type of dental practice']]==3,'Academic','Mixed'))),levels=c('Academic','Public','Private','Mixed'))
d$years <- d[['Years of Dental Clinical practice']]
m_linear <- glm(diagnosis_yes ~ clinical_use + years + female + practice_grp + familiar_high, data=d, family=binomial())
m_log <- glm(diagnosis_yes ~ clinical_use + log1p(years) + female + practice_grp + familiar_high, data=d, family=binomial())
cat('Clinical-use aOR with years linear:',exp(coef(m_linear)['clinical_use']),'\n')
cat('Clinical-use aOR with log(1 + years):',exp(coef(m_log)['clinical_use']),'\n')
cat('AIC linear/log-years:',AIC(m_linear),AIC(m_log),'\n')
