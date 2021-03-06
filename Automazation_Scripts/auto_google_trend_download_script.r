# This script automates the downloading of Google Trends.
# It works best with firefox in combination with the Tab Mix Plus add-on that is used to automate tab closing.
# Ask firefox not to prompt for new downloads and this script should run automatically.
# Google Trends restricts the number of download to roughly 400 at a time.
# This is a fully working script for downloading Google Trends daily Google Trends data for the key word "FTSE 100" since 2004
# The only thing you need to do is change downloadDir to the download directory of your default browser.
# The final results will be located in the data frame "summary"
# Note that this has only been tested on a Windows machine. It should work on a Mac as well.

downloadDir="/home/bbardak/Desktop/Tez/MultipleDisease/sonson"
setwd(downloadDir)
seach_word="FTSE 100"


URL_GT=function(keyword="", country=NA, region=NA, year=NA, month=1, length=3){

  start="http://www.google.com/trends/trendsReport?hl=en-US&q="
  end="&cmpt=q&content=1&export=1"
  geo=""
  date=""

#Geographic restrictions
  if(!is.na(country)) {
    geo="&geo="
    geo=paste(geo, country, sep="")
    if(!is.na(region)) geo=paste(geo, "-", region, sep="")
  }

  queries=keyword[1]
  if(length(keyword)>1) {
    for(i in 2:length(keyword)){
    queries=paste(queries, "%2C ", keyword[i], sep="")
    }
  }

#Dates
  if(!is.na(year)){
    date="&date="
    date=paste(date, month, "%2F", year, " ", length, "m", sep="")
  }

  URL=paste(start, queries, geo, date, end, sep="")
  return(URL)
}

downloadGT=function(URL, downloadDir){

#Determine if download has been completed by comparing the number of files in the download directory to the starting number
  startingFiles=list.files(downloadDir)
  browseURL(URL)
  endingFiles=list.files(downloadDir)

  while(length(setdiff(endingFiles,startingFiles))==0) {
    Sys.sleep(3)
    endingFiles=list.files(downloadDir)
  }
  filePath=setdiff(endingFiles,startingFiles)
  return(filePath)
}


readGT=function(filePath){
rawFiles=list()

  for(i in 1:length(filePath)){
    if(length(filePath)==1) rawFiles[[1]]=read.csv(filePath, header=F, blank.lines.skip=F)
    if(length(filePath)>1) rawFiles[[i]]=read.csv(filePath[i], header=F, blank.lines.skip=F)
  }

  output=data.frame()
  name=vector()

  for(i in 1:length(rawFiles)){
    data=rawFiles[[i]]
    raw_name=as.character(data[1,1])
    raw_name=substr(raw_name, 22, nchar(raw_name))
  
#Create a vector called name containing the search terms
    if(grepl(";", raw_name)) {
      separators=gregexpr(";", raw_name)[[1]]
      separators=c(separators, nchar(raw_name)+1)
      
      name[1]=substr(raw_name, 1, separators[1]-1)
      for(j in 2:length(separators)) {
        name[j]=substr(raw_name, separators[j-1]+2, separators[j]-1)
      }
    } else {name=raw_name}
    
#Select the time series
    start=which(data[,1]=="")[1]+3
    stop=which(data[,1]=="")[2]-2
    
#Skip to next if file is empty
    if(ncol(data)<2) next
    if(is.na(which(data[,1]=="")[2]-2)) next
    
    data=data[start:stop,]
    data[,1]=as.character(data[,1])

#Convert all columns except date column into numeric
    for(j in 2:ncol(data)) data[,j]=as.numeric(as.character(data[,j]))

#FORMAT DATE
    len=nchar(data[1,1])

#Monthly data
    if(len==7) {
        data[,1]=as.Date(paste(data[,1], "-1", sep=""), "%Y-%m-%d")
        data[,1]=sapply(data[,1], seq, length=2, by="1 month")[2,]-1
        data[,1]=as.Date(data[,1], "%Y-%m-%d", origin="1970-01-01")
      }

#Weekly data
      if(len==23){
        data[,1]=sapply(data[,1], substr, start=14, stop=30)
        data[,1]=as.Date(data[,1], "%Y-%m-%d")
      }

#Daily data
      if(len==10) data[,1]=as.Date(data[,1], "%Y-%m-%d")
      
#Structure into panel data format
      panelData=data[1:2]
      panelData[3]=name[1]
      names(panelData)=c("Date", "SVI", "Keyword")
      if(ncol(data)>2) {

        for(j in 3:ncol(data)) {
          appendData=data[c(1,j)]
          appendData[3]=name[j-1]
          names(appendData)=c("Date", "SVI", "Keyword")
          panelData=rbind(panelData, appendData)
        }
      }

#Add file name  
      panelData[ncol(panelData)+1]=filePath[i]
  
#Add path to filename
      names(panelData)[4]="Path"
      
#Merge several several files into one
      if(i==1) output=panelData
      if(i>1) output=rbind(output, panelData)
  }
  return(output)
}


reindexGT=function(GT.daily, GT.weekly){
  GT.daily=GT.daily[,order(colnames(GT.daily))]
  GT.weekly=GT.weekly[,order(colnames(GT.weekly))]
 
  w=match(names(GT.daily), names(GT.weekly))
  w=w[!is.na(w)]
  d=match(names(GT.weekly), names(GT.daily))
  d=d[!is.na(d)]
 
  GT.weekly=GT.weekly[,w]
  GT.daily=GT.daily[,d]
 
  merged=merge(GT.daily, GT.weekly, by="Date", all=T)
  GT.daily=merged[2:(1+((length(merged)-1))/2)]
  rownames(GT.daily)=merged$Date
  GT.weekly=merged[(2+(length(merged)-1)/2):length(merged)]
  rownames(GT.weekly)=merged$Date
 
  reindex=GT.daily/GT.weekly
  for(i in 2:length(reindex[,1])) {
    for(j in 1:length(reindex[1,])) {
      if(is.na(reindex[i,j])) {
        reindex[i,j]=reindex[i-1,j]
      }
    }
  }
 
  for(i in 2:length(GT.daily[,1])) {
   for(j in 1:length(GT.daily[1,])) {
    if(is.na(GT.daily[i,j])) {
      GT.daily[i,j]=GT.daily[i-1,j]
      }
    }
  }
 
  for(i in 2:length(GT.weekly[,1])) {
    for(j in 1:length(GT.weekly[1,])) {
      if(is.na(GT.weekly[i,j])) {
        GT.weekly[i,j]=GT.weekly[i-1,j]
      }
    }
  }
 
output=list(reindex, GT.daily, GT.weekly)
return(output)
}


# EXECUTION

year=c(2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015)

n=1
trendsDir=vector()
for(i in year){
  for(j in 1:12){
    URL=URL_GT(keyword=seach_word, year=i, month=j, length=1)
    trendsDir[n]=downloadGT(URL, downloadDir)
    n=n+1
    if(i==2015 && j==6) break()
  }
}

daily_GT=readGT(trendsDir)

URL=URL_GT(keyword=seach_word)
trendsDir_weekly=downloadGT(URL, downloadDir)
weekly_GT=readGT(trendsDir_weekly)

reindexing=reindexGT(daily_GT[1:2], weekly_GT[1:2])

# GT is the final results
GT=reindexing[[2]]/reindexing[[1]]
GT[which(!is.finite(GT[,1])),]=0

# Create summary table for comparison
summary=as.data.frame(matrix(NA, nrow(GT), 3))
names(summary)=c("Date", "Reindexed", "Original daily")
summary[,1]=as.Date(rownames(GT))
summary[,2]=GT[,1]
summary[,3]=reindexing[[2]][,1]
summary=merge(summary, weekly_GT[1:2], all=T, by="Date")

for(i in 2:nrow(summary)){
	if(is.na(summary[i,4])) summary[i,4]=summary[i-1,4]
}

library(scales)

plot(summary$Date, summary[,3], type="l")
plot(summary$Date, summary[,4], type="l")
plot(summary$Date, summary[,2], type="l")

plot(summary$Date, summary[,2], type="l", col=alpha("green", 0.5), lwd=2)
lines(summary$Date, summary[,3], type="l", col=alpha("blue", 0.8), lwd=1)
lines(summary$Date, summary[,4], type="l", col=alpha("red", 0.9), lwd=2)