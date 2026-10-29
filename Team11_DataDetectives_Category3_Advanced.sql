------------------------------------------------------------------------------------
----------------------------------CATEGORY 3----------------------------------------
------------------------------------------------------------------------------------
/*Question 1:Create a user-defined function to calculate the Time-in-Range (TIR) percentage 
for each patient based on continuous glucose monitoring (CGM) data*/
--step1:Receive patient ID.
--step2:Count glucose readings within 70–180 mg/dL.
--step3:Calculate Time-in-Range percentage.
--step4:Return the TIR value.

CREATE OR REPLACE FUNCTION calculate_tir(p_patient_id INT)
RETURNS NUMERIC AS
$$
DECLARE
    tir_percent NUMERIC;
BEGIN
    SELECT
        ROUND(
            COUNT(*) FILTER (WHERE glucose_mgdl BETWEEN 70 AND 180) * 100.0
            / COUNT(*),
            2
        )
    INTO tir_percent
    FROM dexcom_clean
    WHERE patient_id = p_patient_id;

    RETURN tir_percent;
END;
$$
LANGUAGE plpgsql;

--FUNCTION EXECUTION:

ALL PATIENTS:

SELECT
    patient_id,
    calculate_tir(patient_id) AS tir_percentage
FROM demography_clean
ORDER BY patient_id;


/*Question 2:Create a stored procedure to generate a patient glucose summary report,
including minimum glucose, maximum glucose, average glucose, and Time-in-Range (TIR) percentage*/

--step1: Accept patient ID.
--step2: Calculate minimum, maximum, average glucose, TIR, and glucose variability.
--step3: Store values in variables.
--step4: Display the summary using RAISE NOTICE.

------------------------CREATE PROCEDURE—----------------

CREATE OR REPLACE PROCEDURE generate_glucose_summary(p_patient_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_min_glucose NUMERIC;
    v_max_glucose NUMERIC;
    v_avg_glucose NUMERIC;
    v_tir NUMERIC;
    v_std_glucose NUMERIC;
BEGIN

    SELECT
        MIN(glucose_mgdl),
        MAX(glucose_mgdl),
        ROUND(AVG(glucose_mgdl),2),
        ROUND(
            COUNT(*) FILTER (WHERE glucose_mgdl BETWEEN 70 AND 180)
            *100.0/NULLIF(COUNT(*),0),2),
        ROUND(STDDEV(glucose_mgdl),2)
    INTO
        v_min_glucose,
        v_max_glucose,
        v_avg_glucose,
        v_tir,
        v_std_glucose
    FROM dexcom_clean
    WHERE patient_id = p_patient_id;

    RAISE NOTICE 'Patient ID          : %', p_patient_id;
    RAISE NOTICE 'Minimum Glucose     : % mg/dL', v_min_glucose;
    RAISE NOTICE 'Maximum Glucose     : % mg/dL', v_max_glucose;
    RAISE NOTICE 'Average Glucose     : % mg/dL', v_avg_glucose;
    RAISE NOTICE 'Time In Range (TIR) : % %%', v_tir;
    RAISE NOTICE 'Std Dev Glucose     : % mg/dL', v_std_glucose;

END;
$$;
-----------------------------CALL FUNCTION-----------------------------
CALL generate_glucose_summary(10);

----------------------------DROP FUNCTION-------------------------------
DROP PROCEDURE IF EXISTS generate_glucose_summary(p_patient_id INT);

/*Question 3:Create a trigger to automatically classify newly inserted glucose readings
into glucose categories (Hypoglycemia, Normal, or Hyperglycemia)*/

--step1: Trigger activates before a new glucose record is inserted.
--step2: Compare glucose value with clinical thresholds.
--step3: Assign glucose category automatically.
--step4: Insert the classified record into the table
--
----------------ADDING NEW COLUMN CATEGORY----------

ALTER TABLE dexcom_clean
ADD COLUMN glucose_category VARCHAR(20);

----------CREATE TRIGGER FUNCTION-------------------

CREATE OR REPLACE FUNCTION classify_glucose()
RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.glucose_mgdl < 70 THEN
        NEW.glucose_category := 'Hypoglycemia';

    ELSIF NEW.glucose_mgdl <= 180 THEN
        NEW.glucose_category := 'Normal';

    ELSE
        NEW.glucose_category := 'Hyperglycemia';
    END IF;

    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

------------CREATE TRIGGER --------------------------------

CREATE TRIGGER trg_classify_glucose
BEFORE INSERT ON dexcom_clean
FOR EACH ROW
EXECUTE FUNCTION classify_glucose();



----------INSERTING NEW VALUE------------------------------

INSERT INTO dexcom_clean (patient_id, timestamp, glucose_mgdl)
VALUES (1, '2020-02-23 10:00:00', 220);


--------VERIFY-----------------------------------
SELECT patient_id,
       timestamp,
       glucose_mgdl,
       glucose_category
FROM dexcom_clean
WHERE patient_id = 1
ORDER BY timestamp DESC
LIMIT 1;

--------REMOVE THE TESTED RECORD------------
DELETE FROM dexcom_clean
WHERE patient_id = 1
  AND timestamp = '2020-02-23 10:00:00';
-------DROP TRIGGER---------------------------
DROP TRIGGER IF EXISTS trg_classify_glucose
ON dexcom_clean;
---------------DROP TRIGGER FUNCTION-----------

DROP FUNCTION IF EXISTS classify_glucose();

-------DROP ADD COLUMN----------------------
ALTER TABLE dexcom_clean
DROP COLUMN IF EXISTS glucose_category;

/*Question 4:Create a stored procedure to generate a nutritional summary report for a patient,
including total calories, carbohydrates, protein, fiber, and fat consumed */

--step1: Accept patient ID.
--step2: Sum calories, carbohydrates, protein, fiber, and fat.
--step3: Store results in local variables.
--step4: Display the nutritional summary.

CREATE OR REPLACE PROCEDURE generate_nutrition_summary(p_patient_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_calories NUMERIC;
    v_total_carbs NUMERIC;
    v_total_protein NUMERIC;
    v_total_fiber NUMERIC;
    v_total_fat NUMERIC;
BEGIN

    SELECT 
        COALESCE(SUM(calories), 0),
        COALESCE(SUM(carbs_g), 0),
        COALESCE(SUM(protein_g), 0),
        COALESCE(SUM(fiber_g), 0),
        COALESCE(SUM(fat_g), 0)
    INTO 
        v_total_calories,
        v_total_carbs,
        v_total_protein,
        v_total_fiber,
        v_total_fat
    FROM foodlog_clean
    WHERE patient_id = p_patient_id;

    RAISE NOTICE 'Nutrition Summary Report for Patient ID: %', p_patient_id;
    RAISE NOTICE 'Total Calories  : % kcal', v_total_calories;
    RAISE NOTICE 'Total Carbs     : % g', v_total_carbs;
    RAISE NOTICE 'Total Protein   : % g', v_total_protein;
    RAISE NOTICE 'Total Fiber     : % g', v_total_fiber;
    RAISE NOTICE 'Total Fat       : % g', v_total_fat;

END;
$$;

---------------------------CALL PROCEDURE ---------------

CALL generate_nutrition_summary(1);
---------------DROP PROCEDURE------------------
DROP PROCEDURE IF EXISTS generate_nutrition_summary(INT);


/* Question 5 . Classify glucose level into a clinical category using a User Defined Function.

--Step1: Build a function that takes a glucose value as input.
--Step 2: Check the condition and return the right category.
--Step 3: Apply the function as part of a SELECT query.
*/

CREATE OR REPLACE FUNCTION classify_glucose(glucose NUMERIC)
RETURNS TEXT AS $$
BEGIN
    RETURN CASE
        WHEN glucose < 70  THEN 'Hypoglycemic'
        WHEN glucose < 100 THEN 'Normal'
        WHEN glucose < 126 THEN 'Pre-Diabetic'
        WHEN glucose < 180 THEN 'Diabetic Range'
        ELSE                    'Critical High'
    END;
END;
$$ LANGUAGE plpgsql;

SELECT
    patient_id,
    glucose_mgdl,
    classify_glucose(glucose_mgdl)     AS glucose_status
FROM dexcom_clean
WHERE glucose_mgdl BETWEEN 40 AND 400
ORDER BY patient_id, timestamp;


/* Question 6.Generate a full summary report for a given patient using Stored Procedure.
--Step1: Build a Stored Procedure that takes a glucose value as input.
--Step 2: Check the condition and return the right category and information accordingly.
--Step 3: Call the Stored Procedure.
*/

CREATE OR REPLACE PROCEDURE patient_summary_report(IN p_patient_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN

    -- Glucose summary
    RAISE NOTICE '--- GLUCOSE SUMMARY FOR PATIENT % ---', p_patient_id;
    RAISE NOTICE 'Avg: %, Min: %, Max: %',
        (SELECT ROUND(AVG(glucose_mgdl),1)
         FROM dexcom_clean WHERE patient_id = p_patient_id),
        (SELECT MIN(glucose_mgdl)
         FROM dexcom_clean WHERE patient_id = p_patient_id),
        (SELECT MAX(glucose_mgdl)
         FROM dexcom_clean WHERE patient_id = p_patient_id);

    -- Heart rate summary
    RAISE NOTICE '--- HEART RATE SUMMARY ---';
    RAISE NOTICE 'Avg HR: %, Min: %, Max: %',
        (SELECT ROUND(AVG(hr_bpm),1)
         FROM hr_clean WHERE patient_id = p_patient_id),
        (SELECT MIN(hr_bpm)
         FROM hr_clean WHERE patient_id = p_patient_id),
        (SELECT MAX(hr_bpm)
         FROM hr_clean WHERE patient_id = p_patient_id);

    -- Food log summary
    RAISE NOTICE '--- FOOD LOG SUMMARY ---';
    RAISE NOTICE 'Total Calories: %, Avg per meal: %',
        (SELECT SUM(calories)
         FROM foodlog_clean WHERE patient_id = p_patient_id),
        (SELECT ROUND(AVG(calories),1)
         FROM foodlog_clean WHERE patient_id = p_patient_id);

END;
$$;

CALL patient_summary_report(15);


/* Question 7. Generate a day-by-day study calendar and flag days with no glucose recording
Step 1: Build a complete list of every day in the study period, from the earliest to the latest recorded date, so no day is skipped.
Step 2:Get the list of patients and the days each one actually has glucose data for.
Step 3:Combine every patient with every calendar day, then check which days have a matching real recording and which don't.
Step 4: Label each day "Recorded" or "Missing" based on that match, and sort the results by patient and date to see the full timeline of gaps.
*/

WITH RECURSIVE study_calendar AS (

    -- Base: start from the first recorded date
    SELECT
        MIN(timestamp)        AS calendar_date
    FROM dexcom_clean

    UNION ALL

    -- Recurse: add one day at a time until the last recorded date
    SELECT
        calendar_date + INTERVAL '1 day'
    FROM study_calendar
    WHERE calendar_date < (
        SELECT MAX(timestamp)
        FROM dexcom_clean
    )
),

-- Actual days that have glucose recordings
recorded_days AS (
    SELECT DISTINCT
        patient_id,
        timestamp  AS recorded_date
    FROM dexcom_clean
)

SELECT
    c.calendar_date,
    r.patient_id,
    CASE
        WHEN r.recorded_date IS NULL THEN 'Missing'
        ELSE 'Recorded'
    END                                      AS recording_status
FROM study_calendar c
CROSS JOIN (SELECT DISTINCT patient_id FROM dexcom_clean) p
LEFT JOIN recorded_days r
    ON  r.recorded_date = c.calendar_date
    AND r.patient_id    = p.patient_id
ORDER BY p.patient_id, c.calendar_date;


/* Question 8. Automatically log whenever a new glucose reading is flagged as critical using Triggers. 

-- Step 1: Create an audit table to store alerts
-- Step 2: Create the trigger function
-- Step 3: Attach trigger to the clean table
-- Step 4: Insert a row and test
*/

CREATE TABLE IF NOT EXISTS glucose_alerts (
    alert_id      SERIAL PRIMARY KEY,
    patient_id    TEXT,
    glucose_value NUMERIC,
    alert_type    TEXT,
    alert_time    TIMESTAMP DEFAULT NOW()
);


CREATE OR REPLACE FUNCTION flag_critical_glucose()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.glucose_mgdl < 70 THEN
        INSERT INTO glucose_alerts (patient_id, glucose_value, alert_type)
        VALUES (NEW.patient_id, NEW.glucose_mgdl, 'HYPOGLYCEMIA');

    ELSIF NEW.glucose_mgdl > 300 THEN
        INSERT INTO glucose_alerts (patient_id, glucose_value, alert_type)
        VALUES (NEW.patient_id, NEW.glucose_mgdl, 'CRITICAL HIGH');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_glucose_alert
AFTER INSERT ON dexcom_clean
FOR EACH ROW
EXECUTE FUNCTION flag_critical_glucose();

INSERT INTO dexcom_clean (patient_id, glucose_mgdl, timestamp) VALUES (1, 55, NOW());


SELECT *
FROM glucose_alerts
ORDER BY alert_time DESC;

/*Question 9: What is the cardiovascular summary (heart rate and IBI combined) for each patient, including how well the two sensors agree with each other?*/
--step1: Pre-aggregate hr_clean to one row per patient including anomaly count.
--step2: Pre-aggregate ibi_clean to one row per patient, deriving estimated heart rate from IBI.
--step3: Join both pre-aggregated sets to demography and classify sensor agreement based on the difference.

CREATE OR REPLACE PROCEDURE generate_cardiovascular_summary()
LANGUAGE plpgsql
AS $$
BEGIN
    DROP TABLE IF EXISTS temp_cardiovascular_summary;

    CREATE TEMP TABLE temp_cardiovascular_summary AS
    SELECT
        h.patient_id,
        dc.gender,
        dc.hba1c,
        h.total_hr_readings,
        h.avg_hr_bpm,
        h.min_hr_bpm,
        h.max_hr_bpm,
        h.anomaly_count,
        i.total_ibi_readings,
        i.avg_ibi_seconds,
        i.estimated_hr_from_ibi,
        ROUND(ABS(h.avg_hr_bpm - i.estimated_hr_from_ibi), 1) AS hr_ibi_difference,
        CASE
            WHEN ABS(h.avg_hr_bpm - i.estimated_hr_from_ibi) > 20
            THEN 'Large Discrepancy'
            WHEN ABS(h.avg_hr_bpm - i.estimated_hr_from_ibi) > 10
            THEN 'Moderate Discrepancy'
            ELSE 'Good Agreement'
        END AS sensor_agreement
    FROM (
        -- pre-aggregate hr_clean to 16 rows first
        SELECT
            patient_id,
            COUNT(hr_bpm)                                AS total_hr_readings,
            ROUND(AVG(hr_bpm), 2)                        AS avg_hr_bpm,
            ROUND(MIN(hr_bpm), 2)                        AS min_hr_bpm,
            ROUND(MAX(hr_bpm), 2)                        AS max_hr_bpm,
            COUNT(*) FILTER (WHERE hr_anomaly = TRUE)    AS anomaly_count
        FROM hr_clean
        GROUP BY patient_id
    ) h
    JOIN (
        -- pre-aggregate ibi_clean to 16 rows first
        SELECT
            patient_id,
            COUNT(ibi_seconds)                           AS total_ibi_readings,
            ROUND(AVG(ibi_seconds)::numeric, 4)          AS avg_ibi_seconds,
            ROUND(60.0 / AVG(ibi_seconds), 1)            AS estimated_hr_from_ibi
        FROM ibi_clean
        GROUP BY patient_id
    ) i ON h.patient_id = i.patient_id
    JOIN demography_clean dc ON h.patient_id = dc.patient_id;

    RAISE NOTICE 'Cardiovascular summary generated for % patients',
        (SELECT COUNT(*) FROM temp_cardiovascular_summary);
END;
$$;

CALL generate_cardiovascular_summary();

SELECT * FROM temp_cardiovascular_summary
ORDER BY anomaly_count DESC;



/*Question 10: What is each patient's stress score based on how often their EDA readings spiked during the study?*/
--step1: Calculate spike percentage for the given patient into a local variable.
--step2: Validate the patient exists in eda_clean, raising an exception otherwise.
--step3: Return a full stress burden summary including spike count, average/max EDA, and classification.

CREATE OR REPLACE FUNCTION get_stress_burden(p_patient_id INTEGER)
RETURNS TABLE (
    patient_id      INTEGER,
    total_readings  BIGINT,
    spike_count     BIGINT,
    spike_pct       NUMERIC,
    avg_eda         NUMERIC,
    max_eda         NUMERIC,
    stress_burden   TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spike_pct NUMERIC;
BEGIN
    -- calculate spike percentage for this patient
    SELECT
        COUNT(*) FILTER (WHERE eda_spike = TRUE) * 100.0 / COUNT(*)
    INTO v_spike_pct
    FROM eda_clean
    WHERE eda_clean.patient_id = p_patient_id;

    -- check if patient exists
    IF v_spike_pct IS NULL THEN
        RAISE EXCEPTION 'Patient ID % not found in eda_clean', p_patient_id;
    END IF;

    -- return full stress burden summary
    RETURN QUERY
    SELECT
        e.patient_id,
        COUNT(*)                                            AS total_readings,
        COUNT(*) FILTER (WHERE e.eda_spike = TRUE)         AS spike_count,
        ROUND(
            COUNT(*) FILTER (WHERE e.eda_spike = TRUE)
            * 100.0 / COUNT(*)
        , 2)                                               AS spike_pct,
        ROUND(AVG(e.eda_value)::numeric, 4)                AS avg_eda,
        ROUND(MAX(e.eda_value)::numeric, 4)                AS max_eda,
        -- classify stress burden based on spike percentage
        CASE
            WHEN v_spike_pct > 15 THEN 'Critical Stress'
            WHEN v_spike_pct > 10 THEN 'High Stress'
            WHEN v_spike_pct > 5  THEN 'Moderate Stress'
            ELSE                       'Low Stress'
        END                                                AS stress_burden
    FROM eda_clean e
    WHERE e.patient_id = p_patient_id
    GROUP BY e.patient_id;
END;
$$;

-- Test for a single patient
SELECT * FROM get_stress_burden(1);

-- Apply to all patients using a lateral join
SELECT s.*
FROM demography_clean dc
CROSS JOIN LATERAL get_stress_burden(dc.patient_id) s
ORDER BY s.spike_pct DESC;


/*Question 11: What does each patient's glucose readings look like hour by hour across the whole study, including the hours where no data was recorded?*/
--step1: Build a complete hourly timeline per patient using a recursive CTE, from earliest to latest reading.
--step2: Count readings per hour from actual data using a separate aggregation CTE.
--step3: LEFT JOIN the generated timeline to actual hourly data and summarize total hours vs gap hours per patient.

WITH RECURSIVE hour_series AS (
    -- anchor: start from the earliest glucose reading
    SELECT
        patient_id,
        DATE_TRUNC('hour', MIN(timestamp))  AS hour_slot
    FROM dexcom_clean
    GROUP BY patient_id

    UNION ALL

    -- recursive: add one hour at a time until max timestamp
    SELECT
        hs.patient_id,
        hs.hour_slot + INTERVAL '1 hour'
    FROM hour_series hs
    JOIN (
        -- get max timestamp per patient to know when to stop
        SELECT patient_id, MAX(timestamp) AS max_ts
        FROM dexcom_clean
        GROUP BY patient_id
    ) mx ON hs.patient_id = mx.patient_id
    WHERE hs.hour_slot + INTERVAL '1 hour' <= mx.max_ts
),
-- count readings per hour from actual data
hourly_glucose AS (
    SELECT
        patient_id,
        DATE_TRUNC('hour', timestamp)       AS hour_slot,
        COUNT(*)                            AS readings_in_hour
    FROM dexcom_clean
    GROUP BY patient_id, DATE_TRUNC('hour', timestamp)
)
-- summary: one row per patient showing total hours vs gap hours
SELECT
    hs.patient_id,
    COUNT(*)                                              AS total_hours,
    COUNT(hg.readings_in_hour)                            AS hours_with_data,
    COUNT(*) - COUNT(hg.readings_in_hour)                 AS gap_hours,
    ROUND(
        (COUNT(*) - COUNT(hg.readings_in_hour)) * 100.0 / COUNT(*)
    , 2)                                                  AS gap_pct
FROM hour_series hs
LEFT JOIN hourly_glucose hg
    ON hs.patient_id = hg.patient_id
    AND hs.hour_slot = hg.hour_slot
GROUP BY hs.patient_id
ORDER BY gap_hours DESC;


/*Question 12: How do all patients compare on glucose metrics (average, min, max, time in range) for any given date range?*/
--step1: Accept a start and end date as procedure input, validating the range.
--step2: Calculate average, min, max, standard deviation, TIR, TAR, and TBR for each patient within that date range.
--step3: Rank patients by average glucose within the period.

CREATE OR REPLACE PROCEDURE generate_period_glucose_report(
    p_start_date DATE,  -- start of analysis period
    p_end_date   DATE   -- end of analysis period
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- validate date range
    IF p_start_date >= p_end_date THEN
        RAISE EXCEPTION 'Start date must be before end date';
    END IF;

    -- drop temp table if exists from previous run
    DROP TABLE IF EXISTS temp_period_glucose_report;

    -- generate comparative report for the period
    CREATE TEMP TABLE temp_period_glucose_report AS
    SELECT
        d.patient_id,
        dc.gender,
        dc.hba1c,
        COUNT(d.reading_id)                                 AS total_readings,
        ROUND(AVG(d.glucose_mgdl), 2)                       AS avg_glucose,
        ROUND(MIN(d.glucose_mgdl), 2)                       AS min_glucose,
        ROUND(MAX(d.glucose_mgdl), 2)                       AS max_glucose,
        ROUND(STDDEV(d.glucose_mgdl), 2)                    AS stddev_glucose,
        -- time in range 70-180 mg/dL
        ROUND(
            COUNT(*) FILTER (WHERE d.glucose_mgdl BETWEEN 70 AND 180)
            * 100.0 / COUNT(*)
        , 2)                                                AS tir_pct,
        -- time above range > 180 mg/dL
        ROUND(
            COUNT(*) FILTER (WHERE d.glucose_mgdl > 180)
            * 100.0 / COUNT(*)
        , 2)                                                AS tar_pct,
        -- time below range < 70 mg/dL
        ROUND(
            COUNT(*) FILTER (WHERE d.glucose_mgdl < 70)
            * 100.0 / COUNT(*)
        , 2)                                                AS tbr_pct,
        -- rank patients by average glucose within this period
        RANK() OVER (
            ORDER BY AVG(d.glucose_mgdl) DESC
        )                                                   AS glucose_rank
    FROM dexcom_clean d
    JOIN demography_clean dc ON d.patient_id = dc.patient_id
    -- filter to specified date range
    WHERE d.timestamp BETWEEN p_start_date AND p_end_date
    GROUP BY d.patient_id, dc.gender, dc.hba1c;

    RAISE NOTICE 'Period report generated from % to % for % patients',
        p_start_date,
        p_end_date,
        (SELECT COUNT(*) FROM temp_period_glucose_report);
END;
$$;

-- Call the procedure for full study period
CALL generate_period_glucose_report('2020-02-13', '2020-07-27');

-- View the results
SELECT * FROM temp_period_glucose_report
ORDER BY glucose_rank;


/*Question 13: Identify stress periods using rolling EDA.*/
--step1: Compute rolling mean and standard deviation of EDA per patient using a 120-reading window frame.
--step2: Flag each reading as a stress event if it exceeds rolling mean plus one standard deviation.
--step3: Group consecutive stress-flagged readings into discrete stress periods using the island-and-gap technique.
--step4: Summarize each period's start, end, duration, and peak EDA, filtering out short false-positive events.

WITH eda_rolling AS (
    SELECT
        ec.patient_id,
        ec.timestamp,
        ec.eda_value,
        AVG(ec.eda_value) OVER (
            PARTITION BY ec.patient_id
            ORDER BY ec.timestamp
            ROWS BETWEEN 119 PRECEDING AND CURRENT ROW
        )                                  AS rolling_mean,
        STDDEV(ec.eda_value) OVER (
            PARTITION BY ec.patient_id
            ORDER BY ec.timestamp
            ROWS BETWEEN 119 PRECEDING AND CURRENT ROW
        )                                  AS rolling_sd
    FROM eda_clean ec
),
flagged_ec AS (
    SELECT
        eda_rolling.patient_id,
        eda_rolling.timestamp,
        eda_rolling.eda_value,
        eda_rolling.rolling_mean,
        eda_rolling.rolling_sd,
        CASE WHEN eda_rolling.eda_value
                  > eda_rolling.rolling_mean + eda_rolling.rolling_sd
             THEN 1 ELSE 0
        END                                AS is_stress
    FROM eda_rolling
    WHERE eda_rolling.rolling_sd IS NOT NULL
),
grouped_ec AS (
    SELECT
        flagged_ec.patient_id,
        flagged_ec.timestamp,
        flagged_ec.eda_value,
        flagged_ec.is_stress,
        ROW_NUMBER() OVER (
            PARTITION BY flagged_ec.patient_id
            ORDER BY flagged_ec.timestamp
        )
        - ROW_NUMBER() OVER (
            PARTITION BY flagged_ec.patient_id, flagged_ec.is_stress
            ORDER BY flagged_ec.timestamp
        )                                  AS island_grp
    FROM flagged_ec
)
SELECT
    grouped_ec.patient_id,
    MIN(grouped_ec.timestamp)              AS stress_period_start,
    MAX(grouped_ec.timestamp)              AS stress_period_end,
    ROUND(
        EXTRACT(EPOCH FROM
            MAX(grouped_ec.timestamp) - MIN(grouped_ec.timestamp)
        ) / 60, 1
    )                                      AS duration_minutes,
    COUNT(*)                               AS readings_in_period,
    ROUND(AVG(grouped_ec.eda_value)::NUMERIC, 5) AS avg_eda_during_stress,
    ROUND(MAX(grouped_ec.eda_value)::NUMERIC, 5) AS peak_eda
FROM grouped_ec
WHERE grouped_ec.is_stress = 1
GROUP BY grouped_ec.patient_id, grouped_ec.island_grp
HAVING COUNT(*) >= 10
ORDER BY peak_eda DESC;

/*Question 14: Create a function to compute daily glucose average.*/
--step1: Build a set-returning function accepting a patient ID and an optional start/end date range.
--step2: Filter to EGV readings, applying the optional date range if provided.
--step3: Return one row per study day with average, min, max glucose, reading count, and completeness percentage.
 
CREATE OR REPLACE FUNCTION get_daily_glucose_avg(
    p_patient_id   INT,
    p_start_date   DATE DEFAULT NULL,
    p_end_date     DATE DEFAULT NULL
)
RETURNS TABLE (
    study_day          DATE,
    avg_glucose_mgdl   NUMERIC,
    min_glucose        NUMERIC,
    max_glucose        NUMERIC,
    reading_count      INT,
    completeness_pct   NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CAST(dc.timestamp AS DATE)               AS study_day,
        ROUND(AVG(dc.glucose_mgdl)::NUMERIC, 1),
        MIN(dc.glucose_mgdl),
        MAX(dc.glucose_mgdl),
        COUNT(*)::INT,
        ROUND(COUNT(*) * 100.0 / 288::NUMERIC, 1) AS completeness_pct
    FROM dexcom_clean dc
    WHERE dc.patient_id  = p_patient_id
      AND UPPER(TRIM(dc.event_type)) = 'EGV'
      AND dc.glucose_mgdl IS NOT NULL
      AND (p_start_date IS NULL OR CAST(dc.timestamp AS DATE) >= p_start_date)
      AND (p_end_date   IS NULL OR CAST(dc.timestamp AS DATE) <= p_end_date)
    GROUP BY CAST(dc.timestamp AS DATE)
    ORDER BY study_day;
END;
$$;

-- Usage: daily averages for participant 3
SELECT * FROM get_daily_glucose_avg(3);

-- Usage: all participants via LATERAL join
SELECT dgc.patient_id, dgc.hba1c, g.*
FROM demography_clean dgc
CROSS JOIN LATERAL get_daily_glucose_avg(dgc.patient_id) g
ORDER BY dgc.patient_id, g.study_day;

/*Question 15: Create a function to summarize heart rate.*/
--step1: Build a set-returning function accepting a patient ID.
--step2: Filter heart rate readings to a physiologically valid range (40-200 bpm).
--step3: Return mean, median, standard deviation, resting HR, peak HR, 25th/75th percentiles, total readings, and anomaly count using PERCENTILE_CONT.

CREATE OR REPLACE FUNCTION summarize_heart_rate(p_patient_id INT)
RETURNS TABLE (
    avg_hr_bpm       NUMERIC,
    median_hr_bpm    NUMERIC,
    std_hr_bpm       NUMERIC,
    resting_hr_bpm   NUMERIC,
    peak_hr_bpm      NUMERIC,
    p25_hr           NUMERIC,
    p75_hr           NUMERIC,
    total_readings   BIGINT,
    anomaly_count    BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ROUND(AVG(hc.hr_bpm)::NUMERIC, 1),
        ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP
              (ORDER BY hc.hr_bpm)::NUMERIC, 1),
        ROUND(STDDEV(hc.hr_bpm)::NUMERIC, 2),
        ROUND(PERCENTILE_CONT(0.10) WITHIN GROUP
              (ORDER BY hc.hr_bpm)::NUMERIC, 1),
        MAX(hc.hr_bpm),
        ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP
              (ORDER BY hc.hr_bpm)::NUMERIC, 1),
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP
              (ORDER BY hc.hr_bpm)::NUMERIC, 1),
        COUNT(*),
        COUNT(*) FILTER (WHERE hc.hr_anomaly = TRUE)
    FROM hr_clean hc
    WHERE hc.patient_id = p_patient_id
      AND hc.hr_bpm BETWEEN 40 AND 200;
END;
$$;

-- Usage: summary for one participant
SELECT * FROM summarize_heart_rate(3);

-- Usage: all participants via LATERAL join
SELECT
    dgc.patient_id,
    dgc.hba1c,
    s.avg_hr_bpm,
    s.resting_hr_bpm,
    s.peak_hr_bpm,
    s.std_hr_bpm,
    s.anomaly_count
FROM demography_clean dgc
CROSS JOIN LATERAL summarize_heart_rate(dgc.patient_id) s
ORDER BY s.avg_hr_bpm DESC;

/*Question 16: Create a trigger to log high glucose events.*/
--step1: Create an event log table for high glucose alerts with severity classification.
--step2: Create a trigger function that fires only on EGV rows above 180 mg/dL, classifying severity.
--step3: Attach the trigger to dexcom_clean as an AFTER INSERT trigger.
--step4: Review logged events.

-----------------------------Event log table -----------------------------------------------------
CREATE TABLE IF NOT EXISTS high_glucose_events (
    event_id     SERIAL PRIMARY KEY,
    patient_id   INT,
    reading_id   INT,
    event_time   TIMESTAMP,
    glucose_mgdl NUMERIC,
    severity     TEXT,
    logged_at    TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_hge_patient
    ON high_glucose_events(patient_id, logged_at);

--------------Trigger function (NEW row represents a dexcom_clean / dc row)----------------------
CREATE OR REPLACE FUNCTION fn_log_high_glucose()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only process EGV event type rows (dc context)
    IF UPPER(TRIM(NEW.event_type)) <> 'EGV' THEN
        RETURN NEW;
    END IF;

    IF NEW.glucose_mgdl > 180 THEN
        INSERT INTO high_glucose_events
            (patient_id, reading_id, event_time,
             glucose_mgdl, severity)
        VALUES (
            NEW.patient_id,   -- dc.patient_id
            NEW.reading_id,   -- dc.reading_id
            NEW.timestamp,    -- dc.timestamp
            NEW.glucose_mgdl, -- dc.glucose_mgdl
            CASE
                WHEN NEW.glucose_mgdl > 300 THEN 'Critical (>300)'
                WHEN NEW.glucose_mgdl > 250 THEN 'Severe (>250)'
                WHEN NEW.glucose_mgdl > 200 THEN 'High (>200)'
                ELSE 'Elevated (180-200)'
            END
        );
    END IF;

    RETURN NEW;
END;
$$;

-----------Attach trigger to dexcom_clean (dc)--------------------------------
DROP TRIGGER IF EXISTS trg_log_high_glucose ON dexcom_clean;

CREATE TRIGGER trg_log_high_glucose
AFTER INSERT ON dexcom_clean
FOR EACH ROW EXECUTE FUNCTION fn_log_high_glucose();

--------------------Review logged events---------------------------------------
SELECT
    hge.patient_id,
    hge.event_time,
    hge.glucose_mgdl,
    hge.severity,
    hge.logged_at
FROM high_glucose_events hge
ORDER BY hge.glucose_mgdl DESC
LIMIT 20;

------------------------------------------------------------------------------------