library(mosaic)
library(xtable)
library(dplyr)
library(httr)
library(ggplot2)
library(tidyr)
library(FNN)
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
  while( is.null(res) && attempt < 2 ) {
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



# Define UI for random distribution app ----
ui <- fluidPage(
  
  # App title ----
  titlePanel("Tabsets"),
  
  # Sidebar layout with input and output definitions ----
  sidebarLayout(
    
    # Sidebar panel for inputs ----
    sidebarPanel(
      
      textInput("playlist_id",h3("Playlist ID"),placeholder = "37i9dQZEVXbLRQDuF5jeBp",value = "37i9dQZEVXbLRQDuF5jeBp")      
      
    ),
    
    # Main panel for displaying outputs ----
    mainPanel(
      
      # Output: Tabset w/ plot ----
      tabsetPanel(type = "tabs",
                  tabPanel("Playlist Table", htmlOutput("statement"),DT::dataTableOutput("table")))
      
    )
  )
)

# Define server logic for random distribution app ----
server <- function(input, output) {
  
  # Reactive function returning name of playlist, number of tracks, and number of followers
  playlistdata <- reactive({
    # Gets an access token from the spotify api, expires every hour so this needs to be done with some regularity
    post <- POST('https://accounts.spotify.com/api/token',
                 accept_json(), authenticate(client_id, client_secret),
                 body = list(grant_type = 'client_credentials'),
                 encode = 'form', httr::config(http_version = 2)) %>% content
    access_token <- post$access_token
    
    playlist_id <- input$playlist_id
    print(playlist_id)
    
    # Gets playlist information from API
    url1 <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"?access_token=",access_token,sep = "")
    playlist <- check(url1)
    
    playlistinfo <- NULL
    playlistinfo$name <- playlist$name
    playlistinfo$songs <- playlist$tracks$total
    playlistinfo$followers<- playlist$followers$total
    playlistinfo
  })
  
    # Reactive function to get tracks in the playlist
    playlist <- reactive({
    inf <- playlistdata()
    playlist_id <- input$playlist_id
    leng <- inf$songs
    loops <- as.integer(leng/100)
    
    # Gets all song ids in the playlist
    songs <- NULL
    for(j in 0:loops){
      offset <- j*100
      url2 <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,"&limit=100&offset=",offset,sep = "")
      df <- check(url2)
      songs <- c(songs,df$items$track$id)
    
    # Ensures the playlist has tracks  
    }
    if(is.null(songs)){
      return(NULL)
    }
    loops2 <- ceiling(length(songs)/50)
    
    # Dataframe for song information
    data2 <- data.frame()
    
    # Loops through all song ids, and gets information (title, artists, duration, popularity, etc)
    for(k in 1:loops2){
      ids <- songs[((k-1)*50+1):(k*50)]
      ids <- ids[!is.na(ids)]
      ids <- paste(ids,collapse=",")
      
      # Gets track audio-features (50 at a time) - tempo, duration, loudness
      url3 <- paste("https://api.spotify.com/v1/audio-features/?access_token=",access_token,"&ids=",ids,sep="")
      analysis <- check(url3)$audio_features
      
      # Gets track information (50 at a time) - artist, album, id, popularity, release date
      url4 <- paste("https://api.spotify.com/v1/tracks/?access_token=",access_token,"&ids=",ids,sep="")
      info <- check(url4)$tracks
      
      # Gets artist ids
      artists <- NULL
      for(l in info$artists){
        artists<- c(artists,paste(l$name,collapse=", "))
      }
      data2 <- rbind(data2,data.frame(info$name, artists,info$album$name,info$album$release_date, analysis$tempo, analysis$duration_ms, analysis$loudness, info$popularity))
    }
    
    colnames(data2) <- c("Song Title", "Artist Name", "Album Name","Release Date", "Tempo","Duration","Loudness","Popularity")
    data2
    
  })
  
  playlistana <- reactive({
    df <- playlist()
    df2 <- playlistdata()
    out <- NULL
    
    # Makes list with all necessary information for model
    out$avgpop <- mean(as.numeric(unlist(df["Popularity"])),na.rm = T)
    out$avglen <- mean(as.numeric(unlist(df["Duration"])),na.rm = T)
    out$maxlen <- max(as.numeric(unlist(df["Duration"])),na.rm = T)
    out$minlen <- min(as.numeric(unlist(df["Duration"])),na.rm = T)
    out$songs <- df2$songs
    out$followers<- df2$followers
    temp<-c(out$followers,out$songs,out$avgpop,out$avglen,out$maxlen,out$minlen)
    
    # Gets trained data and runs knn on the playlist
    traindata <- read.csv("playlistsummary.csv",header=T)
    traindata <- traindata[,-1]
    model <- knn.reg(train=traindata,test=temp,y=traindata$numFollowers,k=43)
    
    print(model$pred)
    # Important: gets the follower prediction, takes the log and divides by the log(11,000,000) = 6.5, where 11,000,000 is the max followers of spotify playlists
    # Logarithm is used so that lowers predictions don't simply return 0, and ensures score is 100 maximum
    min(floor(log10(model$pred)/7.04*100),100)
  })
  
  # Generate an HTML table view of the data ----
  output$table <- DT::renderDataTable({
    playlist() 
  })
  
  # Generates text above the html table
  output$statement <- renderText({
    inf <- playlistdata()
    score <- playlistana()
    if(inf$followers != 1){
      s1 <-  " followers!<br/>"
    }else{
      s1 <-  " follower!<br/>"
    }
    if(inf$songs != 1){
      s2 <- "There are "
      s3 <-  " tracks on your playlist."
    }else{
      s2 <- "There is "
      s3 <-  " track on your playlist."
    }
    
    # Creates full string to print to app
    string <- paste("Info for playlist: ",inf$name,"<br/>Your playlist has ", inf$followers, s1,s2,inf$songs, s3,"<br/><font size=\"24\">Playlist score is ",score,"</font>",sep="")
    return(string)
  })
  
}

shinyApp(ui = ui, server = server)

