# Called by run_all.R with data_file and output_dir.
options(stringsAsFactors=FALSE)
root <- output_dir
d <- read.csv(data_file,check.names=FALSE,fileEncoding='UTF-8-BOM')
n <- nrow(d)
trust <- d[['Confidence in diagnostic accuracy of AI']] %in% c(3,4)
diag <- d[['Willingness to base definitive diagnosis on AI generated']]==1
tab <- table(trust,diag)
outfile <- file.path(root,'Fig1.tif')
tiff(outfile,width=2100,height=1650,res=300,pointsize=10,type='cairo',compression='lzw',bg='white')
par(mar=c(5.6,6.8,.5,.6),family='Arial',xpd=NA)
plot(NA,xlim=c(0,2),ylim=c(0,2),axes=FALSE,xlab='',ylab='',asp=1)
counts <- c(tab[1,2],tab[2,2],tab[1,1],tab[2,1])
shade <- grDevices::colorRampPalette(c('#EEF4F8','#377BA8'))(max(counts)-min(counts)+1)
fills <- matrix(shade[counts - min(counts) + 1],nrow=2,byrow=TRUE)
for (i in 1:2) for (j in 1:2) {
  x0 <- j-1; y0 <- 2-i
  rect(x0,y0,x0+1,y0+1,col=fills[i,j],border='white',lwd=4)
  val <- as.integer(tab[j,3-i])
  lab_col <- if (val >= 87) 'white' else '#17334A'
  text(x0+.5,y0+.59,paste0('n = ',val),cex=1.1,font=2,col=lab_col)
  text(x0+.5,y0+.38,sprintf('%.1f%%',100*val/n),cex=.92,col=lab_col)
}
axis(1,at=c(.5,1.5),labels=c('Low confidence','Confident'),tick=FALSE,cex.axis=.95)
axis(2,at=c(.5,1.5),labels=c('Unwilling','Willing'),las=1,tick=FALSE,cex.axis=.95)
mtext('Confidence in AI diagnostic accuracy',side=1,line=2.8,cex=.95)
mtext('Willingness to base diagnosis on AI output',side=2,line=4.4,cex=.82)
dev.off()
cat(outfile,'\n')

options(stringsAsFactors=FALSE)
root <- output_dir
d <- read.csv(data_file,check.names=FALSE,fileEncoding='UTF-8-BOM')
n <- nrow(d)
wilson <- function(x,n) {
  z<-qnorm(.975); p<-x/n; den<-1+z*z/n
  mid<-(p+z*z/(2*n))/den
  half<-z*sqrt(p*(1-p)/n+z*z/(4*n*n))/den
  100*c(mid-half,mid+half)
}

labs <- c('Familiar with AI concepts','Confident in AI accuracy',
          'Willing to integrate AI in education','Academic digital tools/AI use answer',
          'Willing to base diagnosis on AI','Clinical digital tools/AI use answer')
counts <- c(
  sum(d[["Are you familiar with AI and its' concepts?"]] %in% c(3,4)),
  sum(d[['Confidence in diagnostic accuracy of AI']] %in% c(3,4)),
  sum(d[['Willingness for integration in dental education']]==1),
  sum(d[['Have you used AI tools in dental academics']]==3),
  sum(d[['Willingness to base definitive diagnosis on AI generated']]==1),
  sum(d[['Have you used AI tools in clinical practice']]==3))
cis <- t(vapply(counts,wilson,numeric(2),n=n))
pct <- 100*counts/n
derived <- c(FALSE,FALSE,FALSE,TRUE,FALSE,TRUE)
cols <- ifelse(derived,'#B66A23','#1E5A88')
path1 <- file.path(root,'S1_fig.png')
png(path1,width=3000,height=1900,res=300,type='cairo-png',bg='white')
par(mar=c(5.2,15.0,1.0,2.0),family='sans',cex=1.0,xpd=FALSE)
y <- rev(seq_along(labs))
plot(NA,xlim=c(0,121),ylim=c(.5,6.5),axes=FALSE,xlab='',ylab='')
for (g in seq(0,100,20)) abline(v=g,col='#E7EBEF',lwd=1)
abline(v=0,col='#84919C',lwd=1.2)
segments(cis[,1],y,cis[,2],y,col=cols,lwd=3)
arrows(cis[,1],y,cis[,2],y,angle=90,code=3,length=.06,col=cols,lwd=2)
points(pct,y,pch=ifelse(derived,17,16),cex=1.45,col=cols)
axis(1,at=seq(0,100,20),labels=paste0(seq(0,100,20),'%'),col.axis='#263442',cex.axis=.92)
axis(2,at=y,labels=labs,las=1,tick=FALSE,cex.axis=.88,hadj=1)
text(105,y,sprintf('%d/%d',counts,n),adj=0,cex=.89,col='#263442')
mtext('Positive response (%)',side=1,line=3.2,cex=.95)
dev.off()
cat(path1,'\n')

