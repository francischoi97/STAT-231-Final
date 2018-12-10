library(httr)
library(tidyr)
library(dplyr)
library(mosaic)

check <- function(url){
  attempt <- 0
  res <- NULL
  while( is.null(res) && attempt < 5 ) {
    attempt <- attempt + 1
    if(attempt > 1){
      print(paste("FAILED - attempt:",attempt, sep = " "))
    }
    try(
      tryCatch(res <-jsonlite::fromJSON(readLines(url,warn=F)), error=function(e) Sys.sleep(1))
    )
  }
  return(res)
}

req <- paste("https://api.spotify.com/v1/search?type=playlist&q=workout&access_token=",access_token,sep="")

client_id = "58c2614435ab4c29b750b180d0063922"
client_secret = "ab34d429d0df46e3b13d18d7fe0c1473"

post <- POST('https://accounts.spotify.com/api/token',
             accept_json(), authenticate(client_id, client_secret),
             body = list(grant_type = 'client_credentials'),
             encode = 'form', httr::config(http_version = 2)) %>% content
access_token <- post$access_token


alphabet <- c("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")
alphabet <- paste("*",alphabet,"*",sep = "")
data <- data.frame(stringsAsFactors=FALSE)
colnames(data)<- c("Name","NumSongs","Id","Followers","Tracks")

playlist_50s <- 2

for(i in alphabet){
  for(j in 1:playlist_50s){
    offset <- 50*(j-1)
    url1 <- paste("https://api.spotify.com/v1/search?type=playlist&limit=50&offset=",offset,"&q=",i,"&access_token=",access_token,sep="")
    playlists <- check(url1)
    print(i)
    playlistsdata <- NULL
    try(playlistsdata <- data.frame(playlists$playlists$items$name,playlists$playlists$items$tracks$total,playlists$playlists$items$id,"","",stringsAsFactors=FALSE))
    print(playlistsdata)
    data <- rbind(data,playlistsdata)
  }
}
data<-data %>% distinct(playlists.playlists.items.id,.keep_all = T)
data <- data[-c(grep(TRUE,data[,2] == 0)),]
rownames(data) <- 1:nrow(data)

for(i in 1:length(data[,1])){
  playlist_id <- data[i,3]
  leng <- data[i,2]
  loops <- as.integer(leng/100)
  songs <- NULL
  
  url <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"?access_token=",access_token,sep = "")
  followers <- check(url)$followers$total
  data[i,4] <- followers
  
  for(j in 0:loops){
    offset <- j*100
    url <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,"&limit=100&offset=",offset,sep = "")
    df <- check(url)
    songs <- c(songs,df$items$track$id)
    
  }
  if(is.null(songs)){
    next() #thank u
  }
  loops2 <- ceiling(length(songs)/50)
  
  data2 <- data.frame()
  for(k in 1:loops2){
    ids <- songs[((k-1)*50+1):(k*50)]
    ids <- ids[!is.na(ids)]
    ids <- paste(ids,collapse=",")
    url1 <- paste("https://api.spotify.com/v1/audio-features/?access_token=",access_token,"&ids=",ids,sep="")
    analysis <- check(url1)$audio_features
    url2 <- paste("https://api.spotify.com/v1/tracks/?access_token=",access_token,"&ids=",ids,sep="")
    info <- check(url2)$tracks
    artists <- NULL
    for(l in info$artists){
      artists<- c(artists,l$id[1])
    }
    data2 <- rbind(data2,data.frame(info$id, artists,info$album$release_date, analysis$tempo, analysis$duration_ms, analysis$loudness, info$popularity))
  }
  print(paste("Playlist Number",i,sep = " "))
  foo2 <- capture.output(write.csv(data2, stdout(), row.names=F)) 
  dat2str <- capture.output(cat(foo2,sep="slashn"))
  data[i,5] <- dat2str
  if(i %% 100==0){
    post <- POST('https://accounts.spotify.com/api/token',
                 accept_json(), authenticate(client_id, client_secret),
                 body = list(grant_type = 'client_credentials'),
                 encode = 'form', httr::config(http_version = 2)) %>% content
    access_token <- post$access_token
  }
}

write.csv(data,"datamain.csv")
