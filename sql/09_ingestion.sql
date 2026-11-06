-- 09_ingestion.sql
-- Configure the internal stage used by the Python ingestion script.

USE DATABASE WEARABLE_DEMO;
USE SCHEMA RAW;

-- Create the landing area for incoming CSV files.
CREATE STAGE IF NOT EXISTS SENSOR_STAGE
    FILE_FORMAT = (
        TYPE = CSV
        SKIP_HEADER = 1
        FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    );

-- Verify stage configuration.
SHOW STAGES LIKE 'SENSOR_STAGE' IN SCHEMA RAW;


-- =====================================================
-- OPTIONAL DIAGNOSTICS
-- =====================================================

-- List staged files.
-- LIST @RAW.SENSOR_STAGE;

-- Inspect recently loaded readings.
-- SELECT
--     READING_ID,
--     DEVICE_ID,
--     EVENT_TIMESTAMP,
--     ACTIVITY_COUNT,
--     INGESTION_TIMESTAMP
-- FROM RAW.SENSOR_READINGS
-- ORDER BY READING_ID DESC
-- LIMIT 20;


-- =====================================================
-- MANUAL INGESTION EXAMPLE
-- =====================================================
-- Normally performed by ingest_sensor_data.py.
-- Uncomment only for intentional manual ingestion.
-- Set PATTERN to match the intended staged CSV filename.

-- COPY INTO RAW.SENSOR_READINGS
--     (DEVICE_ID, EVENT_TIMESTAMP, ACTIVITY_COUNT)
-- FROM (
--     SELECT
--         $1,
--         TO_TIMESTAMP_NTZ($2),
--         TO_NUMBER($3)
--     FROM @RAW.SENSOR_STAGE
-- )
-- FILE_FORMAT = (
--     TYPE = CSV
--     SKIP_HEADER = 1
--     FIELD_OPTIONALLY_ENCLOSED_BY = '"'
-- )
-- PATTERN = '.*sensor_readings_batch1[.]csv$'
-- ON_ERROR = 'ABORT_STATEMENT';


-- =====================================================
-- OPTIONAL PROCESSING
-- =====================================================

-- CALL CURATED.PROCESS_SENSOR_READINGS();
