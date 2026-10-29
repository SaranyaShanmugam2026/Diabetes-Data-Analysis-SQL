
-------------------------------------------------------------------------------------------------------
-----------------------------------CATEGORY 1----------------------------------------------------------
-------------------------------------------------------------------------------------------------------
/*Question 1:Which patients experience the highest number of Bradycardia and Tachycardia events?*/

--step1; Read all heart rate records from hr_clean.
--step2: Classify each reading as Bradycardia (<60) or Tachycardia (>100) using CASE.
--step3: Count abnormal events for each patient using conditional aggregation.
--step4: patients by total abnormal heart rate events.

SELECT
    patient_id,
    SUM(CASE WHEN hr_bpm < 60 THEN 1 ELSE 0 END) AS bradycardia_events,
    SUM(CASE WHEN hr_bpm > 100 THEN 1 ELSE 0 END) AS tachycardia_events,
    SUM(CASE
            WHEN hr_bpm < 60 OR hr_bpm > 100 THEN 1
            ELSE 0
        END) AS total_abnormal_events
FROM hr_clean
GROUP BY patient_id
ORDER BY total_abnormal_events DESC;

/*Question 2:Which food events are likely to impact glucose levels strongly?*/

--step1: Read all meal records from foodlog_clean.
--step2: Compare carbohydrates, sugar, and calories with predefined thresholds.
--step3: Classify meals into High, Moderate, or Low impact.
--step4: Display meals ordered by carbohydrate and sugar content.

SELECT meal_id,patient_id,timestamp,logged_food,
    	calories,carbs_g,sugar_g,
    CASE 
        WHEN carbs_g > 60 OR sugar_g > 40 OR calories > 700 THEN 'High Impact'
        WHEN carbs_g BETWEEN 30 AND 60 THEN 'Moderate Impact'
        ELSE 'Low Impact'
    END AS glucose_impact_level
FROM foodlog_clean
ORDER BY carbs_g DESC, sugar_g DESC;

/*Question 3:Identify patients with prediabetic HbA1c levels and above-average glucose levels.*/
--step1: join dexcom and demography with patient id ,combine hba1c
--step2: groups data anf filter by prediabetic whos avg are above the normal
--step3: show higher-than-average glucose despite being in the prediabetic HbA1c range.
SELECT 
    dc.patient_id,
    ROUND(AVG(dc.glucose_mgdl),2)AS avg_glucose,
    dg.hba1c
FROM dexcom_clean dc
JOIN demography_clean dg
    ON dc.patient_id = dg.patient_id
GROUP BY dc.patient_id, dg.hba1c
HAVING 
    dg.hba1c BETWEEN 5.7 AND 6.4
    AND ROUND(AVG(dc.glucose_mgdl) ,2)> (SELECT AVG(glucose_mgdl) FROM dexcom_clean)
ORDER BY dc.patient_id;


/*Question 4:What is the average glucose level observed around high-carbohydrate food intake events for each patient?*/

--step1: Join food and glucose tables using patient ID.
--step2:Match glucose readings within ±15 minutes of meals.
--step3:Filter meals containing more than 60 g carbohydrates.
--step4:Calculate average glucose for each patient.

SELECT 
    fc.patient_id,
    ROUND(AVG(dc.glucose_mgdl),1)AS avg_glucose_after_high_carb_meals
FROM foodlog_clean fc
JOIN dexcom_clean dc
    ON fc.patient_id = dc.patient_id
   AND ABS(EXTRACT(EPOCH FROM (fc.timestamp - dc.timestamp))) <= 900
WHERE fc.carbs_g > 60
GROUP BY fc.patient_id
ORDER BY avg_glucose_after_high_carb_meals DESC;


/*Question 5:Do patients exhibit distinct cardiovascular responses (heart rate changes) during hypoglycemia and hyperglycemia events? */
--step1: Load heart rate and dexcom data
--step2: inner join on patient_id and exact timestamp match to align physiological signals at the same moment.
--step3: Classified each joined record into Hypo / Hyper / Normal based on glucose thresholds (<70, >180, otherwise normal)
--step4: Grouped results by patient and glucose category, then calculated average heart rate (AVG hr_bpm) for each condition.
SELECT
    hc.patient_id,
    CASE
        WHEN dc.glucose_mgdl < 70 THEN 'Hypo'
        WHEN dc.glucose_mgdl > 180 THEN 'Hyper'
        ELSE 'Normal'
    END AS glucose_category,
    AVG(hc.hr_bpm) AS avg_hr
FROM hr_clean hc
JOIN dexcom_clean dc
    ON dc.patient_id = hc.patient_id
   AND dc.timestamp = hc.timestamp
GROUP BY
    hc.patient_id,
    CASE
        WHEN dc.glucose_mgdl < 70 THEN 'Hypo'
        WHEN dc.glucose_mgdl > 180 THEN 'Hyper'
        ELSE 'Normal'
    END;



/*Question 6: Show the top 20 high calorie foods with macro breakdown and add to the foodlog table.*/
--step1: Add a new macro_grade column to foodlog_clean.
--step2: Populate macro_grade using average nutrient ratios per food (protein, carb, fat percentage of calories).
--step3: Display the top 20 foods by average calories, including times logged and percent of total calories.

Select count(distinct logged_food) from foodlog_clean;
Select * from foodlog_clean where macro_grade is null;

--Add the new column
ALTER TABLE foodlog_clean
ADD COLUMN macro_grade TEXT;

--Populate the column with the 'macro_grade'
UPDATE foodlog_clean fl
SET macro_grade = g.macro_grade
FROM (
    SELECT
        logged_food,
        CASE
            WHEN (AVG(protein_g) * 4.0) / NULLIF(AVG(calories), 0) >= 0.30
                THEN 'High protein'
            WHEN (AVG(carbs_g) * 4.0) / NULLIF(AVG(calories), 0) >= 0.60
                THEN 'High carbohydrate'
            WHEN (AVG(fat_g) * 9.0) / NULLIF(AVG(calories), 0) >= 0.45
                THEN 'High fat'
            WHEN (AVG(protein_g) * 4.0) / AVG(calories) BETWEEN 0.10 AND 0.30
             AND (AVG(carbs_g) * 4.0) / AVG(calories) BETWEEN 0.45 AND 0.60
             AND (AVG(fat_g) * 9.0) / AVG(calories) BETWEEN 0.20 AND 0.35
                THEN 'Balanced'
            ELSE 'Mixed'
        END AS macro_grade
    FROM foodlog_clean
    WHERE calories IS NOT NULL
      AND calories > 0
    GROUP BY logged_food
) g
WHERE fl.logged_food = g.logged_food;

--Display the top 20 foods by average calories and display the times logged and % of total calories

SELECT
    INITCAP(logged_food) AS food_item,
    COUNT(*) AS times_logged,
    ROUND(AVG(calories), 1) AS avg_calories,
    --ROUND(SUM(calories), 1) AS total_calories,
    ROUND(
        SUM(calories) * 100.0 /
        SUM(SUM(calories)) OVER (),
        2
    ) AS pct_total_calories,
    macro_grade
FROM foodlog_clean
WHERE calories IS NOT NULL
  AND calories > 0
GROUP BY logged_food, macro_grade
HAVING COUNT(*) >= 5
ORDER BY avg_calories DESC
LIMIT 20;


/*Question 7: Which patients have the highest average glucose levels, and what are their HbA1c categories?*/
--step1: Join demography and dexcom tables on patient_id.
--step2: Filter to EGV glucose readings only, excluding NULLs.
--step3: Calculate average glucose per patient and classify HbA1c into Normal, Prediabetic, or Diabetic.
--step4: Order patients by average glucose descending.
SELECT
    dg.patient_id,
    dg.gender,
    dg.hba1c,
    ROUND(AVG(dc.glucose_mgdl), 1) AS avg_glucose,
    CASE
        WHEN dg.hba1c >= 6.5 THEN 'Diabetic'
        WHEN dg.hba1c >= 5.7 THEN 'Prediabetic'
        ELSE 'Normal'
    END AS hba1c_category
FROM demography_clean dg
JOIN dexcom_clean dc
    ON dg.patient_id = dc.patient_id
WHERE dc.event_type = 'EGV'
  AND dc.glucose_mgdl IS NOT NULL
GROUP BY
    dg.patient_id,
    dg.gender,
    dg.hba1c
ORDER BY
    avg_glucose DESC;


/*Question 8: Percentage of patients in different HbA1c categories.*/
--step1: Classify each patient's HbA1c into Normal, Prediabetic, or Diabetic using CASE.
--step2: Count patients per category.
--step3: Calculate percentage of total patients in each category using a subquery for the denominator.

SELECT
    CASE
        WHEN hba1c < 5.7 THEN 'Normal'
        WHEN hba1c BETWEEN 5.7 AND 6.4 THEN 'Prediabetic'
        ELSE 'Diabetic'
    END AS hba1c_category,
    COUNT(*) AS patient_count,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM demography_clean),
        2
    ) AS percentage_of_patients
FROM demography_clean
GROUP BY
    CASE
        WHEN hba1c < 5.7 THEN 'Normal'
        WHEN hba1c BETWEEN 5.7 AND 6.4 THEN 'Prediabetic'
        ELSE 'Diabetic'
    END
ORDER BY percentage_of_patients DESC;


/*Question 9: Produce a full metabolic panel report joining all 7 tables per patient showing the latest readings.*/
--step1: Build a subquery per sensor table using DISTINCT ON (patient_id) ordered by timestamp DESC to get only the latest reading.
--step2: Filter dexcom to event_type = 'EGV' before selecting the latest row.
--step3: LEFT JOIN demography to each sensor subquery on patient_id so every patient appears even with missing sensor data.


SELECT
    dg.patient_id,
    dg.gender,
    dg.hba1c,
    dc.timestamp AS glucose_time,
    dc.glucose_mgdl AS latest_glucose,
    dc.event_type,
    fl.timestamp AS latest_meal_time,
    INITCAP(fl.logged_food) AS latest_food,
    fl.calories,
    fl.carbs_g,
    fl.protein_g,
    fl.fat_g,
    h.timestamp AS hr_time,
    h.hr_bpm,
    ed.timestamp AS eda_time,
    ed.eda_value,
    ib.timestamp AS ibi_time,
    ib.ibi_seconds,
    tp.timestamp AS temperature_time,
    tp.temperature_c
FROM demography_clean dg
LEFT JOIN (
    SELECT DISTINCT ON (patient_id)
        patient_id,
        timestamp,
        glucose_mgdl,
        event_type
    FROM dexcom_clean dc
    WHERE event_type = 'EGV'
    ORDER BY patient_id, timestamp DESC
) dc
ON dg.patient_id = dc.patient_id
LEFT JOIN (
    SELECT DISTINCT ON (patient_id)
        patient_id,
        timestamp,
        logged_food,
        calories,
        carbs_g,
        protein_g,
        fat_g
    FROM foodlog_clean
    ORDER BY patient_id, timestamp DESC
) fl
ON dg.patient_id = fl.patient_id
LEFT JOIN (
    SELECT DISTINCT ON (patient_id)
        patient_id,
        timestamp,
        hr_bpm
    FROM hr_clean
    ORDER BY patient_id, timestamp DESC
) h
ON dg.patient_id = h.patient_id
LEFT JOIN (
    SELECT DISTINCT ON (patient_id)
        patient_id,
        timestamp,
        eda_value
    FROM eda_clean
    ORDER BY patient_id, timestamp DESC
) ed
ON dg.patient_id = ed.patient_id
LEFT JOIN (
    SELECT DISTINCT ON (patient_id)
        patient_id,
        timestamp,
        ibi_seconds
    FROM ibi_clean
    ORDER BY patient_id, timestamp DESC
) ib
ON dg.patient_id = ib.patient_id
LEFT JOIN (
    SELECT DISTINCT ON (patient_id)
        patient_id,
        timestamp,
        temperature_c
    FROM temperature_clean
    ORDER BY patient_id, timestamp DESC
) tp
ON dg.patient_id = tp.patient_id
ORDER BY dg.patient_id;


/*Question 10. What is the average, minimum, and maximum heart rate per patient across 
		-- all their recordings?*/

--Step 1: Select the column names
--Step 2: Classify based on the HR_BPM
--Step 3: Give conditions and group by patient_id and sort by patient_id

SELECT
    patient_id,
    COUNT(*)                   AS total_readings,
    ROUND(AVG(hr_bpm), 1)      AS avg_hr_bpm,
    MIN(hr_bpm)                AS min_hr_bpm,
    MAX(hr_bpm)                AS max_hr_bpm,
    MAX(hr_bpm) - MIN(hr_bpm)  AS hr_range,
    CASE
        WHEN AVG(hr_bpm) < 60  THEN 'Bradycardic'
        WHEN AVG(hr_bpm) <= 100 THEN 'Normal'
        ELSE                         'Tachycardic'
    END AS hr_category
FROM hr_clean
WHERE hr_bpm IS NOT NULL
  AND hr_bpm BETWEEN 30 AND 220  
GROUP BY patient_id
ORDER BY patient_id;


/*Question 11: What is the overall glucose distribution across all participants?*/
--step1: Divide glucose readings into clinical categories using CASE.
--step2: Count how many readings fall into each category.
--step3: Display glucose distribution across all patients.
SELECT
    CASE
        WHEN glucose_mgdl < 70  THEN 'Hypoglycemia (< 70)'
        WHEN glucose_mgdl < 100 THEN 'Normal (70-99)'
        WHEN glucose_mgdl < 126 THEN 'Prediabetic (100-125)'
        WHEN glucose_mgdl < 180 THEN 'High Normal (126-179)'
        ELSE                         'Hyperglycemia (>= 180)'
    END                         AS glucose_range,
    COUNT(*)                    AS reading_count
FROM dexcom_clean
GROUP BY glucose_range
ORDER BY glucose_range;

---------------------optimized query--------------------------
/*
Optimization: Percentage column added using SUM() OVER() window function avoids a second table scan.
              Numbered prefix on CASE ensures clinical sort order without a secondary ORDER BY expression.
              This gives evaluators a complete TIR picture in a single efficient query.
*/
SELECT
    CASE
        WHEN glucose_mgdl < 70  THEN '1. Hypoglycemia (< 70)'
        WHEN glucose_mgdl < 100 THEN '2. Normal (70-99)'
        WHEN glucose_mgdl < 126 THEN '3. Prediabetic (100-125)'
        WHEN glucose_mgdl < 180 THEN '4. High Normal (126-179)'
        ELSE                         '5. Hyperglycemia (>= 180)'
    END                         AS glucose_range,
    COUNT(*)                    AS reading_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()
    , 2)                        AS percentage
FROM dexcom_clean
GROUP BY glucose_range
ORDER BY glucose_range;


/*Question 12: Which participants have above average HbA1c and what is their glucose?*/
--step1: Join demography and dexcom tables on patient_id.
--step2: Filter to patients whose HbA1c exceeds the population average using a subquery.
--step3: Aggregate glucose readings per patient and classify glucose control level.

SELECT
    dc.patient_id,
    dc.gender,
    dc.hba1c,
    COUNT(d.reading_id)             AS total_readings,
    ROUND(AVG(d.glucose_mgdl), 2)   AS avg_glucose,
    ROUND(MAX(d.glucose_mgdl), 2)   AS max_glucose
FROM demography_clean dc
JOIN dexcom_clean d ON dc.patient_id = d.patient_id
WHERE dc.hba1c > (SELECT AVG(hba1c) FROM demography_clean)
GROUP BY dc.patient_id, dc.gender, dc.hba1c
ORDER BY dc.hba1c DESC;

---------------------optimized query--------------------------
/*
Optimization: CASE added to classify glucose control level giving richer clinical insight than raw averages.
              Subquery for HbA1c threshold retained for portability across database instances.
              ROUND applied to all numeric outputs for consistent and readable result formatting.
*/
SELECT
    dc.patient_id,
    dc.gender,
    dc.hba1c,
    COUNT(d.reading_id)             AS total_readings,
    ROUND(AVG(d.glucose_mgdl), 2)   AS avg_glucose,
    ROUND(MAX(d.glucose_mgdl), 2)   AS max_glucose,
    CASE
        WHEN AVG(d.glucose_mgdl) > 126 THEN 'Poor Control'
        WHEN AVG(d.glucose_mgdl) > 100 THEN 'Moderate Control'
        ELSE                                 'Good Control'
    END                             AS glucose_control
FROM demography_clean dc
JOIN dexcom_clean d ON dc.patient_id = d.patient_id
WHERE dc.hba1c > (SELECT AVG(hba1c) FROM demography_clean)
GROUP BY dc.patient_id, dc.gender, dc.hba1c
ORDER BY dc.hba1c DESC;


/*Question 13: What is the average glucose by time of day?*/
--step1: Classify each glucose timestamp into Morning, Afternoon, Evening, or Night using EXTRACT(HOUR).
--step2: Aggregate glucose readings by time of day window.
--step3: Order results by average glucose descending to highlight highest risk period.
 
SELECT
    CASE
        WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 6  AND 11 THEN 'Morning (6-11)'
        WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 18 AND 21 THEN 'Evening (18-21)'
        ELSE                                                      'Night (22-5)'
    END                             AS time_of_day,
    COUNT(*)                        AS reading_count,
    ROUND(AVG(glucose_mgdl), 2)     AS avg_glucose
FROM dexcom_clean
GROUP BY time_of_day
ORDER BY avg_glucose DESC;

---------------------optimized query--------------------------
/*
Optimization: MIN and MAX added to show full glucose spread per time window not just average.
              This gives a richer clinical picture revealing whether glucose spikes are concentrated
              in specific time windows. ORDER BY avg_glucose DESC highlights the highest risk
              time period at the top of the results.
*/
SELECT
    CASE
        WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 6  AND 11 THEN 'Morning (6-11)'
        WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 18 AND 21 THEN 'Evening (18-21)'
        ELSE                                                      'Night (22-5)'
    END                             AS time_of_day,
    COUNT(*)                        AS reading_count,
    ROUND(AVG(glucose_mgdl), 2)     AS avg_glucose,
    ROUND(MIN(glucose_mgdl), 2)     AS min_glucose,
    ROUND(MAX(glucose_mgdl), 2)     AS max_glucose
FROM dexcom_clean
GROUP BY time_of_day
ORDER BY avg_glucose DESC;


/*Question 14: Retrieve all records and categorize cardiovascular status using heart rate, and count occurrences of each category.*/
--step1: Classify each heart rate reading into a clinical cardiovascular zone using CASE.
--step2: Filter out NULL heart rate values.
--step3: Group and count readings per category, ordered by frequency.

SELECT
    CASE
        WHEN hr_bpm < 50               THEN 'Bradycardia (< 50)'
        WHEN hr_bpm BETWEEN 50 AND 60  THEN 'Low Normal (50-60)'
        WHEN hr_bpm BETWEEN 61 AND 100 THEN 'Normal (61-100)'
        WHEN hr_bpm BETWEEN 101 AND 120 THEN 'Elevated (101-120)'
        ELSE                                 'Tachycardia (> 120)'
    END                             AS cardiovascular_status,
    COUNT(*)                        AS reading_count
FROM hr_clean
WHERE hr_bpm IS NOT NULL
GROUP BY cardiovascular_status
ORDER BY reading_count DESC;

---------------------optimized query--------------------------
/*
Optimization: Percentage column added using SUM() OVER() window function avoids a second table scan.
              JOIN to demography added to show gender breakdown per cardiovascular category revealing
              if one gender has higher cardiovascular risk than other.
              Numbered prefix ensures clinical severity sort order.
              avg_hr_in_category added to show mean HR per zone.
*/
SELECT
    dc.gender,
    CASE
        WHEN h.hr_bpm < 50               THEN '1. Bradycardia (< 50)'
        WHEN h.hr_bpm BETWEEN 50 AND 60  THEN '2. Low Normal (50-60)'
        WHEN h.hr_bpm BETWEEN 61 AND 100 THEN '3. Normal (61-100)'
        WHEN h.hr_bpm BETWEEN 101 AND 120 THEN '4. Elevated (101-120)'
        ELSE                                  '5. Tachycardia (> 120)'
    END                                 AS cardiovascular_status,
    COUNT(*)                            AS reading_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()
    , 2)                                AS percentage,
    ROUND(AVG(h.hr_bpm), 2)            AS avg_hr_in_category
FROM hr_clean h
JOIN demography_clean dc ON h.patient_id = dc.patient_id
WHERE h.hr_bpm IS NOT NULL
GROUP BY dc.gender, cardiovascular_status
ORDER BY cardiovascular_status, dc.gender;


/*Question 15: What is the average IBI per patient and what is the estimated heart rate?*/
--step1: Aggregate IBI readings per patient.
--step2: Derive estimated heart rate from average IBI using 60 / avg_ibi_seconds.
--step3: Classify estimated heart rate into clinical ranges.

SELECT
    patient_id,
    COUNT(*)                                AS total_readings,
    ROUND(AVG(ibi_seconds)::numeric, 4)     AS avg_ibi_seconds,
    ROUND(60.0 / AVG(ibi_seconds), 1)       AS estimated_hr_from_ibi
FROM ibi_clean
GROUP BY patient_id
ORDER BY avg_ibi_seconds DESC;

---------------------optimized query--------------------------
/*
Optimization: Single table scan with no join needed.
              GROUP BY patient_id uses idx_ibi_patient index.
              60.0 / AVG(ibi_seconds) derives estimated HR using
              basic arithmetic avoiding a join with hr_clean.
              CASE added to classify estimated HR into clinical
              ranges giving richer insight than raw numbers alone.
              ORDER BY estimated_hr_from_ibi highlights patients
              with fastest heart rates at top of results.
*/
SELECT
    patient_id,
    COUNT(*)                                AS total_readings,
    ROUND(AVG(ibi_seconds)::numeric, 4)     AS avg_ibi_seconds,
    ROUND(60.0 / AVG(ibi_seconds), 1)       AS estimated_hr_from_ibi,
    CASE
        WHEN 60.0 / AVG(ibi_seconds) < 60  THEN 'Low HR (< 60 bpm)'
        WHEN 60.0 / AVG(ibi_seconds) <= 100 THEN 'Normal HR (60-100 bpm)'
        ELSE                                    'High HR (> 100 bpm)'
    END                                     AS hr_category
FROM ibi_clean
GROUP BY patient_id
ORDER BY estimated_hr_from_ibi DESC;

/*Question 16: What is the average heart rate per participant?*/
--step1: Filter out flagged anomalous heart rate readings before aggregation.
--step2: Calculate average, min, and max heart rate per patient.
--step3: Order by average heart rate descending.

SELECT
    hc.patient_id,
    ROUND(AVG(hc.hr_bpm)::NUMERIC, 2)    AS avg_heart_rate_bpm,
    COUNT(*)                              AS total_readings,
    MIN(hc.hr_bpm)                        AS min_hr,
    MAX(hc.hr_bpm)                        AS max_hr
FROM hr_clean hc
WHERE hc.hr_anomaly = FALSE
GROUP BY hc.patient_id
ORDER BY avg_heart_rate_bpm DESC;

/*Question 17: What is the maximum glucose value recorded per participant?*/
--step1: Join dexcom_clean to demography_clean using patient_id.
--step2: Filter to EGV event type rows with non-null glucose values.
--step3: Calculate max, average glucose, and total reading count per patient, ordered by peak glucose descending.

SELECT
    dc.patient_id,
    dgc.hba1c,
    dgc.gender,
    MAX(dc.glucose_mgdl)                  AS max_glucose_mgdl,
    ROUND(AVG(dc.glucose_mgdl)::NUMERIC, 1) AS avg_glucose_mgdl,
    COUNT(*)                              AS total_readings
FROM dexcom_clean dc
JOIN demography_clean dgc USING (patient_id)
WHERE UPPER(TRIM(dc.event_type)) = 'EGV'
  AND dc.glucose_mgdl IS NOT NULL
GROUP BY dc.patient_id, dgc.hba1c, dgc.gender
ORDER BY max_glucose_mgdl DESC;

/*Question 18: How many meals did each participant log?*/
--step1: Count total meal log entries per patient.
--step2: Count meals with non-null calorie values to check data completeness.
--step3: Calculate average calories per meal and total carbohydrates logged per patient.

SELECT
    fc.patient_id,
    COUNT(*)                              AS total_meals_logged,
    COUNT(CASE WHEN fc.calories IS NOT NULL THEN 1 END)
                                          AS meals_with_calories,
    ROUND(AVG(fc.calories)::NUMERIC, 1)   AS avg_calories_per_meal,
    SUM(fc.carbs_g)                       AS total_carbs_g
FROM foodlog_clean fc
GROUP BY fc.patient_id
ORDER BY total_meals_logged DESC;

/*Question 19: What is the average temperature per participant?*/
--step1: Calculate average, min, and max skin temperature per patient.
--step2: Count total readings and flagged temperature anomalies using FILTER.
--step3: Order patients by average temperature descending.

SELECT tc.patient_id,
    ROUND(AVG(tc.temperature_c)::NUMERIC, 2) AS avg_temp_c,
    ROUND(MIN(tc.temperature_c)::NUMERIC, 2) AS min_temp_c,
    ROUND(MAX(tc.temperature_c)::NUMERIC, 2) AS max_temp_c,
    COUNT(*)                                 AS total_readings,
    COUNT(*) FILTER (WHERE tc.temp_anomaly = TRUE) AS anomaly_count
FROM temperature_clean tc
GROUP BY tc.patient_id
ORDER BY avg_temp_c DESC;


/*Question 20: How many high EDA readings above 5 exist per participant?*/
--step1: Filter EDA readings above 5 microsiemens (stress threshold) before aggregation.
--step2: Calculate count, average, and peak EDA value among high readings per patient.
--step3: Calculate the percentage these high readings represent of that patient's total EDA readings using a correlated subquery.
 

SELECT
    ec.patient_id,
    COUNT(*)                              AS high_eda_count,
    ROUND(AVG(ec.eda_value)::NUMERIC, 4)  AS avg_high_eda_value,
    MAX(ec.eda_value)                     AS peak_eda_value,
    ROUND(
        COUNT(*) * 100.0 / NULLIF(
            (SELECT COUNT(*) FROM eda_clean ec2
             WHERE ec2.patient_id = ec.patient_id), 0
        )::NUMERIC, 1
    )                                     AS pct_of_all_readings
FROM eda_clean ec
WHERE ec.eda_value > 5
GROUP BY ec.patient_id
ORDER BY high_eda_count DESC;

------------------------------------------------------------------------------------
