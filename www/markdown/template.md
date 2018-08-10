#### Modify the template

##### Population sheet

- Cell A2: A dropdown list allow to select a different country and have Population (2016) and GDP / Capita (2016) values updated
- The number of life years lost per death. The assumption is that all years are considered productive.

##### Antibiotic_consumption sheet:

Columns *Number of pills/vials/tablets per day* and *Duration (Days)* determine the number of standard unit (SU) per full course of treatment. This only affects the calculation of the total cost of AMR per full course, not the cost per SU.

##### Drug-resistance_matrix sheet:

Select the drugs that are assumed to be implicated in driving resistance in each of these organisms by setting the value to TRUE.

##### Burden_costs sheet:

Cost per infection: 

- Costs per infection adaptd from for all pathogens other than S pneumonia taken from: Roberts RR, Hota B, Ahmad I, et al. Hospital and societal costs of antimicrobial-resistant infections in a Chicago teaching hospital: implications for antibiotic stewardship. Clin. Infect. Dis. 2009; 49:1175–84. 
- Costs for treating drug resistant S penumonia were assumed to be much lower due to lesser likelihood of severe outcomes (as indicated by much lower mortlaity rates per infection) and lower cost of second line treatments. 
- The estimates are taken from CDC report: Centers for Disease Control and Prevention. Antibiotic resistance threats in the United States, 2013. 2013: 114. Available at: http://www.cdc.gov/drugresistance/threat-report-2013/index.html.

RMf: The resistance modulating factor specifies the degree to which AMR and its associated costs are driven by human antimicrobial consumption (with other key drivers including for instance agricultural use of antibiotics)
