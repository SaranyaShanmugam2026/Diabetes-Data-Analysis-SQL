# Diabetes Data Analysis Using SQL

## Project Overview

We worked on a diabetes healthcare data analysis project using PostgreSQL, where we analyzed patient demographics, continuous glucose monitoring (CGM) readings, wearable sensor measurements, and food intake records.

Our focus was to transform raw healthcare data into structured, reliable datasets and use SQL to explore glucose patterns, physiological measurements, and patient monitoring trends.

As **Team 11 – Data Detectives**, we worked collaboratively on data cleaning, exploratory analysis, complex SQL queries, and query optimization to identify meaningful patterns in the data.

## Project Objectives

Our main objectives were to:

- Clean and validate healthcare and wearable sensor datasets to improve data quality.
- Analyze patient glucose readings and classify HbA1c levels.
- Identify hyperglycemia patterns and glucose variability across patients.
- Examine relationships between glucose readings, heart rate, skin temperature, and other physiological measurements.
- Investigate missing glucose recordings and monitoring consistency.
- Apply simple, intermediate, and advanced SQL techniques to answer analytical questions.
- Optimize queries to efficiently process large volumes of sensor data.

## Dataset Description

We worked with **seven related datasets**, containing patient information, glucose measurements, wearable sensor readings, and food consumption records.

| Dataset | Description |
|---|---|
| Demography | Patient demographic details and HbA1c measurements |
| Dexcom | Continuous glucose monitoring readings |
| Heart Rate | Heart rate measurements collected through wearable sensors |
| EDA | Electrodermal activity measurements |
| IBI | Inter-beat interval measurements |
| Temperature | Skin temperature readings |
| Food Log | Food intake, calories, and nutritional information |

We used patient identifiers to connect related datasets and timestamps to analyze time-based measurements. This allowed us to combine information from multiple sources and examine patient-level trends.

## Tools and Technologies

- **Database:** PostgreSQL
- **Programming Languages:** SQL, PL/pgSQL
- **SQL Techniques:** Joins, subqueries, aggregations, CTEs, window functions, conditional expressions, indexing, stored procedures, and user-defined functions

## Data Cleaning and Preparation

We started by exploring the seven datasets to understand their structure, data types, and overall data quality.

We checked for missing values, duplicate records, and unusual measurements. We also examined minimum and maximum values in numerical columns to identify potential data quality issues.

During the cleaning process, we:

- Used SQL queries to identify missing values and examine data completeness.
- Applied the `ROW_NUMBER()` window function to identify and remove duplicate records where applicable.
- Converted source columns into appropriate data types for consistent analysis.
- Created cleaned tables with primary keys and foreign key relationships.
- Created anomaly flags for selected sensor measurements to distinguish potentially unusual readings.
- Created indexes on patient IDs and timestamps to improve query performance when working with large sensor datasets.
- Validated the cleaned tables using record counts before proceeding with the analysis.

These steps helped us prepare structured datasets for further analysis while maintaining consistency across related tables.

## SQL Analysis

We organized our analysis into three categories based on query complexity: Simple, Intermediate, and Advanced.

### 1. Simple Analysis

We began with exploratory SQL queries to understand the overall dataset and identify basic patient-level patterns.

We used aggregate functions such as `COUNT()`, `AVG()`, `MIN()`, and `MAX()` to summarize glucose readings, heart rate measurements, and food consumption data.

We also used `CASE` statements to classify glucose readings and HbA1c measurements into different categories.

Our analysis included:

- Calculating average, minimum, and maximum glucose and heart rate measurements.
- Classifying patients based on HbA1c values.
- Analyzing glucose distributions across participants.
- Examining food consumption and calorie information.
- Joining multiple tables to generate patient-level summaries.

This initial analysis helped us understand the characteristics of the data before moving into more complex investigations.

### 2. Intermediate Analysis

After completing the initial exploration, we used more complex SQL queries to investigate relationships, variability, and time-based patterns.

We applied Common Table Expressions (CTEs), window functions, conditional aggregations, and joins to analyze glucose fluctuations and monitoring consistency.

Our analysis included:

- Measuring glucose variability across patients using averages and standard deviations.
- Calculating the percentage of glucose readings above selected thresholds.
- Identifying gaps between consecutive glucose recordings using `LEAD()`.
- Comparing heart rate measurements with inter-beat interval data.
- Combining sensor readings to investigate relationships between physiological measurements.

We also refined selected queries using CTEs, window functions, and conditional aggregation to make the logic more efficient and easier to maintain.

### 3. Advanced Analysis

For the advanced analysis, we used PostgreSQL features to develop reusable SQL logic and perform more detailed patient-level investigations.

We created a **user-defined function** to classify glucose readings into categories based on specified thresholds.

We also developed a **stored procedure** to generate patient summary information, including glucose measurements, heart rate statistics, and food consumption details.

Our advanced analysis included:

- Creating reusable functions for glucose classification.
- Developing stored procedures to generate patient-level summaries.
- Investigating monitoring consistency and missing recording days.
- Analyzing time-based glucose patterns using window functions.
- Combining multiple sensor measurements for more detailed analysis.
- Applying SQL optimization techniques to improve query efficiency.

These queries allowed us to move beyond basic summaries and explore more complex relationships within the healthcare data.

## Key Findings and Insights

Through our SQL analysis, we identified several patterns in glucose monitoring and physiological measurements.

### Glucose Variability

We calculated glucose variability across patients using statistical measures such as standard deviation and coefficient of variation.

Our analysis showed differences in glucose variability between participants, indicating that glucose patterns were not consistent across the study population.

### Hyperglycemia Patterns

We examined glucose readings above 180 mg/dL and calculated the percentage of readings exceeding this threshold for each patient.

We observed that some patients had a higher proportion of elevated glucose readings, while others had fewer or no readings above the selected threshold.

### Monitoring Gaps

We analyzed the time intervals between consecutive glucose recordings using SQL window functions.

This helped us identify patients with longer recording gaps and assess how consistently glucose measurements were collected.

### Wearable Sensor Analysis

We combined glucose, heart rate, and other wearable sensor measurements to explore relationships between physiological signals.

This provided a broader view of patient monitoring patterns beyond glucose measurements alone.

**Note:** These findings are based on exploratory analysis of the available dataset and are not intended to provide clinical diagnoses.

## Skills Demonstrated

Through this project, we applied:

- SQL data cleaning and validation
- Relational database design
- Multi-table joins and aggregations
- Common Table Expressions (CTEs)
- Window functions
- Conditional logic using `CASE`
- Data quality and anomaly checks
- SQL query optimization and indexing
- Stored procedures and user-defined functions
- Exploratory healthcare data analysis
- Analytical problem-solving
- Team collaboration

## Conclusion

Through this project, we gained practical experience working with multiple healthcare datasets and large volumes of time-based sensor data.

We used PostgreSQL to clean and organize raw data, perform exploratory and advanced analysis, identify glucose monitoring patterns, and optimize queries for efficient processing.

The project strengthened our understanding of data quality, relational databases, SQL problem-solving, and interpreting analytical results from real-world healthcare data.
