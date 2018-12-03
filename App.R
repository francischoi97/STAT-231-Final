library(xtable)
library(dplyr)
library(httr)
library(ggplot2)
library(tidyr)
client_id = "58c2614435ab4c29b750b180d0063922"
client_secret = "ab34d429d0df46e3b13d18d7fe0c1473"

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
    playlist_id <- input$playlist_id
    print(playlist_id)
    post <- POST('https://accounts.spotify.com/api/token',
                 accept_json(), authenticate(client_id, client_secret),
                 body = list(grant_type = 'client_credentials'),
                 encode = 'form', httr::config(http_version = 2)) %>% content
    access_token <- post$access_token
    url <- paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,"?limit=200",sep = "")
    df <- jsonlite::fromJSON(paste("https://api.spotify.com/v1/playlists/",playlist_id,"/tracks?access_token=",access_token,sep = ""))
    songs <- df$items$track$id
    data <- data.frame()
    for(i in songs){
      url1 <- paste("https://api.spotify.com/v1/audio-features/",i,"?access_token=",access_token,sep="")
      analysis <- jsonlite::fromJSON(url1)
      url2 <- paste("https://api.spotify.com/v1/tracks/",i,"?access_token=",access_token,sep="")
      info <- jsonlite::fromJSON(url2)
      data <- rbind(data,data.frame(info$name, info$artists$name[1], info$album$name,info$album$release_date, analysis$tempo, analysis$duration_ms, analysis$loudness, info$popularity))
    }
    
    colnames(data) <- c("Song Title", "Artist Name", "Album Name","Release Date", "Tempo","Duration","Loudness","Popularity")
    data
  })
  
  # Generate an HTML table view of the data ----
  output$table <- renderTable({
    playlist() 
  })
  
}

shinyApp(ui = ui, server = server)

