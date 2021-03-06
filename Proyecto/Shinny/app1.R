
##APP1 EJEMPLO TWITTER REST
install.packages("ggplot2")
install.packages("ggmap")
install.packages("shiny")
install.packages("shinyWidgets")
install.packages("RCurl") 
install.packages("ROAuth")
install.packages("RJSONIO")
install.packages("leaflet")
install.packages("streamR")
install.packages("tm")
install.packages("SnowballC")

library(ggplot2)
library(ggmap)
library(shiny)
library(shinyWidgets)
library(RCurl)
library(RJSONIO)
library(ROAuth)
library(leaflet)
library(streamR)
library(tm)
library(SnowballC)

setwd("D:/Universidad/Diplomado/Rstudio/")
frecuencia_positivos <- 0
frecuencia_negativos <- 0
shinyApp(
  ui <- pageWithSidebar(
    #Titulo de la App
    headerPanel("Analisis Tweets"),
    
    #Crear sideBar panel para Liga
    sidebarPanel(
      
      #Input: Selector de la variable a visualizar
      textInput("filtro", label = "Busqueda:", value = "@petro"),
      
      #Input: Selector de la variable a visualizar
      textInput("lat", label = "Latitud:", value = 4.57),
      
      #Input 2: radioBox para inclusion
      textInput("long", label = "Longitud:", value = -74.29),
      
      chooseSliderSkin("Modern"),
      sliderInput("cantidadTweets", "Cantidad de tweets:",
                  min = 1, max =1000, value = 50)
    ),     
    
    #Crear mainPanel que visualiza resultados
    mainPanel(
      
      #Salida uno ---> Texto
      h2(textOutput("encabezado")),
      #Salida dos ---> Mapa
      leafletOutput("myMap"),
      #Salida tres ---> Texto
      h3(textOutput("twwts")),
      #Salida cuatro ---> Tabla
      DT::dataTableOutput('table'),
      
      plotOutput("histograma")
    )
  ),
  
  
  server = function(input, output) {
    
    #Declaracion de las credenciales de la API de twitter
    consumer_key <- "9D1mcibkU0zu3oMAESphjkpbK"
    consumer_secret <- "gCRVGbIE85i0kfazJSfWAJBAp30GvK8cQFO6v8uy69g5IJn5mg"
    access_token <- "936771334809575424-5lXALAAynvJhIoAUpZGQWEVP2LQYRTJ"
    access_secret <- "ZFkg8mdVCPfltReSL4rAr8tKxQznyh7Vn6U0vfOn1beYb"
    requestURL <- "https://api.twitter.com/oauth/request_token"
    accessURL <- "https://api.twitter.com/oauth/access_token"
    authURL <- "https://api.twitter.com/oauth/authorize"
    
    options(httr_oauth_cache = TRUE) # enable using a local file to cache OAuth access credentials between R sessions
    my_oauth <- OAuthFactory$new(consumerKey = consumer_key,
                                 consumerSecret = consumer_secret,
                                 requestURL = requestURL,
                                 accessURL = accessURL,
                                 authURL = authURL)
    
    # Ejecuta el protocolo OAUth  (handshake) - se autoriza a la aplicacion mediante el ingreso de un PIN de 7 digitos
    my_oauth$handshake(cainfo = system.file("CurlSSL", "cacert.pem", package = "RCurl"))
    
    
    # Issue search query to Twitter
    dataInput <- reactive({  
      
    })
    
    # Create a reactive leaflet map
    mapTweets <- reactive({
      map = leaflet() %>% addTiles() %>%
        addMarkers(as.numeric(dataInput()$longitude), as.numeric(dataInput()$latitude), popup = dataInput()$screenName) %>%
        setView(input$long, input$lat, zoom = 11)
    })
    output$myMap = renderLeaflet(mapTweets())
    
    # Create a reactive table 
    output$table <- DT::renderDataTable(
      colnames = c('Registro','Tweet',"Sentimiento"), 
      options = list(pageLength = 10),
      {
        filterStream(file.name="tweets_candidatos.json",
                     locations = c(input$long, input$lat, -73.39, 5.57), 
                     track= c(input$filtro), oauth=my_oauth, 
                     timeout= 20, 
                     tweets = input$cantidadTweets,
                     lang="es")
        
        # Carga los tweets en fomato .JSON a un dataset de Rstudio
        json_candidatos<- parseTweets(tweets='tweets_candidatos.json', simplify = FALSE)
        texto=json_candidatos$text
        #coordenadas <- json_candidatos$coordinates
        #cat(coordenadas)
        # -------------------------------
        # Pre-procesamiento de los datos 
        # -------------------------------
        
        # Elimina retweets
        limpia_texto = gsub("(RT|via)((?:\\b\\W*@\\w+)+)", "", texto)
        # Elimina puntuacion
        limpia_texto = gsub("[[:punct:]]", "", limpia_texto)
        # Elimina numeros
        limpia_texto = gsub("[[:digit:]]", "", limpia_texto)
        # Elimina URLs
        limpia_texto = gsub("http\\w+", "", limpia_texto)
        limpia_texto = gsub("http[^[:blank:]]+", "", limpia_texto)
        # Elimina a las personas
        limpia_texto = gsub("@\\w+", "", limpia_texto)
        # Elimina espacios innecesarios
        limpia_texto = gsub("[^[:alnum:]]", " ", limpia_texto)
        limpia_texto = gsub("(?<=[\\s])\\s*|^\\s+|\\s+$", "", limpia_texto, perl=TRUE)
        # Elimina emojis o caracteres especiales
        limpia_texto = gsub('<.*>', '', enc2native(limpia_texto))
        # Convierte mayusculas a minusculas
        limpia_texto = tolower(limpia_texto)
        # Elimina palabras vacias (Stopwords)
        limpia_texto <- removeWords(limpia_texto, words = stopwords("spanish"))
        # Aplicacion de Stemming: Principalmente recorta las palabras a su raiz
        limpia_texto <- stemDocument (limpia_texto, language = "spanish") 
        #head( limpia_texto, n = input$cantidadTweets )
        cantidadTweets <-1:length(limpia_texto)
        
        #Se validan los sentimientos del tweet (Prueba)
        sentimiento_Pos <-sample(1:2,length(limpia_texto),replace=T)
        sentimiento_valor <- c("Positivo","Negativo")
        sentimientos_tweets<-1:length(limpia_texto)
        for (posicion in 1:length(limpia_texto)){
          sentimientos_tweets[posicion]=sentimiento_valor[sentimiento_Pos[posicion]]
        }
        
        result = as.matrix(cbind(cantidadTweets, limpia_texto,sentimientos_tweets)) 
        #output <- matrix(unlist(limpia_texto), ncol = 1, byrow = TRUE)
        frecuencia <-data.frame(
          Equipo=table(limpia_texto))
        cantEmpate <-frecuencia$Equipo.Freq
        

        data <- result
      }
    )
    
    output$twwts<- renderText({
      paste("Consolidado de Tweets para ",input$filtro)
    })
    
    output$encabezado<- renderText({
      paste("Ubicacion de Tweets para ",input$filtro)
    })
    
    output$histograma <- renderPlot({
      mydf <- data.frame( Resultados=c(3,2,4))
      barplot(as.matrix(mydf),
              beside=TRUE,
              horiz = F,
              col=c("darkblue","orange","red"),
              names.arg=c("Petro", "Duque" , "Fajardo"), 
              width = 0.2,
              ylab = "Frecuencia",
              main="Consolidado de resultados") 
    })
  }
)

