library(xtable)
library(dplyr)
library(httr)
library(ggplot2)
library(tidyr)
client_id = "58c2614435ab4c29b750b180d0063922"
client_secret = "ab34d429d0df46e3b13d18d7fe0c1473"

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

# Define UI for random distribution app ----
ui <- fluidPage(
  
  # App title ----
  titlePanel("Tabsets"),
  
  # Sidebar layout with input and output definitions ----
  sidebarLayout(
    
    # Sidebar panel for inputs ----
    sidebarPanel(
      
      textInput("playlist_id",h3("Playlist ID"))      
      
    ),
    
    # Main panel for displaying outputs ----
    mainPanel(
      
      # Output: Tabset w/ plot, summary, and table ----
      tabsetPanel(type = "tabs",
                  tabPanel("Table", tableOutput("table")))
      
    )
  )
)

# Define server logic for random distribution app ----
server <- function(input, output) {
  
  # Reactive expression to generate the requested distribution ----
  # This is called whenever the inputs change. The output functions
  # defined below then use the value computed from this expression
  playlist <- reactive({
    
    post <- POST('https://accounts.spotify.com/api/token',
                 accept_json(), authenticate(client_id, client_secret),
                 body = list(grant_type = 'client_credentials'),
                 encode = 'form', httr::config(http_version = 2)) %>% content
    access_token <- post$access_token
    
    playlist_id <- input$playlist_id
    print(playlist_id)
    
    
    url <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"?access_token=",access_token,sep = "")
    playlist <- check(url)
    followers <- playlist$followers$total
    leng <- playlist$tracks$total
    loops <- as.integer(leng/100)
    
    songs <- NULL
    for(j in 0:loops){
      offset <- j*100
      url <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,"&limit=100&offset=",offset,sep = "")
      df <- check(url)
      songs <- c(songs,df$items$track$id)
      
    }
    if(is.null(songs)){
      return(NULL)
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
        artists<- c(artists,paste(l$name,collapse=", "))
      }
      data2 <- rbind(data2,data.frame(info$name, artists,info$album$name,info$album$release_date, analysis$tempo, analysis$duration_ms, analysis$loudness, info$popularity))
    }
    
    colnames(data2) <- c("Song Title", "Artist Name", "Album Name","Release Date", "Tempo","Duration","Loudness","Popularity")
    data2
    
  })
  
  # Generate an HTML table view of the data ----
  output$table <- renderTable({
    playlist() 
  })
  
}

shinyApp(ui = ui, server = server)

