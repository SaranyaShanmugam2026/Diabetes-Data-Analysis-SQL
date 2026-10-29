-- ============================================================
--  DATA EXPLORATION AND PROFILING
-- Purpose:
-- Examine the raw dataset to identify data quality issues,
-- understand its structure, and determine the cleaning and
-- transformation steps required to build an analytics-ready schema.
--============================================================
----------------------------------------------------------------------------------------------
-- ROW COUNTS
-- Purpose:
-- Verify that all records were imported successfully and
-- establish baseline row counts before data cleaning.
-- --------------------------------------------------------------------------------------------

SELECT 'demography'  AS table_name, COUNT(*) AS row_count FROM demography  UNION ALL
SELECT 'dexcom',                    COUNT(*)              FROM dexcom       UNION ALL
SELECT 'eda',                       COUNT(*)              FROM eda          UNION ALL
SELECT 'foodlog',                   COUNT(*)              FROM foodlog      UNION ALL
SELECT 'hr',                        COUNT(*)              FROM hr           UNION ALL
SELECT 'ibi',                       COUNT(*)              FROM ibi          UNION ALL
SELECT 'temperature',               COUNT(*)              FROM temperature;


-- ------------------------------------------------------------
--  COLUMN DATA TYPES
-- Purpose:
-- Identify columns requiring data type conversion to improve
-- query performance and analytical processing.
-- ------------------------------------------------------------

SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name IN (
    'demography','dexcom','eda',
    'foodlog','hr','ibi','temperature'
)
ORDER BY table_name, ordinal_position;
-- ------------------------------------------------------------
-- SAMPLE RAW DATA FROM EACH TABLE
-- Purpose:
-- Inspect raw data values, formats, and missing data to
-- determine appropriate cleaning and transformation rules.
-- ------------------------------------------------------------
-- demography
SELECT * FROM demography LIMIT 10;
-- dexcom
SELECT * FROM dexcom LIMIT 10;
-- foodlog
SELECT * FROM foodlog LIMIT 10;
-- hr
SELECT * FROM hr LIMIT 10;
-- ibi
SELECT * FROM ibi LIMIT 10;
-- temperature
SELECT * FROM temperature LIMIT 10;

-----------------------------------------------------------------------------------------------
--------------------------DROP TABLE ALREADY EXISTS-------------------------------------------

DROP TABLE IF EXISTS demography_stage CASCADE;
DROP TABLE IF EXISTS dexcom_stage CASCADE;
DROP TABLE IF EXISTS eda_stage CASCADE;
DROP TABLE IF EXISTS foodlog_stage CASCADE;
DROP TABLE IF EXISTS hr_stage CASCADE;
DROP TABLE IF EXISTS ibi_stage CASCADE;
DROP TABLE IF EXISTS temperature_stage CASCADE;
DROP TABLE IF EXISTS demography_clean CASCADE;
DROP TABLE IF EXISTS dexcom_clean CASCADE;
DROP TABLE IF EXISTS eda_clean CASCADE;
DROP TABLE IF EXISTS foodlog_clean CASCADE;
DROP TABLE IF EXISTS hr_clean CASCADE;
DROP TABLE IF EXISTS ibi_clean CASCADE;
DROP TABLE IF EXISTS temperature_clean CASCADE;
	

---------------------------------------------------------------------------------------
-------------------------------------CREATE STAGE TABLE -------------------------------
-----------------------------------------------------------------------------------------------

CREATE TABLE dexcom_stage AS SELECT * FROM dexcom;
CREATE TABLE hr_stage AS SELECT * FROM hr;
CREATE TABLE ibi_stage AS SELECT * FROM ibi;
CREATE TABLE eda_stage AS SELECT * FROM eda;
CREATE TABLE temperature_stage AS SELECT * FROM temperature;
CREATE TABLE foodlog_stage AS SELECT * FROM foodlog;
CREATE TABLE demography_stage AS SELECT * FROM demography;
------------------------------------------------------------------------------------------------
------------------------------- VERIFY ALL STAGING TABLES CREATED SUCCESSFULLY------------------
-- ----------------------------------------------------------------------------------------------
SELECT 'demography_stage'  AS table_name, COUNT(*) AS row_count FROM demography_stage  UNION ALL
SELECT 'dexcom_stage',                    COUNT(*)              FROM dexcom_stage       UNION ALL
SELECT 'hr_stage',                        COUNT(*)              FROM hr_stage           UNION ALL
SELECT 'eda_stage',                       COUNT(*)              FROM eda_stage          UNION ALL
SELECT 'ibi_stage',                       COUNT(*)              FROM ibi_stage          UNION ALL
SELECT 'temperature_stage',               COUNT(*)              FROM temperature_stage  UNION ALL
SELECT 'foodlog_stage',                   COUNT(*)              FROM foodlog_stage;
-------------------------------------------------------------------------------------------------------
-------------------------------------DATA CLEANING-------------------------------------------------
-- Purpose: Clean all staging tables to prepare for final schema
-- =========================================================================================================

----------------------------DEMOGRAPHY  TABLE --------------------------------------------------------
------------------------------------------------------------------------------------------------------

-------------------------------CLEANING PROCESS-------------------------------------------------------

-------------------------------NULL CHECK-----------------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE gender IS NULL OR gender = '') AS null_gender,
    COUNT(*) FILTER (WHERE hba1c IS NULL OR hba1c = '') AS null_hba1c,
    COUNT(*) FILTER (WHERE patientid IS NULL OR patientid = '') AS null_patientid
FROM demography_stage;

---------------------------------HANDLING DUPLICATES------------------------------------------------------
SELECT patientid, gender, hba1c, COUNT(*) As a
FROM demography_stage
GROUP BY patientid, gender, hba1c
HAVING count(*) > 1
order by a desc;

-----------------------RANGE OF VALUES--------------------------------------------------------------
SELECT 
    MIN(hba1c::numeric) AS min_hba1c,
    MAX(hba1c::numeric) AS max_hba1c,
    AVG(hba1c::numeric) AS avg_hba1c
FROM demography_stage
WHERE hba1c IS NOT NULL;

----------------------------CREATING CLEAN TABLE ---------------------------------------------------------
CREATE TABLE demography_clean (
    patient_id  INTEGER         PRIMARY KEY,
    gender      VARCHAR(10)     NOT NULL,
    hba1c       NUMERIC(4,1)    NOT NULL
);

INSERT INTO demography_clean (patient_id, gender, hba1c)
SELECT
    patientid::INTEGER,
	TRIM(UPPER(gender)),
    ROUND(hba1c::NUMERIC, 1)
FROM demography_stage;
------------------------------------VALIDATION------------------------------------------------------------
SELECT * FROM   demography_clean;
SELECT COUNT(*)FROM  demography;
SELECT COUNT(*) FROM demography_stage;
SELECT COUNT(*) FROM demography_clean;

-----------------------------------------------------------------------------------------------
-----------------------------------DEXCOM TABLE -----------------------------------------------
-----------------------------------------------------------------------------------------------

-------------------------CLEANING PROCESS---------------------------------------------------

----------------------------NULL CHECK-----------------------------------------------------------------------

SELECT
    COUNT(*) FILTER (WHERE indexval                    IS NULL OR indexval                    = '') AS null_indexval,
    COUNT(*) FILTER (WHERE timeof                      IS NULL OR timeof                      = '') AS null_timeof,
    COUNT(*) FILTER (WHERE eventtype                   IS NULL OR eventtype                   = '') AS null_eventtype,
    COUNT(*) FILTER (WHERE eventsubtype                IS NULL OR eventsubtype                = '') AS null_eventsubtype,
    COUNT(*) FILTER (WHERE patientinfo                 IS NULL OR patientinfo                 = '') AS null_patientinfo,
    COUNT(*) FILTER (WHERE deviceinfo                  IS NULL OR deviceinfo                  = '') AS null_deviceinfo,
    COUNT(*) FILTER (WHERE sourcedeviceid              IS NULL OR sourcedeviceid              = '') AS null_sourcedeviceid,
    COUNT(*) FILTER (WHERE glucosevaluemgdl            IS NULL OR glucosevaluemgdl            = '') AS null_glucosevaluemgdl,
    COUNT(*) FILTER (WHERE insulinvalue_u              IS NULL OR insulinvalue_u              = '') AS null_insulinvalue_u,
    COUNT(*) FILTER (WHERE carbvaluegrams              IS NULL OR carbvaluegrams              = '') AS null_carbvaluegrams,
    COUNT(*) FILTER (WHERE duration                    IS NULL OR duration                    = '') AS null_duration,
    COUNT(*) FILTER (WHERE glucoserateofchangemgdlmin  IS NULL OR glucoserateofchangemgdlmin  = '') AS null_glucoserateofchangemgdlmin,
    COUNT(*) FILTER (WHERE transmittertimelonginteger  IS NULL OR transmittertimelonginteger  = '') AS null_transmittertimelonginteger,
    COUNT(*) FILTER (WHERE patientid                   IS NULL OR patientid                   = '') AS null_patientid
FROM dexcom_stage;


SELECT *FROM dexcom_stage
WHERE eventsubtype IS NOT NULL;

SELECT *FROM dexcom_stage
WHERE glucosevaluemgdl IS NULL;

SELECT*FROM dexcom_stage
WHERE eventtype = 'Exercise';

SELECT DISTINCT eventtype FROM dexcom_stage;

SELECT 
    COALESCE(eventtype, '(blank)') AS event_type,
    COALESCE(eventsubtype, '(blank)') AS event_subtype,
    COUNT(*) AS row_count
FROM dexcom_stage
GROUP BY eventtype, eventsubtype
ORDER BY row_count DESC;


----------------------------------------------HANDLINING DUPLICATES VALUES---------------------------
SELECT *
FROM dexcom_stage d
WHERE (patientid, timeof, glucosevaluemgdl) IN (
    SELECT
        patientid,
        timeof,
        glucosevaluemgdl
    FROM dexcom_stage
    GROUP BY
        patientid,
        timeof,
        glucosevaluemgdl
    HAVING COUNT(*) > 1
)
ORDER BY patientid, timeof;

------------------------------------------------RANGE OF VALUES--------------------------------
SELECT
MIN(glucosevaluemgdl::numeric),
MAX(glucosevaluemgdl::numeric)
FROM dexcom_stage;

-----------------------------------------CREATE TABLE ---------------------------------------

--filtering the rows with null values (Eventtype = 'Exercise')
--removed the columns with null values in all rows 
CREATE TABLE dexcom_clean (
	reading_id        SERIAL PRIMARY KEY,
    index_val         INTEGER,
    timestamp         TIMESTAMP,
    event_type        VARCHAR(50),
    event_subtype     VARCHAR(50),
    sourcedevice_id   TEXT,
    glucose_mgdl      NUMERIC,
    duration          TIME,
    transmitter_time  BIGINT,
    patient_id        INTEGER NOT NULL,

    CONSTRAINT fk_dexcom_patient
        FOREIGN KEY (patient_id)
        REFERENCES demography_clean(patient_id)
);
INSERT INTO dexcom_clean (
    index_val,
    timestamp,
    event_type,
    event_subtype,
    sourcedevice_id,
    glucose_mgdl,
    duration,
    transmitter_time,
    patient_id
)
SELECT
    indexval::int,
    TO_TIMESTAMP(timeof,'MM/DD/YYYY HH24:MI'),
    TRIM(eventtype),
    TRIM(eventsubtype),
    sourcedeviceid,
    glucosevaluemgdl::numeric,
    duration::time,
    transmittertimelonginteger::bigint,
    patientid::integer
FROM dexcom_stage
WHERE eventtype = 'EGV';


------------------------------VALIDATION-------------------------------------------------
SELECT *
FROM dexcom_clean
WHERE event_type='Exercise';

SELECT * FROM  dexcom_clean
WHERE event_subtype IS NOT NULL;

SELECT  * FROM dexcom_clean;
SELECT  COUNT (*) FROM dexcom;
SELECT  COUNT (*)FROM dexcom_stage;
SELECT  COUNT (*) FROM dexcom_clean;



-----------------------------------------------------------------------------------------------
------------------------------------------EDA TABLE--------------------------------------------
-----------------------------------------------------------------------------------------------

--------------------------------------CLEANING PROCESS-------------------------------------

---------------------------------------NULL CHECK------------------------------------------
 SELECT   COUNT(*) FILTER (WHERE timeof IS NULL OR timeof = '') AS null_timestamp,
    COUNT(*) FILTER (WHERE eda IS NULL OR eda = '') AS null_eda,
    COUNT(*) FILTER (WHERE patientid IS NULL OR patientid = '') AS null_patientid
FROM eda_stage;

--------------------------------------HANDLING DUPLICATES---------------------------------

SELECT *
FROM eda_stage
WHERE (patientid, timeof, eda) IN (
    SELECT
        patientid,
        timeof,
        eda
    FROM eda_stage
    GROUP BY patientid, timeof, eda
	HAVING COUNT(*) > 1
)
ORDER BY patientid, timeof;


--------------------------------RANGE OF VALUES --------------------------------------------
SELECT
MIN(eda::numeric),
MAX(eda::numeric)
FROM eda_stage;

-----------------------------------------CREATE TABLE -----------------------------------------
CREATE TABLE eda_clean (
    reading_id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    eda_value NUMERIC NOT NULL,
	eda_spike BOOLEAN DEFAULT FALSE,

    CONSTRAINT fk_eda_patient
    FOREIGN KEY(patient_id)
    REFERENCES demography_clean(patient_id)
);
INSERT INTO eda_clean (
    patient_id,
    timestamp,
    eda_value
)
SELECT
    patientid::integer,
    timeof::timestamp,
    eda::numeric
FROM eda_stage;

-- Flag stress spike events (EDA > 5 microsiemens)
-- 200,385 spike rows represent 4.93% of total EDA readings
-- These indicate significant physiological stress response events

UPDATE eda_clean
SET eda_spike = TRUE
WHERE eda_value > 5;

-------------------------------------------VALIDATION----------------------------------------------
SELECT * FROM  eda_clean;

SELECT COUNT (*) FROM eda_stage;
SELECT COUNT(*) FROM eda_clean;


----------------------------------------------------------------------------------------------
------------------------------FOODLOG TABLE ---------------------------------------------------
-----------------------------------------------------------------------------------------------

-------------------------------CLEANING PROCESS-------------------------------------------------

--------------------------------NULL CHECK--------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE dateof        IS NULL OR dateof        IN ('', '\N')) AS null_dateof,
    COUNT(*) FILTER (WHERE timeof        IS NULL OR timeof        IN ('', '\N')) AS null_timeof,
    COUNT(*) FILTER (WHERE time_begin    IS NULL OR time_begin    IN ('', '\N')) AS null_time_begin,
    COUNT(*) FILTER (WHERE time_end      IS NULL OR time_end      IN ('', '\N')) AS null_time_end,
    COUNT(*) FILTER (WHERE logged_food   IS NULL OR logged_food   IN ('', '\N')) AS null_logged_food,
    COUNT(*) FILTER (WHERE amount        IS NULL OR amount        IN ('', '\N')) AS null_amount,
    COUNT(*) FILTER (WHERE unit          IS NULL OR unit          IN ('', '\N')) AS null_unit,
    COUNT(*) FILTER (WHERE searched_food IS NULL OR searched_food IN ('', '\N')) AS null_searched_food,
    COUNT(*) FILTER (WHERE calorie       IS NULL OR calorie       IN ('', '\N')) AS null_calorie,
    COUNT(*) FILTER (WHERE total_carb    IS NULL OR total_carb    IN ('', '\N')) AS null_total_carb,
    COUNT(*) FILTER (WHERE dietary_fiber IS NULL OR dietary_fiber IN ('', '\N')) AS null_dietary_fiber,
    COUNT(*) FILTER (WHERE sugar         IS NULL OR sugar         IN ('', '\N')) AS null_sugar,
    COUNT(*) FILTER (WHERE protein       IS NULL OR protein       IN ('', '\N')) AS null_protein,
    COUNT(*) FILTER (WHERE total_fat     IS NULL OR total_fat     IN ('', '\N')) AS null_total_fat,
    COUNT(*) FILTER (WHERE patientid     IS NULL OR patientid     IN ('', '\N')) AS null_patientid,
    COUNT(*) FILTER (WHERE time_of_day   IS NULL OR time_of_day   IN ('', '\N')) AS null_time_of_day
FROM foodlog_stage;

--------------------------------------HANDLING DUPLICATES----------------------------------------------

SELECT
    dateof, timeof, time_begin, time_end, logged_food, amount, unit, searched_food, calorie,
    total_carb, dietary_fiber, sugar, protein, total_fat, patientid, time_of_day, 
COUNT(*) AS duplicate_count
FROM foodlog_stage
GROUP BY
    dateof, timeof, time_begin, time_end, logged_food, amount, unit, searched_food, calorie, total_carb,
    dietary_fiber, sugar, protein, total_fat, patientid, time_of_day
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


WITH dupes AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY
               dateof, timeof, time_begin, time_end, logged_food, amount, unit, searched_food, calorie,
    			total_carb, dietary_fiber, sugar, protein, total_fat, patientid, time_of_day
            ORDER BY ctid
        ) AS rn
    FROM foodlog_stage
)
DELETE FROM foodlog_stage
WHERE ctid IN (
    SELECT ctid
    FROM dupes
    WHERE rn > 1
);


SELECT *
FROM foodlog_stage
WHERE patientid = '15' 
AND sugar = '4.7'
AND time_begin = '2/21/2020 17:00';

-----------------------------------------CREATE TABLE ---------------------------------------

CREATE TABLE foodlog_clean (
    meal_id         SERIAL PRIMARY KEY,
    patient_id      INTEGER NOT NULL,
    timestamp       TIMESTAMP NOT NULL,
    time_end        TIMESTAMP,
    logged_food     TEXT,
    amount          NUMERIC(8,2),
    unit            VARCHAR(30),
    searched_food   TEXT,
    calories        NUMERIC,
    carbs_g         NUMERIC,
    fiber_g         NUMERIC,
    sugar_g         NUMERIC,
    protein_g       NUMERIC,
    fat_g           NUMERIC,

    CONSTRAINT fk_foodlog_patient
        FOREIGN KEY (patient_id)
        REFERENCES demography_clean(patient_id)
);

INSERT INTO foodlog_clean (
    patient_id,
    timestamp,
    time_end,      
    logged_food,
    amount,
    unit,
    searched_food,
    calories,
    carbs_g,
    fiber_g,
    sugar_g,
    protein_g,
    fat_g
)
SELECT
    patientid::INTEGER,
    COALESCE(
        TO_TIMESTAMP(time_begin, 'MM/DD/YYYY HH24:MI'),
        TO_TIMESTAMP(dateof || ' ' || timeof, 'MM/DD/YYYY HH24:MI:SS')
    ),
    CASE
        WHEN time_end IS NOT NULL
        THEN (DATE(COALESCE(
                TO_TIMESTAMP(time_begin, 'MM/DD/YYYY HH24:MI'),
                TO_TIMESTAMP(dateof || ' ' || timeof, 'MM/DD/YYYY HH24:MI:SS')
             ))::text || ' ' || time_end)::timestamp
        ELSE NULL
    END,
    TRIM(logged_food),
    CASE
        WHEN amount ~ '^-?\d+(\.\d+)?$'
        THEN amount::NUMERIC(8,2)
        ELSE NULL
    END,
    TRIM(unit),
    TRIM(searched_food),
    calorie::NUMERIC,
    total_carb::NUMERIC,
    dietary_fiber::NUMERIC,
    sugar::NUMERIC,
    protein::NUMERIC,
    total_fat::NUMERIC
FROM foodlog_stage;

-------------------------------------------------------VAIDATION------------------------------
SELECT * FROM foodlog_clean;

SELECT COUNT(*) FROM foodlog_stage UNION ALL
SELECT COUNT(*) FROM foodlog_clean;

-----------------------------------------------------------------------------------------------
----------------------------HR------------------------------------------------------------------	
-----------------------------------------------------------------------------------------------


-------------------------------CLEANING PROCESS-----------------------------------------------------
-------------------------------NULL CHECK-----------------------------------------------------------

SELECT
    COUNT(*) FILTER (WHERE timeof IS NULL OR timeof = '') AS null_timestamp,
    COUNT(*) FILTER (WHERE hr IS NULL OR hr = '') AS null_hr,
    COUNT(*) FILTER (WHERE patientid IS NULL OR patientid = '') AS null_patientid
FROM hr_stage;
--------------------------------------HANDLING DUPLICATES----------------------------------------------
--Handling Duplicate Values - 69231 duplicate rows
--Duplicate rows identified and removed, keeping the first occurrence.
SELECT patientid, timeof, hr, COUNT(*) AS cnt
FROM hr_stage
GROUP BY patientid, timeof, hr
HAVING COUNT(*) > 1
ORDER BY cnt DESC;


WITH dupes AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY
               patientid, timeof, hr
            ORDER BY ctid
        ) AS rn
    FROM hr_stage
)
DELETE FROM hr_stage
WHERE ctid IN (
    SELECT ctid
    FROM dupes
    WHERE rn > 1
);



--------------------------------RANGE OF VALUES --------------------------------------------
SELECT
MIN(hr::numeric),
MAX(hr::numeric)
FROM hr_stage;

-----------------------------------------CREATE TABLE ---------------------------------------

CREATE TABLE hr_clean (
    reading_id  SERIAL PRIMARY KEY,
    patient_id  INTEGER NOT NULL,
    timestamp   TIMESTAMP NOT NULL,
    hr_bpm      DECIMAL(6,2) NOT NULL,
    hr_anomaly  BOOLEAN DEFAULT FALSE,

    CONSTRAINT fk_hr_patient
        FOREIGN KEY (patient_id)
        REFERENCES demography_clean(patient_id)
);

INSERT INTO hr_clean (
    patient_id,
    "timestamp",
    hr_bpm
)
SELECT
    patientid::INTEGER,
    CASE
        WHEN timeof LIKE '%/%' THEN
            TO_TIMESTAMP(timeof, 'MM/DD/YY HH24:MI')
        ELSE
            timeof::TIMESTAMP
    END,
    hr::DECIMAL(6,2)
FROM hr_stage;

-------FEATURE CREATION ANAMOLY -----------------

-- Flag anomalous heart rate readings
-- Threshold: < 50 OR > 120 bpm
-- Below 50 bpm may indicate bradycardia (abnormally slow HR)
-- Above 120 bpm may indicate tachycardia (elevated resting HR)

UPDATE hr_clean
SET hr_anomaly = TRUE
WHERE hr_bpm < 50 OR hr_bpm > 120;

-------------------------------------------------------VAIDATION------------------------------
SELECT * FROM hr_clean;

SELECT COUNT(*) FROM hr_stage UNION ALL
SELECT COUNT(*) FROM hr_clean;


-----------------------------------------------------------------------------------------------
----------------------------------------------IBI TABLE----------------------------------------
-----------------------------------------------------------------------------------------------
-------------------------------CLEANING PROCESS-----------------------------------------------------
-------------------------------NULL CHECK-----------------------------------------------------------

SELECT
    COUNT(*) FILTER (WHERE timeof IS NULL)    AS null_timeof,
    COUNT(*) FILTER (WHERE ibi IS NULL)       AS null_ibi,
    COUNT(*) FILTER (WHERE patientid IS NULL) AS null_patientid
FROM ibi_stage;

--------------------------------------HANDLING DUPLICATES----------------------------------------------

SELECT patientid, timeof, ibi, COUNT(*) AS cnt
FROM ibi_stage
GROUP BY patientid, timeof, ibi
HAVING COUNT(*) > 1
ORDER BY cnt DESC;


--------------------------------RANGE OF VALUES --------------------------------------------
SELECT
MIN(ibi::numeric),
MAX(ibi::numeric)
FROM ibi_stage;


-----------------------------------------CREATE TABLE ---------------------------------------
CREATE TABLE ibi_clean (
    reading_id  SERIAL PRIMARY KEY,
    patient_id  INTEGER NOT NULL,
    timestamp   TIMESTAMP NOT NULL,
    ibi_seconds DECIMAL(10,6) NOT NULL,

    CONSTRAINT fk_ibi_patient
        FOREIGN KEY (patient_id)
        REFERENCES demography_clean(patient_id)
);
INSERT INTO ibi_clean (
    patient_id,
    timestamp,
    ibi_seconds
)
SELECT
    patientid::INTEGER,
    timeof::TIMESTAMP,
    ibi::DECIMAL(10,6)
FROM ibi_stage;

------------------------------------------VALIDATION----------------------------------------------

SELECT * FROM ibi_clean;

SELECT COUNT(*) FROM ibi_stage;
SELECT COUNT(*) FROM ibi_clean;
-----------------------------------------------------------------------------------------------------
--------------------------------TEMPERATURE TABLE ---------------------------------------------------
------------------------------------Validation Check---------------------------------------
SELECT * FROM temperature;
SELECT * FROM temperature_stage;
SELECT * FROM temperature_clean;


SELECT COUNT(*) FROM temperature_stage;
SELECT COUNT(*) FROM temperature_clean;

-------------------------------CLEANING PROCESS-----------------------------------------------------

---------------------------------NULL CHECK--------------------------------------------------------

SELECT
    COUNT(*) FILTER (WHERE timeof IS NULL)      AS null_timeof,
    COUNT(*) FILTER (WHERE temparature IS NULL) AS null_temperature,
    COUNT(*) FILTER (WHERE patientid IS NULL)   AS null_patientid
FROM temperature_stage;

--------------------------------------HANDLING DUPLICATES------------------------------------------
SELECT patientid, timeof, temparature, COUNT(*) AS cnt
FROM temperature_stage
GROUP BY patientid, timeof, temparature
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

------------ New Script for Handling Duplicates ------
WITH ranked AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY patientid, timeof, temparature
            ORDER BY ctid
        ) AS rn
    FROM temperature_stage
)
DELETE FROM temperature_stage
WHERE ctid IN (
    SELECT ctid
    FROM ranked
    WHERE rn > 1
);


--------------------------------RANGE OF VALUES --------------------------------------------
SELECT
MIN(temparature::numeric),
MAX(temparature::numeric)
FROM temperature_stage;

------------------------------------------CREATE TABLE ---------------------------------------

CREATE TABLE temperature_clean (
    reading_id      SERIAL PRIMARY KEY,
    patient_id      INTEGER NOT NULL,
    timestamp       TIMESTAMP NOT NULL,
    temperature_c   DECIMAL(6,2) NOT NULL,
    temp_anomaly    BOOLEAN DEFAULT FALSE,

    CONSTRAINT fk_temperature_patient
        FOREIGN KEY (patient_id)
        REFERENCES demography_clean(patient_id)
);

INSERT INTO temperature_clean (
    patient_id,
    timestamp,
    temperature_c
)
SELECT
    patientid::INTEGER,
    timeof::TIMESTAMP,
    temparature::DECIMAL(6,2)
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY patientid, timeof, temparature
               ORDER BY ctid
           ) AS rn
    FROM temperature_stage
) t
WHERE rn = 1;



-------FEATURE CREATION ANAMOLY -----------------

-- Flag anomalous skin temperature readings
-- Empatica E4 measures SKIN temperature not body temperature
-- Normal skin temperature range: 20-40 Celsius
-- Values below 20C indicate sensor detachment (device removed)
-- Data exploration found only 12 readings below 20C
-- All values above 40C: 0 rows found in exploration

UPDATE temperature_clean
SET temp_anomaly = TRUE
WHERE temperature_c < 20 OR temperature_c > 40;


-- ============================================================
-- INDEXES
-- Purpose: Improve query performance on large sensor tables
-- All sensor tables queried primarily by patient_id and timestamp
-- Composite indexes handle the most common query pattern:
-- WHERE patient_id = X AND timestamp BETWEEN Y AND Z
-- ============================================================

-- dexcom_clean (36,898 rows)
CREATE INDEX idx_dexcom_patient    ON dexcom_clean(patient_id);
CREATE INDEX idx_dexcom_timestamp  ON dexcom_clean(timestamp);
CREATE INDEX idx_dexcom_patient_ts ON dexcom_clean(patient_id, timestamp);

-- hr_clean (9,384,435 rows -- largest table, indexes critical)
CREATE INDEX idx_hr_patient    ON hr_clean(patient_id);
CREATE INDEX idx_hr_timestamp  ON hr_clean(timestamp);
CREATE INDEX idx_hr_patient_ts ON hr_clean(patient_id, timestamp);
CREATE INDEX idx_hr_anomaly    ON hr_clean(hr_anomaly);

-- eda_clean (4,068,518 rows after deduplication)
CREATE INDEX idx_eda_patient    ON eda_clean(patient_id);
CREATE INDEX idx_eda_timestamp  ON eda_clean(timestamp);
CREATE INDEX idx_eda_patient_ts ON eda_clean(patient_id, timestamp);
CREATE INDEX idx_eda_spike      ON eda_clean(eda_spike);

-- ibi_clean (699,512 rows)
CREATE INDEX idx_ibi_patient    ON ibi_clean(patient_id);
CREATE INDEX idx_ibi_timestamp  ON ibi_clean(timestamp);
CREATE INDEX idx_ibi_patient_ts ON ibi_clean(patient_id, timestamp);

-- temperature_clean (4,068,504 rows after deduplication)
CREATE INDEX idx_temp_patient    ON temperature_clean(patient_id);
CREATE INDEX idx_temp_timestamp  ON temperature_clean(timestamp);
CREATE INDEX idx_temp_patient_ts ON temperature_clean(patient_id, timestamp);
CREATE INDEX idx_temp_anomaly    ON temperature_clean(temp_anomaly);

-- foodlog_clean
CREATE INDEX idx_foodlog_patient    ON foodlog_clean(patient_id);
CREATE INDEX idx_foodlog_timestamp  ON foodlog_clean(timestamp);
CREATE INDEX idx_foodlog_patient_ts ON foodlog_clean(patient_id, timestamp);


-- ============================================================
-- FINAL VALIDATION
-- Purpose: Confirm all tables loaded correctly
-- ============================================================
SELECT 'demography_clean'  AS table_name, COUNT(*) AS row_count FROM demography_clean  UNION ALL
SELECT 'dexcom_clean',                    COUNT(*)              FROM dexcom_clean       UNION ALL
SELECT 'hr_clean',                        COUNT(*)              FROM hr_clean           UNION ALL
SELECT 'eda_clean',                       COUNT(*)              FROM eda_clean          UNION ALL
SELECT 'ibi_clean',                       COUNT(*)              FROM ibi_clean          UNION ALL
SELECT 'temperature_clean',               COUNT(*)              FROM temperature_clean  UNION ALL
SELECT 'foodlog_clean',                   COUNT(*)              FROM foodlog_clean;

-----------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------
