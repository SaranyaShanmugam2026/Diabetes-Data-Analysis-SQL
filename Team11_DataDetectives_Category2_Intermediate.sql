--------------------------------------------------------------------------------------------------
-----------------------------------CATEGORY 2-----------------------------------------------------
--------------------------------------------------------------------------------------------------

/*Question 1:Do patients who consume more high-carbohydrate meals exhibit greater glucose variability?*/

--Step1: Created meal_summary CTE to aggregate food data per patient and count high-carbohydrate meals (carbs_g > 60).
--step2: Created glucose_summary CTE to compute glucose variability using STDDEV(glucose_mgdl) for each patient.
--step3: Joined both CTEs on patient_id to combine dietary exposure with physiological response.
--step4: Applied DENSE_RANK() to rank patients based on high-carb meal frequency and ordered results for comparison.

SELECT
    fc.patient_id,
    COUNT(*) FILTER (WHERE fc.carbs_g > 60) AS high_carb_meal_count,
    STDDEV(dc.glucose_mgdl) AS glucose_variability,

    DENSE_RANK() OVER (ORDER BY COUNT(*) FILTER (WHERE fc.carbs_g > 60) DESC) AS carb_rank

FROM foodlog_clean fc
JOIN dexcom_clean dc
    ON fc.patient_id = dc.patient_id
GROUP BY fc.patient_id;

-----------optimized query---------------
WITH meal_summary AS (
    SELECT
        patient_id,
        COUNT(*) FILTER (WHERE carbs_g > 60) AS high_carb_meal_count
    FROM foodlog_clean
    GROUP BY patient_id
),
glucose_summary AS (
    SELECT
        patient_id,
        ROUND(STDDEV(glucose_mgdl),2) AS glucose_variability
    FROM dexcom_clean
    GROUP BY patient_id
)

SELECT
    m.patient_id,
    m.high_carb_meal_count,
    g.glucose_variability,
    DENSE_RANK() OVER (ORDER BY m.high_carb_meal_count DESC) AS carb_rank
FROM meal_summary m
JOIN glucose_summary g
ON m.patient_id = g.patient_id
ORDER BY carb_rank;

/*Question 2: Which patients have the highest frequency of high-carbohydrate meals over time? */

-- Step 1: Filtered foodlog_clean to include only records where carbs_g > 50, identifying high-carbohydrate meals
-- Step 2: Grouped data by patient_id to aggregate total high-carb meal occurrences per patient
-- Step 3: Calculated COUNT(*) within each group to measure frequency of high-carb meals
-- Step 4: Applied RANK() over the aggregated counts to rank patients by highest high-carb meal frequency
-- Step 5: Ordered final output by rank to highlight patients with highest dietary carbohydrate exposure
SELECT
    patient_id,
    DATE_TRUNC('month', timestamp) AS month,
    COUNT(*) AS high_carb_meals,
    RANK() OVER (
        PARTITION BY patient_id
        ORDER BY COUNT(*) DESC
    ) AS monthly_rank
FROM foodlog_clean
WHERE carbs_g > 50
GROUP BY patient_id, DATE_TRUNC('month', timestamp)
ORDER BY patient_id, month;

/*Question 3:Which hour of the day has the highest average glucose level for each patient?*/
-- Step 1: Extracted the hour of day from timestamp using EXTRACT(HOUR FROM timestamp)
-- Step 2: Grouped data by patient_id and hour_of_day
-- Step 3: Computed AVG(glucose_mgdl) for each patient-hour group
-- Step 4: Applied DENSE_RANK() per patient to rank hours by highest average glucose
-- Step 5: Ordered results by patient_id and glucose_hour_rank

SELECT
    patient_id,
    EXTRACT(HOUR FROM timestamp) AS hour_of_day,
    ROUND(AVG(glucose_mgdl), 1) AS avg_glucose,
    DENSE_RANK() OVER (
        PARTITION BY patient_id
        ORDER BY AVG(glucose_mgdl) DESC
    ) AS glucose_hour_rank
FROM dexcom_clean
GROUP BY patient_id, EXTRACT(HOUR FROM timestamp)
ORDER BY patient_id, glucose_hour_rank;

/*Question 4: Which patients show relative metabolic risk compared to 
the cohort based on unusually high or low glucose readings using percentile-based classification? */
--step1: calculated global glucose thresholds using PERCENTILE_CONT to get 90th (p90) and 10th (p10) percentiles from all readings.
--step2: Tagged each glucose reading as high-risk (≥ p90) or low-risk (≤ p10) by cross joining percentile values to all records.
--step3: Aggregated per patient to compute total high/low risk events and derived a risk score as percentage of extreme readings

WITH percentiles AS (
    SELECT
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY glucose_mgdl) AS p90,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY glucose_mgdl) AS p10
    FROM dexcom_clean
),

risk_flags AS (
    SELECT
        dc.patient_id,
        dc.glucose_mgdl,
        p.p90,
        p.p10,

        CASE WHEN dc.glucose_mgdl >= p.p90 THEN 1 ELSE 0 END AS high_risk_flag,
        CASE WHEN dc.glucose_mgdl <= p.p10 THEN 1 ELSE 0 END AS low_risk_flag

    FROM dexcom_clean dc
    CROSS JOIN percentiles p
)

SELECT
    patient_id,
    SUM(high_risk_flag) AS high_risk_events,
    SUM(low_risk_flag) AS low_risk_events,
    COUNT(*) AS total_readings,

    ROUND(
        (SUM(high_risk_flag) + SUM(low_risk_flag)) * 100.0 / COUNT(*),
        2
    ) AS risk_score

FROM risk_flags
GROUP BY patient_id
ORDER BY risk_score DESC;

/*Question 5:During which hour of the day do patients most frequently record glucose values above their own daily average?*/

--step1: Computed daily average glucose per patient using a window function partitioned by patient_id and date.
--step2: Filtered readings where glucose was above the patient’s daily average and counted occurrences per hour of day.
--step3: Ranked hours per patient using ROW_NUMBER() to identify the hour with the highest above-average glucose frequency.

WITH daily_avg AS (
    SELECT
        patient_id,
        DATE(timestamp) AS glucose_date,
        timestamp,
        glucose_mgdl,
        AVG(glucose_mgdl) OVER (
            PARTITION BY patient_id, DATE(timestamp)
        ) AS daily_avg_glucose
    FROM dexcom_clean
),

hourly_counts AS (
    SELECT
        patient_id,
        EXTRACT(HOUR FROM timestamp) AS hour_of_day,
        COUNT(*) AS above_daily_avg_count
    FROM daily_avg
    WHERE glucose_mgdl > daily_avg_glucose
    GROUP BY patient_id, EXTRACT(HOUR FROM timestamp)
),

ranked_hours AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY patient_id
               ORDER BY above_daily_avg_count DESC
           ) AS hour_rank
    FROM hourly_counts
)

SELECT
    patient_id,
    hour_of_day,
    above_daily_avg_count
FROM ranked_hours
WHERE hour_rank = 1
ORDER BY patient_id;



/*Question 6:Which patients experience continuous high glucose episodes, and how long do those episodes last*/

--Step 1: Compute global glucose percentiles (P90 and P10) from the full dataset.
--Step 2: Attach these percentile thresholds to every glucose record using CROSS JOIN.
--Step 3: Flag each record as high-risk or low-risk based on percentile comparison.
--Step 4: Aggregate flagged values per patient to calculate final risk score and ranking.
--
WITH percentiles AS (
    SELECT
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY glucose_mgdl) AS p90,
        PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY glucose_mgdl) AS p10
    FROM dexcom_clean
),

risk_flags AS (
    SELECT
        dc.patient_id,
        dc.glucose_mgdl,
        p.p90,
        p.p10,

        CASE WHEN dc.glucose_mgdl >= p.p90 THEN 1 ELSE 0 END AS high_risk_flag,
        CASE WHEN dc.glucose_mgdl <= p.p10 THEN 1 ELSE 0 END AS low_risk_flag

    FROM dexcom_clean dc
    CROSS JOIN percentiles p
)

SELECT
    patient_id,
    SUM(high_risk_flag) AS high_risk_events,
    SUM(low_risk_flag) AS low_risk_events,
    COUNT(*) AS total_readings,

    ROUND(
        (SUM(high_risk_flag) + SUM(low_risk_flag)) * 100.0 / COUNT(*),
        2
    ) AS risk_score

FROM risk_flags
GROUP BY patient_id
ORDER BY risk_score DESC;

/*Question 7: .Which patients show long-term glucose stability vs subtle drift over time? */
--Step 1: Aggregate raw CGM readings into daily average glucose per patient.
--Step 2: Order daily data by patient and time to reconstruct time series.
--Step 3: Apply LAG to compute previous-day trend and daily change.
--Step 4: Compute rolling 7-day average and volatility using window functions.

WITH daily_avg AS (
    SELECT
        patient_id,
        DATE(timestamp) AS day,
        ROUND(AVG(glucose_mgdl), 2) AS avg_glucose
    FROM dexcom_clean
    GROUP BY patient_id, DATE(timestamp)
),

enriched AS (
    SELECT
        patient_id,
        day,
        avg_glucose,

        -- previous day value (trend)
        LAG(avg_glucose) OVER (
            PARTITION BY patient_id ORDER BY day
        ) AS prev_day_glucose,

        -- daily change (trend slope)
        avg_glucose - LAG(avg_glucose) OVER (
            PARTITION BY patient_id ORDER BY day
        ) AS daily_change,

        -- rolling average (7-day trend smoothing)
        AVG(avg_glucose) OVER (
            PARTITION BY patient_id
            ORDER BY day
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7day_avg,

        -- volatility (stability measure)
        STDDEV(avg_glucose) OVER (
            PARTITION BY patient_id
            ORDER BY day
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7day_volatility

    FROM daily_avg
)

SELECT *
FROM enriched
ORDER BY patient_id, day;



/* Question 8. What is each patient's 7-day rolling average glucose, and when did they experience their 
-- worst glycemic week?

-- STEP 1: Parse timestamps and extract date
-- STEP 2: Apply 7-day rolling average using window function
-- STEP 3: Rank weeks by worst rolling average per patient
*/

WITH glucose_daily AS (
    SELECT
        patient_id,
        timestamp            AS reading_date,
        ROUND(AVG(glucose_mgdl), 1)   AS daily_avg_glucose
    FROM dexcom_clean
    WHERE glucose_mgdl BETWEEN 40 AND 400
    GROUP BY patient_id, timestamp
),
rolling_avg AS (
    SELECT
        patient_id,
        reading_date,
        daily_avg_glucose,
        ROUND(AVG(daily_avg_glucose) OVER (
            PARTITION BY patient_id
            ORDER BY reading_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 1)                               AS rolling_7day_avg,
        COUNT(*) OVER (
            PARTITION BY patient_id
            ORDER BY reading_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )                                   AS days_in_window
    FROM glucose_daily
),
ranked AS (
    SELECT
        patient_id,
        reading_date,
        daily_avg_glucose,
        rolling_7day_avg,
        days_in_window,
        RANK() OVER (
            PARTITION BY patient_id
            ORDER BY rolling_7day_avg DESC
        )                                   AS worst_week_rank
    FROM rolling_avg
    WHERE days_in_window = 7
)
SELECT
    patient_id,
    reading_date,
    daily_avg_glucose,
    rolling_7day_avg,
    worst_week_rank,
    CASE
        WHEN worst_week_rank = 1 THEN 'Worst Glycemic Week'
        ELSE '-'
    END                                    
FROM ranked
WHERE worst_week_rank = 1
ORDER BY patient_id, reading_date;



/* Question 9. For each patient, how many days elapsed between their first and last recording, 
--and how consistent was their glucose monitoring?

-- STEP 1: Get per-patient recording boundaries using datetime functions
-- STEP 2: Compute study span and adherence metrics
-- STEP 3: Classify adherence using percentage of days monitored
*/

WITH recording_bounds AS (
    SELECT
        patient_id,
        MIN(timestamp)             AS first_recorded,
        MAX(timestamp)             AS last_recorded,
        COUNT(*)                            AS total_readings,
        COUNT(DISTINCT DATE(timestamp)) AS active_days
    FROM dexcom_clean
    WHERE glucose_mgdl BETWEEN 40 AND 400
    GROUP BY patient_id
),
study_span AS (
    SELECT
        patient_id,
        first_recorded,
        last_recorded,
        total_readings,
        active_days,
        AGE(last_recorded, first_recorded)  AS study_duration,
        EXTRACT(DAY FROM
            last_recorded - first_recorded) AS total_days_span,
        ROUND(total_readings * 1.0
            / NULLIF(active_days, 0), 1)    AS readings_per_active_day
    FROM recording_bounds
),
adherence AS (
    SELECT
        patient_id,
        first_recorded,
        last_recorded,
        TO_CHAR(first_recorded, 'Mon DD, YYYY') AS study_start,
        TO_CHAR(last_recorded,  'Mon DD, YYYY') AS study_end,
        study_duration,
        total_days_span,
        active_days,
        total_readings,
        readings_per_active_day,
        ROUND(active_days * 100.0
            / NULLIF(total_days_span, 0), 1) AS pct_days_monitored
    FROM study_span
)

SELECT
    patient_id,
    study_start,
    study_end,
    study_duration,
    total_days_span,
    active_days,
    pct_days_monitored,
    readings_per_active_day,
    CASE
        WHEN pct_days_monitored >= 80 THEN 'High Adherence'
        WHEN pct_days_monitored >= 50 THEN 'Moderate Adherence'
        ELSE                               'Low Adherence'
    END                                     AS adherence_category
FROM adherence
ORDER BY pct_days_monitored DESC;


/* Question 10. Which patients show a significant difference between their morning and evening glucose levels?

-- STEP 1: Tag each glucose reading by time of day
-- STEP 2: Average glucose per patient per period
-- STEP 3: Pivot morning vs evening into one row per patient
-- STEP 4: Compute delta and rank using PERCENT_RANK and CUME_DIST
*/

WITH glucose_tagged AS (
    SELECT
        patient_id,
        glucose_mgdl,
        timestamp AS recorded_at,
        CASE
            WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 5  AND 9  THEN 'Morning'
            WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 18 AND 22 THEN 'Evening'
            ELSE NULL
        END  AS period
    FROM dexcom_clean
    WHERE glucose_mgdl BETWEEN 40 AND 400
),
period_avg AS (
    SELECT
        patient_id,
        period,
        ROUND(AVG(glucose_mgdl), 1)            AS avg_glucose,
        ROUND(STDDEV(glucose_mgdl)::numeric, 1) AS glucose_stddev,
        COUNT(*)                                AS reading_count
    FROM glucose_tagged
    WHERE period IS NOT NULL
    GROUP BY patient_id, period
),
pivoted AS (
    SELECT
        patient_id,
        MAX(CASE WHEN period = 'Morning' THEN avg_glucose  END) AS morning_avg,
        MAX(CASE WHEN period = 'Evening' THEN avg_glucose  END) AS evening_avg,
        MAX(CASE WHEN period = 'Morning' THEN glucose_stddev END) AS morning_stddev,
        MAX(CASE WHEN period = 'Evening' THEN glucose_stddev END) AS evening_stddev,
        MAX(CASE WHEN period = 'Morning' THEN reading_count END) AS morning_readings,
        MAX(CASE WHEN period = 'Evening' THEN reading_count END) AS evening_readings
    FROM period_avg
    GROUP BY patient_id
),
delta_ranked AS (
    SELECT
        patient_id,
        morning_avg,
        evening_avg,
        morning_stddev,
        evening_stddev,
        morning_readings,
        evening_readings,
        ROUND(evening_avg - morning_avg, 1)          AS evening_vs_morning_delta,
        RANK() OVER (
            ORDER BY ABS(evening_avg - morning_avg) DESC
        )                                            AS delta_rank,
        ROUND(PERCENT_RANK() OVER (
            ORDER BY ABS(evening_avg - morning_avg)
        )::numeric * 100, 1)                         AS pct_rank_in_cohort,
        ROUND(CUME_DIST() OVER (
            ORDER BY ABS(evening_avg - morning_avg)
        )::numeric * 100, 1)                         AS cumulative_dist_pct
    FROM pivoted
    WHERE morning_avg IS NOT NULL
      AND evening_avg IS NOT NULL
)
SELECT
    patient_id,
    morning_avg,
    evening_avg,
    evening_vs_morning_delta,
    morning_stddev,
    evening_stddev,
    delta_rank,
    pct_rank_in_cohort                               AS bottom_x_pct_of_cohort,
    cumulative_dist_pct,
    CASE
        WHEN evening_vs_morning_delta >  20 THEN 'Evening Carb Load Pattern'
        WHEN evening_vs_morning_delta < -20 THEN 'Dawn Phenomenon'
        ELSE                                    'Stable Across Day'
    END                                              AS pattern_flag
FROM delta_ranked
ORDER BY delta_rank;


/*Question 11. What is the cumulative calorie intake per patient, and on which date did they 
-- cross the 10,000-calorie milestone?

-- STEP 1: Daily calorie totals per patient
-- STEP 2: Running cumulative sum + capture first and last food of study
-- STEP 3: Flag milestone crossing using LAG
*/

WITH daily_cals AS (
    SELECT
        patient_id,
        timestamp AS log_date,
        SUM(calories) AS daily_calories,
        STRING_AGG(
            UPPER(SUBSTR(logged_food, 1, 1))
            || LOWER(SUBSTR(logged_food, 2)),
            ', '
        )  AS foods_eaten
    FROM foodlog_clean
    WHERE calories > 0
    GROUP BY patient_id, timestamp
),
cumulative AS (
    SELECT
        patient_id,
        log_date,
        daily_calories,
        foods_eaten,
        SUM(daily_calories) OVER (
            PARTITION BY patient_id
            ORDER BY log_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                            AS cumulative_calories,
        ROW_NUMBER() OVER (
            PARTITION BY patient_id
            ORDER BY log_date
        )                                            AS day_number,
        FIRST_VALUE(log_date) OVER (
            PARTITION BY patient_id
            ORDER BY log_date
        )                                            AS study_start_date,
        LAST_VALUE(log_date) OVER (
            PARTITION BY patient_id
            ORDER BY log_date
            ROWS BETWEEN UNBOUNDED PRECEDING
                     AND UNBOUNDED FOLLOWING
        )                                            AS study_end_date
    FROM daily_cals
),
milestone AS (
    SELECT
        patient_id,
        log_date,
        daily_calories,
        foods_eaten,
        cumulative_calories,
        day_number,
        study_start_date,
        study_end_date,
        LAG(cumulative_calories) OVER (
            PARTITION BY patient_id
            ORDER BY log_date
        )   AS prev_cumulative,
        CASE
            WHEN cumulative_calories >= 10000
             AND LAG(cumulative_calories) OVER (
                    PARTITION BY patient_id
                    ORDER BY log_date
                 ) < 10000
            THEN 'Milestone Crossed'
            ELSE '-'
        END   AS milestone_flag
    FROM cumulative
)
SELECT
    patient_id,
    TO_CHAR(log_date, 'Mon DD, YYYY')                AS log_date,
    TO_CHAR(study_start_date, 'Mon DD, YYYY')        AS study_start,
    TO_CHAR(study_end_date,   'Mon DD, YYYY')        AS study_end,
    day_number,
    daily_calories,
    cumulative_calories,
    foods_eaten,
    milestone_flag
FROM milestone
WHERE milestone_flag = 'Milestone Crossed'
   OR cumulative_calories <= 10000
ORDER BY patient_id, log_date;


/*Question 12: Which patients have the highest average glucose, ranked across the cohort?*/
--Step1: Filtered glucose readings to physiologically valid range (40-400 mg/dL).
--Step2: Aggregated average glucose per patient.
--Step3: Ranked patients using RANK() over average glucose descending.

SELECT
    patient_id,
    ROUND(AVG(glucose_mgdl), 1)        AS avg_glucose,
    RANK() OVER (
        ORDER BY AVG(glucose_mgdl) DESC
    )                                         AS glucose_rank
FROM dexcom_clean
WHERE glucose_mgdl BETWEEN 40 AND 400
GROUP BY patient_id;


/*Question 13: For each heart rate reading, what is the next recorded value and is the trend rising or falling?*/
--Step1: Filtered heart rate readings to physiologically valid range (30-220 bpm).
--Step2: Used LEAD() to retrieve the next chronological heart rate reading per patient.
--Step3: Classified the trend between current and next reading as Rising, Falling, or Stable.

SELECT
    patient_id,
    timestamp,
    hr_bpm,
    LEAD(hr_bpm) OVER (
        PARTITION BY patient_id
        ORDER BY timestamp
    )       AS next_hr,
    CASE
        WHEN LEAD(hr_bpm) OVER (
            PARTITION BY patient_id
            ORDER BY timestamp
        ) > hr_bpm THEN 'Rising'
        WHEN LEAD(hr_bpm) OVER (
            PARTITION BY patient_id
            ORDER BY timestamp
        ) < hr_bpm THEN 'Falling'
        ELSE 'Stable'
    END    AS hr_trend
FROM hr_clean
WHERE hr_bpm BETWEEN 30 AND 220;


/*Question 14: Where does each patient's peak glucose reading fall as a percentile within the cohort?*/
--Step1: Filtered glucose readings to physiologically valid range (40-400 mg/dL).
--Step2: Calculated each patient's maximum glucose reading.
--Step3: Used PERCENT_RANK() to determine where each patient's peak falls relative to the cohort.
 

SELECT
    patient_id,
    MAX(glucose_mgdl)                  AS peak_glucose,
    ROUND(PERCENT_RANK() OVER (
        ORDER BY MAX(glucose_mgdl)
    )::numeric * 100, 1)                      AS percentile_in_cohort
FROM dexcom_clean
WHERE glucose_mgdl BETWEEN 40 AND 400
GROUP BY patient_id;

/*Question 15: What is the difference between each glucose reading and the previous reading per patient?*/
--Step1: Used LAG() to retrieve the previous glucose reading per patient in chronological order.
--Step2: Calculated the difference between current and previous reading.
--Step3: Classified each change into Rapid Rise, Rapid Drop, First Reading, or Stable.
 
SELECT
    patient_id,
    timestamp,
    glucose_mgdl AS current_glucose,
    LAG(glucose_mgdl) OVER (
        PARTITION BY patient_id
        ORDER BY timestamp
    ) AS previous_glucose
FROM dexcom_clean
ORDER BY patient_id, timestamp;
 
---------------------optimized query--------------------------
/*
Optimization: CTE separates LAG calculation from CASE logic
              making the query easier to read and maintain.
              CASE classifies each reading as Rapid Rise, Rapid Drop
              or Stable giving clinical meaning to raw numbers.
              NULL check handles first reading per patient where
              no previous value exists.
*/
WITH glucose_changes AS (
    SELECT
        patient_id,
        timestamp,
        glucose_mgdl AS current_glucose,
        LAG(glucose_mgdl) OVER (
            PARTITION BY patient_id
            ORDER BY timestamp
        ) AS previous_glucose,
        glucose_mgdl - LAG(glucose_mgdl) OVER (
            PARTITION BY patient_id
            ORDER BY timestamp
        ) AS glucose_change
    FROM dexcom_clean
)
SELECT
    patient_id,
    timestamp,
    current_glucose,
    previous_glucose,
    ROUND(glucose_change, 1) AS glucose_change_mgdl,
    CASE
        WHEN glucose_change > 20  THEN 'Rapid Rise'
        WHEN glucose_change < -20 THEN 'Rapid Drop'
        WHEN glucose_change IS NULL THEN 'First Reading'
        ELSE 'Stable'
    END AS glucose_trend
FROM glucose_changes
ORDER BY glucose_trend, patient_id, timestamp;
 
/*
Conclusion: 36,846 Stable readings, 20 Rapid Rise events and
            16 Rapid Drop events found. Patients with frequent
            Rapid Rise or Rapid Drop events have unstable glucose
            regulation and need closer dietary monitoring.
*/
 
 
/*Question 16: Which patients have the highest glucose variability based on coefficient of variation?*/
--Step1: Calculated average and standard deviation of glucose per patient.
--Step2: Computed coefficient of variation (STDDEV / AVG * 100) to normalize variability across different baselines.
--Step3: Classified each patient's variability level using CASE.
 
SELECT
    patient_id,
    COUNT(*) AS total_readings,
    ROUND(AVG(glucose_mgdl), 2) AS avg_glucose,
    ROUND(STDDEV(glucose_mgdl), 2) AS stddev_glucose,
    ROUND(
        STDDEV(glucose_mgdl) / NULLIF(AVG(glucose_mgdl), 0) * 100
    , 2) AS coefficient_of_variation_pct,
    CASE
        WHEN STDDEV(glucose_mgdl) / NULLIF(AVG(glucose_mgdl), 0) * 100 > 20 THEN 'High Variability'
        WHEN STDDEV(glucose_mgdl) / NULLIF(AVG(glucose_mgdl), 0) * 100 > 10 THEN 'Moderate Variability'
        ELSE 'Low Variability'
    END AS variability_category
FROM dexcom_clean
GROUP BY patient_id
ORDER BY coefficient_of_variation_pct DESC;
 
/*
Conclusion: Patient 10 has highest variability (25.74%) and
            patient 15 has lowest (13.65%). All patients show
            moderate to high variability confirming unstable
            glucose regulation across the prediabetic population.
*/
 
 
/*Question 17: What is the longest gap between consecutive glucose readings per patient?*/
--Step1: Used LEAD() to find the next chronological reading per patient.
--Step2: Calculated gap in minutes between consecutive readings.
--Step3: Aggregated longest gap, average gap, and counted gaps above clinical thresholds (10 min, 1 hour, 3 hours).
 
SELECT
    patient_id,
    timestamp AS current_reading,
    LEAD(timestamp) OVER (
        PARTITION BY patient_id
        ORDER BY timestamp
    ) AS next_reading,
    EXTRACT(EPOCH FROM (
        LEAD(timestamp) OVER (PARTITION BY patient_id ORDER BY timestamp) - timestamp
    )) / 60 AS gap_minutes
FROM dexcom_clean
ORDER BY patient_id, current_reading;
 
---------------------optimized query--------------------------
/*
Optimization: CTE calculates gaps once then aggregates in outer query
              avoiding recalculation of LEAD() expression.
              FILTER clause counts gaps above multiple thresholds
              in a single pass -- more efficient than multiple subqueries.
              WHERE gap_minutes IS NOT NULL excludes last reading
              per patient which has no next reading.
*/
WITH glucose_gaps AS (
    SELECT
        patient_id,
        timestamp AS current_reading,
        LEAD(timestamp) OVER (
            PARTITION BY patient_id
            ORDER BY timestamp
        ) AS next_reading,
        EXTRACT(EPOCH FROM (
            LEAD(timestamp) OVER (PARTITION BY patient_id ORDER BY timestamp) - timestamp
        )) / 60 AS gap_minutes
    FROM dexcom_clean
)
SELECT
    patient_id,
    ROUND(MAX(gap_minutes)::numeric, 1) AS longest_gap_minutes,
    ROUND(AVG(gap_minutes)::numeric, 1) AS avg_gap_minutes,
    COUNT(*) FILTER (WHERE gap_minutes > 10)  AS gaps_over_10_min,
    COUNT(*) FILTER (WHERE gap_minutes > 60)  AS gaps_over_1_hour,
    COUNT(*) FILTER (WHERE gap_minutes > 180) AS gaps_over_3_hours
FROM glucose_gaps
WHERE gap_minutes IS NOT NULL
GROUP BY patient_id
ORDER BY longest_gap_minutes DESC;
 
/*
Conclusion: Patient 15 has the longest gap of 1,315 minutes
            (almost 22 hours) indicating a major data collection
            gap. Patient 2 has an 845 minute gap. Most patients
            maintain the expected 5 minute average interval.
            Analyses for patients 15 and 2 should be interpreted
            with caution due to missing data periods.
*/
 
 
/*Question 18: What is the percentage of time each patient spends above 180 mg/dL?*/
--Step1: Counted total readings and readings above 180 mg/dL per patient using FILTER.
--Step2: Calculated percentage of time above range, both per patient and as a share of the total population.
--Step3: Classified each patient's hyperglycemia burden using CASE.
 
SELECT
    patient_id,
    COUNT(*) AS total_readings,
    COUNT(*) FILTER (WHERE glucose_mgdl > 180) AS readings_above_180
FROM dexcom_clean
GROUP BY patient_id
ORDER BY readings_above_180 DESC;
 
---------------------optimized query--------------------------
/*
Optimization: FILTER clause counts above 180 readings in single pass
              avoiding a subquery or CASE plus SUM pattern.
              SUM() OVER() calculates population percentage without
              a second table scan.
              CASE classifies hyperglycemia burden for clinical interpretation.
*/
SELECT
    patient_id,
    COUNT(*) AS total_readings,
    COUNT(*) FILTER (WHERE glucose_mgdl > 180) AS readings_above_180,
    ROUND(
        COUNT(*) FILTER (WHERE glucose_mgdl > 180) * 100.0 / COUNT(*)
    , 2) AS pct_time_above_180,
    ROUND(
        COUNT(*) FILTER (WHERE glucose_mgdl > 180) * 100.0 / SUM(COUNT(*)) OVER()
    , 2) AS pct_of_total_population,
    CASE
        WHEN COUNT(*) FILTER (WHERE glucose_mgdl > 180) * 100.0 / COUNT(*) > 5 THEN 'High Hyperglycemia Burden'
        WHEN COUNT(*) FILTER (WHERE glucose_mgdl > 180) * 100.0 / COUNT(*) > 1 THEN 'Moderate Hyperglycemia Burden'
        ELSE 'Low Hyperglycemia Burden'
    END AS hyperglycemia_burden
FROM dexcom_clean
GROUP BY patient_id
ORDER BY pct_time_above_180 DESC;
 
/*
Conclusion: Patient 6 spends 7.31% of time above 180 mg/dL
            showing the highest hyperglycemia burden.
            4 patients have 0% time above 180 showing good
            glucose control. 12 out of 16 patients have some
            degree of hyperglycemia during the study period.
*/
 
 
/*Question 19: What is the average IBI vs actual heart rate comparison per patient?*/
--Step1: Pre-aggregated IBI readings per patient and derived estimated heart rate from average IBI.
--Step2: Pre-aggregated actual heart rate per patient.
--Step3: Joined both pre-aggregated sets and classified sensor agreement based on the difference.
 
SELECT
    i.patient_id,
    dc.gender,
    dc.hba1c,
    i.total_ibi_readings,
    i.avg_ibi_seconds,
    i.estimated_hr_from_ibi,
    h.actual_avg_hr,
    ROUND(ABS(i.estimated_hr_from_ibi - h.actual_avg_hr), 1) AS hr_difference,
    CASE
        WHEN ABS(i.estimated_hr_from_ibi - h.actual_avg_hr) > 20 THEN 'Large Discrepancy'
        WHEN ABS(i.estimated_hr_from_ibi - h.actual_avg_hr) > 10 THEN 'Moderate Discrepancy'
        ELSE 'Good Agreement'
    END AS sensor_agreement
FROM (
    SELECT
        patient_id,
        COUNT(ibi_seconds) AS total_ibi_readings,
        ROUND(AVG(ibi_seconds)::numeric, 4) AS avg_ibi_seconds,
        ROUND(60.0 / AVG(ibi_seconds), 1) AS estimated_hr_from_ibi
    FROM ibi_clean
    GROUP BY patient_id
) i
JOIN (
    SELECT
        patient_id,
        ROUND(AVG(hr_bpm), 1) AS actual_avg_hr
    FROM hr_clean
    GROUP BY patient_id
) h ON i.patient_id = h.patient_id
JOIN demography_clean dc ON i.patient_id = dc.patient_id
ORDER BY hr_difference DESC;
 
/*
Conclusion: Patient 13 shows the largest discrepancy (22.4 bpm)
            between estimated and actual HR suggesting possible
            sensor calibration issues. Most patients show moderate
            discrepancy which is expected as IBI and HR are
            recorded at different frequencies and time points.
*/
 
 
/*Question 20: What is the rolling 7 day average glucose per patient?*/
--Step1: Calculated daily average glucose per patient.
--Step2: Computed a rolling 7-day average using a window frame (6 PRECEDING to CURRENT ROW).
--Step3: Compared rolling average against each patient's overall study average.
 
WITH daily_glucose AS (
    SELECT
        patient_id,
        DATE_TRUNC('day', timestamp) AS glucose_date,
        ROUND(AVG(glucose_mgdl), 2) AS daily_avg_glucose
    FROM dexcom_clean
    GROUP BY patient_id, DATE_TRUNC('day', timestamp)
)
SELECT
    patient_id,
    glucose_date,
    daily_avg_glucose,
    ROUND(AVG(daily_avg_glucose) OVER (
        PARTITION BY patient_id
        ORDER BY glucose_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7day_avg,
    ROUND(AVG(daily_avg_glucose) OVER (
        PARTITION BY patient_id
    ), 2) AS overall_avg
FROM daily_glucose
ORDER BY patient_id, glucose_date;
 
/*
Conclusion: 150 daily rows across 16 patients. Rolling 7 day
            average smooths daily noise revealing genuine glucose
            trends. Patients where rolling average consistently
            exceeds overall average are experiencing worsening
            glucose control over the study period.
*/
 
 
/*Question 21: What is the rank of each patient by average glucose?*/
--Step1: Calculated average glucose per patient via JOIN to demography for gender and HbA1c context.
--Step2: Ranked patients using both RANK() and DENSE_RANK() to demonstrate tie-handling differences.
--Step3: Classified top 5 as High Risk, next 5 as Moderate Risk, remainder as Low Risk.
 
SELECT
    d.patient_id,
    dc.gender,
    dc.hba1c,
    ROUND(AVG(d.glucose_mgdl), 2) AS avg_glucose,
    RANK() OVER (
        ORDER BY AVG(d.glucose_mgdl) DESC
    ) AS glucose_rank,
    DENSE_RANK() OVER (
        ORDER BY AVG(d.glucose_mgdl) DESC
    ) AS dense_rank,
    CASE
        WHEN RANK() OVER (ORDER BY AVG(d.glucose_mgdl) DESC) <= 5  THEN 'High Risk'
        WHEN RANK() OVER (ORDER BY AVG(d.glucose_mgdl) DESC) <= 10 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS risk_category
FROM dexcom_clean d
JOIN demography_clean dc ON d.patient_id = dc.patient_id
GROUP BY d.patient_id, dc.gender, dc.hba1c
ORDER BY glucose_rank;
 
/*
Conclusion: Patient 2 ranks 1st with highest avg glucose (130.43).
            Patient 7 ranks last with lowest avg glucose (93.07).
            Top 5 high risk patients are patients 2, 9, 13, 6 and 12.
            These patients need the most urgent dietary intervention.
*/
 
 
/*Question 22: What is the rolling 5-minute average heart rate?*/
--Step1: Filtered heart rate readings to remove anomalies and physiologically invalid values (40-200 bpm).
--Step2: Computed a 5-reading rolling average using a physical row window frame.
--Step3: Computed a wider 60-reading rolling average for additional trend smoothing.
 
WITH clean_hc AS (
    SELECT hc.patient_id, hc.timestamp, hc.hr_bpm
    FROM hr_clean hc
    WHERE hc.hr_anomaly = FALSE
      AND hc.hr_bpm BETWEEN 40 AND 200
)
SELECT
    hc.patient_id,
    hc.timestamp,
    hc.hr_bpm AS raw_hr_bpm,
    ROUND(
        AVG(hc.hr_bpm) OVER (
            PARTITION BY hc.patient_id
            ORDER BY hc.timestamp
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        )::NUMERIC, 1
    ) AS rolling_5s_avg_hr,
    ROUND(
        AVG(hc.hr_bpm) OVER (
            PARTITION BY hc.patient_id
            ORDER BY hc.timestamp
            ROWS BETWEEN 59 PRECEDING AND CURRENT ROW
        )::NUMERIC, 1
    ) AS rolling_60s_avg_hr
FROM clean_hc hc
ORDER BY hc.patient_id, hc.timestamp;
 
 
/*Question 23: What is the hourly average glucose?*/
--Step1: Bucketed glucose readings into hourly intervals using DATE_TRUNC.
--Step2: Filtered to EGV readings with non-null glucose values.
--Step3: Calculated average, min, max, and standard deviation of glucose per hourly bucket.
 
SELECT
    dc.patient_id,
    DATE_TRUNC('hour', dc.timestamp) AS hour_bucket,
    TO_CHAR(DATE_TRUNC('hour', dc.timestamp), 'HH12:MI AM') AS hour_label,
    COUNT(*) AS readings_in_hour,
    ROUND(AVG(dc.glucose_mgdl)::NUMERIC, 1) AS avg_glucose,
    ROUND(MIN(dc.glucose_mgdl)::NUMERIC, 1) AS min_glucose,
    ROUND(MAX(dc.glucose_mgdl)::NUMERIC, 1) AS max_glucose,
    ROUND(STDDEV(dc.glucose_mgdl)::NUMERIC, 2) AS glucose_std_dev
FROM dexcom_clean dc
WHERE UPPER(TRIM(dc.event_type)) = 'EGV'
  AND dc.glucose_mgdl IS NOT NULL
GROUP BY dc.patient_id, DATE_TRUNC('hour', dc.timestamp)
ORDER BY dc.patient_id, hour_bucket;
 
 
/*Question 24: What is the difference between consecutive glucose readings?*/
--Step1: Used LAG() to retrieve the previous glucose reading and its timestamp per patient.
--Step2: Calculated the glucose delta between consecutive EGV readings.
--Step3: Classified each delta into Rapid Rise, Rapid Fall, Stable, or Moderate Change.
 
WITH lagged_dc AS (
    SELECT
        dc.patient_id,
        dc.timestamp,
        dc.glucose_mgdl,
        LAG(dc.glucose_mgdl) OVER (
            PARTITION BY dc.patient_id
            ORDER BY dc.timestamp
        ) AS prev_glucose,
        LAG(dc.timestamp) OVER (
            PARTITION BY dc.patient_id
            ORDER BY dc.timestamp
        ) AS prev_timestamp
    FROM dexcom_clean dc
    WHERE UPPER(TRIM(dc.event_type)) = 'EGV'
      AND dc.glucose_mgdl IS NOT NULL
)
SELECT
    lagged_dc.patient_id,
    lagged_dc.timestamp,
    lagged_dc.prev_timestamp,
    lagged_dc.prev_glucose,
    lagged_dc.glucose_mgdl AS current_glucose,
    lagged_dc.glucose_mgdl - lagged_dc.prev_glucose AS glucose_delta,
    CASE
        WHEN lagged_dc.glucose_mgdl - lagged_dc.prev_glucose >  30 THEN 'Rapid Rise'
        WHEN lagged_dc.glucose_mgdl - lagged_dc.prev_glucose < -30 THEN 'Rapid Fall'
        WHEN ABS(lagged_dc.glucose_mgdl - lagged_dc.prev_glucose) <= 10 THEN 'Stable'
        ELSE 'Moderate Change'
    END AS change_category
FROM lagged_dc
WHERE lagged_dc.prev_glucose IS NOT NULL
ORDER BY lagged_dc.patient_id, lagged_dc.timestamp;
 
 
/*Question 25: What is the cumulative meal count per participant?*/
--Step1: Filtered foodlog_clean to records with valid timestamps.
--Step2: Computed a running cumulative meal count per patient using an unbounded window frame.
--Step3: Computed a per-day meal count nested within the same patient partition.
 
SELECT
    fc.patient_id,
    fc.timestamp AS meal_time,
    fc.logged_food,
    fc.calories,
    fc.carbs_g,
    COUNT(*) OVER (
        PARTITION BY fc.patient_id
        ORDER BY fc.timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_meal_count,
    COUNT(*) OVER (
        PARTITION BY fc.patient_id, DATE_TRUNC('day', fc.timestamp)
        ORDER BY fc.timestamp
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS meal_number_today
FROM foodlog_clean fc
WHERE fc.timestamp IS NOT NULL
ORDER BY fc.patient_id, fc.timestamp;
 
 
/*Question 26: What is the rolling standard deviation of IBI?*/
--Step1: Computed rolling standard deviation and rolling average of IBI using a 12-reading window frame.
--Step2: Captured window size per row to filter out incomplete windows at the start of each patient's data.
--Step3: Classified rolling variability into High, Moderate, or Low HRV tiers.
 
WITH ibi_rolling AS (
    SELECT
        ic.patient_id,
        ic.timestamp,
        ic.ibi_seconds,
        ROUND(
            STDDEV(ic.ibi_seconds) OVER (
                PARTITION BY ic.patient_id
                ORDER BY ic.timestamp
                ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
            )::NUMERIC, 5
        ) AS rolling_ibi_sd,
        ROUND(
            AVG(ic.ibi_seconds) OVER (
                PARTITION BY ic.patient_id
                ORDER BY ic.timestamp
                ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
            )::NUMERIC, 4
        ) AS rolling_avg_ibi,
        COUNT(*) OVER (
            PARTITION BY ic.patient_id
            ORDER BY ic.timestamp
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS window_size
    FROM ibi_clean ic
)
SELECT
    ibi_rolling.patient_id,
    ibi_rolling.timestamp,
    ibi_rolling.ibi_seconds,
    ibi_rolling.rolling_avg_ibi,
    ibi_rolling.rolling_ibi_sd,
    CASE
        WHEN ibi_rolling.rolling_ibi_sd > 0.08 THEN 'High HRV'
        WHEN ibi_rolling.rolling_ibi_sd > 0.04 THEN 'Moderate HRV'
        ELSE 'Low HRV'
    END AS hrv_tier
FROM ibi_rolling
WHERE ibi_rolling.window_size = 12
ORDER BY ibi_rolling.patient_id, ibi_rolling.timestamp;
 
 
/*Question 27: What is the average EDA per hour?*/
--Step1: Bucketed EDA readings into hourly intervals per patient per study day using EXTRACT(HOUR) and DATE_TRUNC.
--Step2: Calculated average and peak EDA value per hourly bucket.
--Step3: Counted EDA spike events per bucket using FILTER.
 
SELECT
    ec.patient_id,
    DATE_TRUNC('day', ec.timestamp)::DATE AS study_date,
    EXTRACT(HOUR FROM ec.timestamp)::INT AS hour_of_day,
    TO_CHAR(
        MAKE_TIME(EXTRACT(HOUR FROM ec.timestamp)::INT, 0, 0),
        'HH12:MI AM'
    ) AS hour_label,
    COUNT(*) AS readings_in_hour,
    ROUND(AVG(ec.eda_value)::NUMERIC, 5) AS avg_eda,
    ROUND(MAX(ec.eda_value)::NUMERIC, 5) AS peak_eda,
    COUNT(*) FILTER (WHERE ec.eda_spike = TRUE) AS spike_count
FROM eda_clean ec
GROUP BY
    ec.patient_id,
    DATE_TRUNC('day', ec.timestamp)::DATE,
    EXTRACT(HOUR FROM ec.timestamp)::INT
ORDER BY ec.patient_id, study_date, hour_of_day;
 
 
/*Question 28: What is the average temperature per hour?*/
--Step1: Filtered out flagged temperature anomalies before aggregation.
--Step2: Bucketed temperature readings into hourly intervals using DATE_TRUNC.
--Step3: Calculated average, min, max, and standard deviation of temperature per hourly bucket.
 
SELECT
    tc.patient_id,
    DATE_TRUNC('hour', tc.timestamp) AS hour_bucket,
    TO_CHAR(DATE_TRUNC('hour', tc.timestamp), 'Day HH12:MI AM') AS hour_label,
    COUNT(*) AS readings_in_hour,
    ROUND(AVG(tc.temperature_c)::NUMERIC, 2) AS avg_temp_c,
    ROUND(MIN(tc.temperature_c)::NUMERIC, 2) AS min_temp_c,
    ROUND(MAX(tc.temperature_c)::NUMERIC, 2) AS max_temp_c,
    ROUND(STDDEV(tc.temperature_c)::NUMERIC, 3) AS temp_std_dev
FROM temperature_clean tc
WHERE tc.temp_anomaly = FALSE
GROUP BY tc.patient_id, DATE_TRUNC('hour', tc.timestamp)
ORDER BY tc.patient_id, hour_bucket;
 
 
/*Question 29: Align glucose and heart rate by minute.*/
--Step1: Pre-aggregated glucose readings into 5-minute bins per patient (dc_5min CTE).
--Step2: Pre-aggregated heart rate readings into matching 5-minute bins per patient (hc_5min CTE).
--Step3: LEFT JOIN both binned signals on patient_id and time_bin, then classified each bin's combined physiological state.
 
WITH dc_5min AS (
    SELECT
        dc.patient_id,
        DATE_TRUNC('minute', dc.timestamp)
            - ((EXTRACT(MINUTE FROM dc.timestamp)::INT % 5))::INT * INTERVAL '1 minute' AS time_bin,
        ROUND(AVG(dc.glucose_mgdl)::NUMERIC, 1) AS avg_glucose
    FROM dexcom_clean dc
    WHERE UPPER(TRIM(dc.event_type)) = 'EGV'
      AND dc.glucose_mgdl IS NOT NULL
    GROUP BY
        dc.patient_id,
        DATE_TRUNC('minute', dc.timestamp)
            - ((EXTRACT(MINUTE FROM dc.timestamp)::INT % 5))::INT * INTERVAL '1 minute'
),
hc_5min AS (
    SELECT
        hc.patient_id,
        DATE_TRUNC('minute', hc.timestamp)
            - ((EXTRACT(MINUTE FROM hc.timestamp)::INT % 5))::INT * INTERVAL '1 minute' AS time_bin,
        ROUND(AVG(hc.hr_bpm)::NUMERIC, 1) AS avg_hr
    FROM hr_clean hc
    WHERE hc.hr_anomaly = FALSE
    GROUP BY
        hc.patient_id,
        DATE_TRUNC('minute', hc.timestamp)
            - ((EXTRACT(MINUTE FROM hc.timestamp)::INT % 5))::INT * INTERVAL '1 minute'
)
SELECT
    dc_5min.patient_id,
    dc_5min.time_bin,
    dc_5min.avg_glucose,
    hc_5min.avg_hr,
    CASE
        WHEN dc_5min.avg_glucose > 140 AND hc_5min.avg_hr > 90 THEN 'High Glucose + High HR'
        WHEN dc_5min.avg_glucose > 140 THEN 'High Glucose Only'
        WHEN hc_5min.avg_hr > 90       THEN 'High HR Only'
        ELSE 'Normal'
    END AS combined_state
FROM dc_5min
LEFT JOIN hc_5min USING (patient_id, time_bin)
ORDER BY dc_5min.patient_id, dc_5min.time_bin;


/*Question 30: Identify patients who show simultaneous high glucose, high heart rate, and high stress (EDA)?*/
--Step1: Aggregated glucose, heart rate, and EDA readings into matching 30-minute time bins per patient.
--Step2: Calculated cohort-wide 75th percentile thresholds for glucose, heart rate, and EDA using PERCENTILE_CONT.
--Step3: Joined all three binned signals together and flagged bins where all three values exceed their respective P75 threshold.
--Step4: Counted how many triple-high events each patient experienced.

WITH dc_30min AS (
    SELECT
        patient_id,
        DATE_TRUNC('hour', timestamp)
            + (FLOOR(EXTRACT(MINUTE FROM timestamp) / 30) * INTERVAL '30 minutes') AS time_bin,
        ROUND(AVG(glucose_mgdl)::NUMERIC, 1) AS avg_glucose
    FROM dexcom_clean
    WHERE UPPER(TRIM(event_type)) = 'EGV'
    GROUP BY
        patient_id,
        DATE_TRUNC('hour', timestamp)
            + (FLOOR(EXTRACT(MINUTE FROM timestamp) / 30) * INTERVAL '30 minutes')
),
hc_30min AS (
    SELECT
        patient_id,
        DATE_TRUNC('hour', timestamp)
            + (FLOOR(EXTRACT(MINUTE FROM timestamp) / 30) * INTERVAL '30 minutes') AS time_bin,
        ROUND(AVG(hr_bpm)::NUMERIC, 1) AS avg_hr
    FROM hr_clean
    WHERE hr_anomaly = FALSE
    GROUP BY
        patient_id,
        DATE_TRUNC('hour', timestamp)
            + (FLOOR(EXTRACT(MINUTE FROM timestamp) / 30) * INTERVAL '30 minutes')
),
ec_30min AS (
    SELECT
        patient_id,
        DATE_TRUNC('hour', timestamp)
            + (FLOOR(EXTRACT(MINUTE FROM timestamp) / 30) * INTERVAL '30 minutes') AS time_bin,
        ROUND(AVG(eda_value)::NUMERIC, 4) AS avg_eda
    FROM eda_clean
    GROUP BY
        patient_id,
        DATE_TRUNC('hour', timestamp)
            + (FLOOR(EXTRACT(MINUTE FROM timestamp) / 30) * INTERVAL '30 minutes')
),
thresholds AS (
    SELECT
        (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_glucose) FROM dc_30min) AS glucose_p75,
        (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_hr)      FROM hc_30min) AS hr_p75,
        (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_eda)     FROM ec_30min) AS eda_p75
),
combined AS (
    SELECT
        dc.patient_id,
        dc.time_bin,
        dc.avg_glucose,
        hc.avg_hr,
        ec.avg_eda
    FROM dc_30min dc
    JOIN hc_30min hc ON dc.patient_id = hc.patient_id AND dc.time_bin = hc.time_bin
    JOIN ec_30min ec ON dc.patient_id = ec.patient_id AND dc.time_bin = ec.time_bin
)
SELECT
    combined.patient_id,
    COUNT(*) AS triple_high_events,
    ROUND(AVG(combined.avg_glucose), 1) AS avg_glucose_in_events,
    ROUND(AVG(combined.avg_hr), 1) AS avg_hr_in_events,
    ROUND(AVG(combined.avg_eda), 4) AS avg_eda_in_events
FROM combined
CROSS JOIN thresholds t
WHERE combined.avg_glucose > t.glucose_p75
  AND combined.avg_hr > t.hr_p75
  AND combined.avg_eda > t.eda_p75
GROUP BY combined.patient_id
ORDER BY triple_high_events DESC;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------