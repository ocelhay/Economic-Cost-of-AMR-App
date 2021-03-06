# Economic Cost of AMR App --------------------------------------------------------------------------------------------------
# Author: olivier.celhay@gmail.com

library(DT)
library(markdown)
library(readxl)
library(shiny)
library(tidyverse)

# Define UI for the application
ui <- fluidPage(
  br(),
  
  column(12, 
         
         tabsetPanel(type = "tabs", id='theTabs',
                     tabPanel('About',
                              h3("Welcome to the Economic Cost of AMR App"),
                              fluidRow(
                                column(width = 6, includeMarkdown('./www/markdown/about_2.md')),
                                column(width = 1, br()),
                                column(width = 5, includeMarkdown('./www/markdown/about_1.md'))
                              )
                     ),
                     tabPanel('Inputs',
                              h2("Input Parameters:"),
                              fluidRow(
                                column(width = 3,
                                       h4("Download Template"),
                                       HTML("With default values "),
                                       a("for high income countries", href="https://github.com/ocelhay/Economic-Cost-of-AMR-App/blob/master/templates/Inputs_App_HIC.xlsx", target="_blank"),
                                       em("or"),
                                       a("for low/middle income countries", href="https://github.com/ocelhay/Economic-Cost-of-AMR-App/blob/master/templates/Inputs_App_LMIC.xlsx", target="_blank")
                                ),
                                column(width = 6,
                                       includeMarkdown('./www/markdown/template.md')
                                ),
                                column(width = 3,
                                       h4("Upload File with Custom Parameters"),
                                       fileInput("file_xlsx", label = NULL, accept = ".xlsx", buttonLabel = "Browse...")
                                )
                              )
                     ),
                     tabPanel('Outputs',
                              fluidRow(
                                column(width = 12,
                              htmlOutput("country")
                                )),
                              fluidRow(
                                column(width = 6,
                                       h4("Cost per Standard Unit of antibiotic per drug class (Cumulative) - QALY = 10"),
                                       dataTableOutput("table_cost_su")
                                ),
                                column(width = 6,
                                       h4("Societal cost per course (USD) - QALY = 10"),
                                       dataTableOutput("table_cost_societal")
                                )
                              )
                     )
         )
  )
)





# Define server logic
server <- function(input, output) {
  
  output$downloadData <- downloadHandler(
    filename = "Inputs_App.xlsx",
    content = function(file) {
      file.copy("www/Inputs_App.xlsx", file)
    }
  )
  
  # Initiate reactive values.
  import_eco <- reactiveVal(read_xlsx("www/Default_Thailand.xlsx", sheet = 1))
  import_drug_conso <- reactiveVal(read_xlsx("www/Default_Thailand.xlsx", sheet = 2))
  import_drug_resistance <- reactiveVal(read_xlsx("www/Default_Thailand.xlsx", sheet = 3))
  import_drug_cost <- reactiveVal(read_xlsx("www/Default_Thailand.xlsx", sheet = 4))
  

  # Load .xlsx from input and update reactive values.
  observeEvent(input$file_xlsx,{
    
    # escape if there is no data
    if (is.null(input$file_xlsx)) return(NULL)
    
    # load data
    inFile <- input$file_xlsx
    file <- inFile$datapath
    
    tmp_import_eco <- read_xlsx(file, sheet = 1)
    tmp_import_drug_conso <- read_xlsx(file, sheet = 2)
    tmp_import_drug_resistance <- read_xlsx(file, sheet = 3)
    tmp_import_drug_cost <- read_xlsx(file, sheet = 4)
    
    # update reactive values
    import_eco(tmp_import_eco)
    import_drug_conso(tmp_import_drug_conso)
    import_drug_resistance(tmp_import_drug_resistance)
    import_drug_cost(tmp_import_drug_cost)
  })
  
  # Show tables of inputs
  output$table_drug_conso <- renderDataTable({
    datatable(import_drug_cost())
  })
  
  
  # Computations
  dr <- reactive({
    # Rename columns
    eco <- import_eco()
    names(eco) <- c("country", "population", "gdp", "years")
    
    drug_conso <- import_drug_conso()
    names(drug_conso) <- c("drug_class", "conso_su", "per_day", "duration_day")
    
    drug_resistance <- import_drug_resistance() %>% 
      rename(bug = Name)
    
    drug_cost <- import_drug_cost()
    names(drug_cost) <- c("bug", "death", "infection", "cost", "RMf")
    
    # SU for a full course
    drug_conso <- drug_conso %>%
      mutate(course_su = duration_day * per_day)
    
    # Gather bug-related info
    bugs <- bind_cols(drug_cost, drug_resistance %>% select(-bug)) %>%
      mutate(direct_cost = infection * cost,
             direct_cost_hc = direct_cost * RMf,
             indirect_cost_amr = death * eco$years * eco$gdp,
             indirect_cost_hc = indirect_cost_amr * RMf,
             total_cost = direct_cost_hc + indirect_cost_hc)
    
    bugs <- bugs %>%
      mutate(consumption_drive_res_su = colSums(apply(bugs[, drug_conso$drug_class], 1, function(x) x * drug_conso$conso_su)),
             consumption_drive_res = consumption_drive_res_su * eco$population / 1000,
             direct_cost_su = direct_cost_hc / consumption_drive_res,
             indirect_cost_su = indirect_cost_hc / consumption_drive_res,
             cost_su = direct_cost_su + indirect_cost_su) %>%
      select(-one_of(drug_conso$drug_class))
    
    # Merge dataframes for output
    dr_out <- drug_resistance %>%
      gather(drug_class, val, 2:ncol(drug_resistance))%>%
      left_join(drug_conso, by = "drug_class") %>%
      left_join(bugs, by = "bug")
    
    # Return
    return(dr_out)
  })
  
  
  # Outputs
  output$country <- renderUI({
    h2(import_eco()[1, 1])
    })
  
  
  output$table_cost_su <- renderDataTable({
    df <- dr() %>%
      filter(val == TRUE) %>%
      group_by(drug_class) %>%
      summarise(total_cost_su = sum(cost_su)) %>%
      ungroup()
    
    datatable(df %>% rename(`Drug Class` = drug_class , `Cost per Standard Unit` = total_cost_su),
              rownames = FALSE) %>%
      formatCurrency("Cost per Standard Unit")
  })
  
  output$table_cost_societal <- renderDataTable({
    df <- dr() %>%
      filter(val == TRUE) %>%
      group_by(drug_class, course_su) %>%
      summarise(societal_cost = sum(cost_su*course_su)) %>%
      ungroup() %>%
      select(-course_su)
    
    datatable(df %>% rename(`Drug Class` = drug_class , `Societal Cost` = societal_cost),
              rownames = FALSE) %>%
      formatCurrency("Societal Cost")
  })
}

# Run the application 
shinyApp(ui = ui, server = server)

