

                                          
## Diabetes Data Analysis Using SQL

## Project Overview

This project focuses on analyzing diabetes-related health data using PostgreSQL. The analysis combines patient demographic information, continuous glucose monitoring (CGM) readings, wearable sensor measurements, and food intake records.

The objective is to clean and organize multiple datasets, investigate glucose patterns, explore relationships between physiological measurements, and generate meaningful insights using SQL.

The project was developed collaboratively by **Team 11 – Data Detectives**.

## Project Objectives

- Clean and validate healthcare and wearable sensor datasets.
- Analyze patient glucose levels and HbA1c categories.
- Identify patterns in hyperglycemia and glucose variability.
- Examine heart rate, skin temperature, and other sensor measurements.
- Investigate glucose monitoring consistency and missing recording periods.
- Apply intermediate and advanced SQL techniques to solve analytical questions.
- Optimize SQL queries for efficient analysis of large datasets.

## Dataset Description

The project uses seven related datasets:

| Dataset | Description |
|---|---|
| Demography | Patient demographic and HbA1c information |
| Dexcom | Continuous glucose monitoring readings |
| Heart Rate | Wearable heart rate measurements |
| EDA | Electrodermal activity sensor readings |
| IBI | Inter-beat interval measurements |
| Temperature | Skin temperature measurements |
| Food Log | Food intake and nutritional information |

The datasets are connected using patient identifiers and, where appropriate, timestamps.

## Tools and Technologies

- **Database:** PostgreSQL
- **Language:** SQL and PL/pgSQL
- **Techniques:** Joins, aggregations, subqueries, CTEs, window functions, conditional logic, indexing, stored procedures, and user-defined functions

## Data Cleaning and Preparation

Data cleaning was performed to improve consistency and reliability before analysis.

Key activities included:

- Checking missing values and reviewing data completeness.
- Identifying duplicate records using SQL window functions.
- Reviewing minimum and maximum values to identify potentially invalid measurements.
- Converting source fields into appropriate data types.
- Creating cleaned tables with primary and foreign key relationships.
- Flagging selected anomalous sensor readings.
- Creating indexes on patient identifiers and timestamps to improve query performance.
- Validating cleaned tables using record counts.

## SQL Analysis

### 1. Simple Analysis

The initial analysis focused on understanding the data through:

- Patient-level glucose summaries.
- HbA1c classification.
- Glucose distribution analysis.
- Heart rate statistics.
- Food consumption and calorie summaries.
- Combining information across related tables.

### 2. Intermediate Analysis

Intermediate queries explored more complex relationships and trends, including:

- Glucose variability across patients.
- Time spent above selected glucose thresholds.
- Missing glucose monitoring intervals.
- Comparisons between heart rate and inter-beat interval measurements.
- Time-based analysis using common table expressions and window functions.

### 3. Advanced Analysis

Advanced SQL techniques were applied to:

- Develop reusable glucose classification functions.
- Create stored procedures for patient summary reports.
- Analyze monitoring gaps and recording consistency.
- Combine multiple sensor measurements for deeper analysis.
- Improve query efficiency using SQL optimization techniques.

## Example Analytical Findings

The SQL scripts include analyses showing that:

- Glucose variability differed across patients.
- Some patients experienced longer gaps between glucose recordings.
- Elevated glucose readings occurred at different frequencies across participants.
- Combining glucose, heart rate, and other sensor data supported more detailed physiological analysis.

These findings describe patterns in the available dataset and should not be interpreted as clinical diagnoses.


## Skills Demonstrated

- SQL data cleaning and validation
- Relational database design
- Multi-table joins and aggregation
- Common table expressions (CTEs)
- Window functions
- Data quality checks
- SQL query optimization
- Analytical problem-solving
- Healthcare data analysis
- Team collaboration




