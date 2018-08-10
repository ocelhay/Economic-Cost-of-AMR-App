# Economic Cost of AMR App
# Author: olivier.celhay@gmail.com

library(DT)
library(markdown)
library(readxl)
library(shiny)
library(tidyverse)

# Define UI for application that draws a histogram
ui <- fluidPage(
  
  # Application title
  # fluidRow(HTML('<h1>BETA</h1><center><h2>AMR Costing Application</h2></center>')),
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
                                       a("for US", href="https://www.dropbox.com/s/35jyq12eamz3idj/Inputs_App_US.xlsx?dl=1", target="_blank"),
                                       em("or"),
                                       a("for Thailand", href="https://www.dropbox.com/s/no5qln6y2y3i1q1/Inputs_App_TH.xlsx?dl=1", target="_blank")
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
                                column(width = 6,
                                       h4("Cost per SU of antibiotic per drug class (Cumulative) - QALY = 10"),
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

# Define server logic required to draw a histogram
server <- function(input, output) {
  
  output$downloadData <- downloadHandler(
    filename = "Inputs_App_2.xlsx",
    content = function(file) {
      file.copy("www/Inputs_App_2.xlsx", file)
    }
  )
  
  # Initiate reactive values.
  no_data <- reactiveVal(TRUE)
  import_drug_conso <- reactiveVal(NULL)
  import_drug_cost <- reactiveVal(NULL)
  import_drug_resistance <- reactiveVal(NULL)
  import_eco <- reactiveVal(NULL)
  
  
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
    no_data(FALSE)
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
    if(isTRUE(no_data())) return(NULL)
    
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
  output$table_cost_su <- renderDataTable({
    if(isTRUE(no_data())) return(NULL)
    
    df <- dr() %>%
      filter(val == TRUE) %>%
      group_by(drug_class) %>%
      summarise(total_cost_su = sum(cost_su)) %>%
      ungroup()
    
    datatable(df %>% rename(`Drug Class` = drug_class , `Cost per SU` = total_cost_su),
              rownames = FALSE) %>%
      formatCurrency("Cost per SU")
  })
  
  output$table_cost_societal <- renderDataTable({
    if(isTRUE(no_data())) return(NULL)
    
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

