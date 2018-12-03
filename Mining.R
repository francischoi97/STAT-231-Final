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
data <- data.frame()
colnames(data)<- c("Name","Tracks","Id")
for(i in alphabet){
  url1 <- paste("https://api.spotify.com/v1/search?type=playlist&limit=2&q=",i,"&access_token=",access_token,sep="")
  playlists <-jsonlite::fromJSON(url1)
  playlistsdata <- data.frame(playlists$playlists$items$name,playlists$playlists$items$tracks$total,playlists$playlists$items$id,"")
  data <- rbind(data,playlistsdata)
  print(i)
}

for(i in 1:length(data[,1])){
  playlist_id <- data[i,3]
  url <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,"?limit=200",sep = "")
  df <- jsonlite::fromJSON(paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,sep = ""))
  songs <- df$items$track$id
  data2 <- data.frame()
  for(i in songs){
    url1 <- paste("https://api.spotify.com/v1/audio-features/",i,"?access_token=",access_token,sep="")
    analysis <- jsonlite::fromJSON(url1)
    url2 <- paste("https://api.spotify.com/v1/tracks/",i,"?access_token=",access_token,sep="")
    info <- jsonlite::fromJSON(url2)
    data2 <- rbind(data2,data.frame(info$name, info$artists$name[1], info$album$name,info$album$release_date, analysis$tempo, analysis$duration_ms, analysis$loudness, info$popularity))
  }
  data[i,4] <- data2
}
