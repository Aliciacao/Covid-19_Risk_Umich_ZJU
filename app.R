library(shiny)
library(readr)
library(magrittr)
library(leaflet)
library(dplyr)
library(ggplot2)
library(plotly)
library(lubridate)
library(tigris)
COVID19_by_Neighborhood <- read.csv("data/COVID19_by_Neighborhood.csv")
# char_zips <- zctas(cb = TRUE, starts_with = c("90","91","92"))
# saveRDS(char_zips, "char_zips.rds")

ui <- fluidPage(
    titlePanel("Covid-19 Risk Umich + ZJU"),
    tabPanel("Interactive map",
             div(class="outer",
                 textOutput("select_stat"),
                 leafletOutput("map",width = "100%", height = 700),
                 absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                               draggable = TRUE, top = "100", left = "70", 
                               right = "auto", bottom = "auto",
                               width = "330", height = "500",
                               
                               h3("explorer"),
                               
                               selectInput("statistic",
                                           "You are interested in...",
                                           c("exposure risk", "public mobility", "death rate","infectious rate"),
                                           selected = "exposure risk"),
                               selectInput("community",
                                           "locate at ...",
                                           unique(COVID19_by_Neighborhood$COMTY_NAME),
                                           multiple = T),
                               plotly::plotlyOutput("hist", height = 200)
                               )))
)

server <- function(input, output) {
    options(tigris_use_cache = TRUE)
    output$select_stat = renderText(paste("So you want to know",input$statistic))
    output$map = renderLeaflet({
        char_zips <- readRDS("char_zips.rds")
        
        # join zip boundaries and case count
        char_zips <- geo_join(char_zips, 
                              data.frame("zipcode"=char_zips$GEOID10,"RiskScore" = c(1:652)), 
                              by_sp = "GEOID10", 
                              by_df = "zipcode",
                              how = "left")
        pal <- colorNumeric(
            palette = "Reds",
            domain = c(1:700))
        
        labels <- paste0(
                "Zip Code: ",
                char_zips@data$GEOID10, "<br/>",
                "Case Count: ",
                char_zips@data$RiskScore) %>%
            lapply(htmltools::HTML)
        
        char_zips %>% 
            leaflet %>% 
            addProviderTiles("CartoDB.Voyager") %>% 
            setView(lng = -118.19, lat=34.05, zoom = 9) %>%
            addPolygons(fillColor = ~pal(RiskScore),
                        weight = 2,
                        opacity =0.15,
                        color = "white",
                        dashArray = "3",
                        fillOpacity = 0.5,
                        highlight = highlightOptions(weight = 2,
                                                     color = "#667",
                                                     dashArray = "",
                                                     fillOpacity = 0.7,
                                                     bringToFront = TRUE),label = labels) %>%
            addLegend(pal = pal, 
                      values = ~RiskScore, 
                      opacity = 0.7, 
                      title = htmltools::HTML("Case Count <br> 
                                    by Zip Code"),
                      position = "bottomright")

    })
    output$hist = renderPlotly({
        ggplotly(
            ggplot2::ggplot(data = COVID19_by_Neighborhood)+
                geom_histogram(aes(x=cases), binwidth=30) +
                theme_classic()
        )
    })
}

shinyApp(ui = ui, server = server)
