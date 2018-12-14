library(httr)
library(tidyr)
library(dplyr)
library(mosaic)
source('config.R')

# check(url)
# inputs: url to get data from
# outputs: json data as df
# 
# This function's purpose is to circumvent 409 errors (too many requests)
# Will retry each second for 5 seconds
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

# Gets an access token from the spotify api
post <- POST('https://accounts.spotify.com/api/token',
             accept_json(), authenticate(client_id, client_secret),
             body = list(grant_type = 'client_credentials'),
             encode = 'form', httr::config(http_version = 2)) %>% content
access_token <- post$access_token

# Creates a series of patterns such that the API query will return playlists starting or ending with each alphabetical character
alphabet <- c("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")
alphabet <- paste("*",alphabet,"*",sep = "")

# Creates blank dataframe for the data
data <- data.frame(stringsAsFactors=FALSE)
colnames(data)<- c("Name","NumSongs","Id","Followers","Tracks")

# Number of each letter to get from playlists in 50s (i.e. playlist_50s <- 2 gets 100 of each letter)
playlist_50s <- 1

# Loops to search playlist over each alphabetical letter
for(i in alphabet){
  # Loops to search 50s of playlists for each alphabetical letter
  for(j in 1:playlist_50s){
    offset <- 50*(j-1)
    url1 <- paste("https://api.spotify.com/v1/search?type=playlist&limit=1&offset=",offset,"&q=",i,"&access_token=",access_token,sep="")
    playlists <- check(url1)
    print(i)
    playlistsdata <- NULL
    # Tries to add the data from each playlist to dataframe, some playlists will be outdated, and will not be added
    # If limit is too small, errors will be returned, but can be ignored
    try(playlistsdata <- data.frame(playlists$playlists$items$name,playlists$playlists$items$tracks$total,playlists$playlists$items$id,"","",stringsAsFactors=FALSE))
    data <- rbind(data,playlistsdata)
  }
}

# Removes duplicate playlists
data<-data %>% distinct(playlists.playlists.items.id,.keep_all = T)

# Removes empty playlists
if(0 %in% data[,2]){
  data <- data[-c(grep(TRUE,data[,2] == 0)),]
}

# Reorders data, so index doesn't skip numbers
rownames(data) <- 1:nrow(data)

# Loops through the indices over all playlists
for(i in 1:length(data[,1])){
  playlist_id <- data[i,3]
  leng <- data[i,2]
  loops <- as.integer(leng/100)
  
  # Gets playlist information (followers)
  url2 <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"?access_token=",access_token,sep = "")
  followers <- check(url2)$followers$total
  data[i,4] <- followers
  songs <- NULL
  
  # Gets all songs in the playlist
  for(j in 0:loops){
    offset <- j*100
    url3 <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,"&limit=100&offset=",offset,sep = "")
    df <- check(url3)
    songs <- c(songs,df$items$track$id)
  
  #ignores playlists with no tracks (some only containing videos, audiobooks, etc)  
  }
  if(is.null(songs)){
    next() #thank u
  }
  
  loops2 <- ceiling(length(songs)/50)
  
  # Dataframe for track information
  data2 <- data.frame()
  
  # Loops over all tracks in playlist
  for(k in 1:loops2){
    ids <- songs[((k-1)*50+1):(k*50)]
    ids <- ids[!is.na(ids)]
    ids <- paste(ids,collapse=",")
    
    # Gets track audio-features (50 at a time) - tempo, duration, loudness
    url4 <- paste("https://api.spotify.com/v1/audio-features/?access_token=",access_token,"&ids=",ids,sep="")
    analysis <- check(url4)$audio_features
    
    # Gets track information (50 at a time) - artist, album, id, popularity, release date
    url5 <- paste("https://api.spotify.com/v1/tracks/?access_token=",access_token,"&ids=",ids,sep="")
    info <- check(url5)$tracks
    
    # Gets artist ids
    artists <- NULL
    for(l in info$artists){
      artists<- c(artists,l$id[1])
    }
    # Adds songs to dataframe
    data2 <- rbind(data2,data.frame(info$id, artists,info$album$release_date, analysis$tempo, analysis$duration_ms, analysis$loudness, info$popularity))
  }
  print(paste("Playlist Number",i,sep = " "))
  
  # Some spaghetti code here, R has trouble saving dfs in dfs, so the songs are in a csv string with line separater "slashn"
  foo2 <- capture.output(write.csv(data2, stdout(), row.names=F)) 
  dat2str <- capture.output(cat(foo2,sep="slashn"))
  data[i,5] <- dat2str
  
  # Since access tokens last for an hour, refreshes every 100 playlists (safe, could do as many as every 1250 playlists)
  if(i %% 100==0){
    post <- POST('https://accounts.spotify.com/api/token',
                 accept_json(), authenticate(client_id, client_secret),
                 body = list(grant_type = 'client_credentials'),
                 encode = 'form', httr::config(http_version = 2)) %>% content
    access_token <- post$access_token
  }
}

#Writes data to csv "datamain.csv" in same directory as 'Mining.R'
write.csv(data,"datamaintest.csv")
