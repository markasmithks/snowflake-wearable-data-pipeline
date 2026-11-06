-- 02a_seed_data.sql
-- Populate RAW tables with synthetic demonstration data.
-- MERGE prevents duplicate inserts on repeated execution.

USE DATABASE WEARABLE_DEMO;
USE SCHEMA RAW;

-- 1. Animals
MERGE INTO ANIMALS AS target
USING (
    SELECT
        column1 AS ANIMAL_ID,
        column2 AS ANIMAL_NAME,
        column3 AS SPECIES,
        column4 AS BREED
    FROM VALUES
        ('A101', 'Buddy', 'Dog', 'Labrador'),
        ('A102', 'Luna', 'Dog', 'Beagle'),
        ('A103', 'Max', 'Dog', 'Golden Retriever')
) AS source
ON target.ANIMAL_ID = source.ANIMAL_ID
WHEN NOT MATCHED THEN
    INSERT (ANIMAL_ID, ANIMAL_NAME, SPECIES, BREED)
    VALUES (
        source.ANIMAL_ID,
        source.ANIMAL_NAME,
        source.SPECIES,
        source.BREED
    );

-- 2. Devices
MERGE INTO DEVICES AS target
USING (
    SELECT
        column1 AS DEVICE_ID,
        column2 AS MANUFACTURER,
        column3 AS DEVICE_TYPE
    FROM VALUES
        ('S500', 'DemoSensors', 'Activity Collar'),
        ('S725', 'DemoSensors', 'Activity Collar')
) AS source
ON target.DEVICE_ID = source.DEVICE_ID
WHEN NOT MATCHED THEN
    INSERT (DEVICE_ID, MANUFACTURER, DEVICE_TYPE)
    VALUES (
        source.DEVICE_ID,
        source.MANUFACTURER,
        source.DEVICE_TYPE
    );

-- 3. Historical device assignments
MERGE INTO DEVICE_ASSIGNMENTS AS target
USING (
    SELECT
        column1 AS ANIMAL_ID,
        column2 AS DEVICE_ID,
        column3::TIMESTAMP_NTZ AS ASSIGNMENT_START,
        column4::TIMESTAMP_NTZ AS ASSIGNMENT_END
    FROM VALUES
        ('A101', 'S500', '2026-10-01', '2026-10-11'),
        ('A101', 'S725', '2026-10-11', NULL),
        ('A102', 'S500', '2026-10-12', NULL)
) AS source
ON target.ANIMAL_ID = source.ANIMAL_ID
   AND target.DEVICE_ID = source.DEVICE_ID
   AND target.ASSIGNMENT_START = source.ASSIGNMENT_START
WHEN NOT MATCHED THEN
    INSERT (
        ANIMAL_ID,
        DEVICE_ID,
        ASSIGNMENT_START,
        ASSIGNMENT_END
    )
    VALUES (
        source.ANIMAL_ID,
        source.DEVICE_ID,
        source.ASSIGNMENT_START,
        source.ASSIGNMENT_END
    );

-- 4. Sample sensor readings
MERGE INTO SENSOR_READINGS AS target
USING (
    SELECT
        column1 AS DEVICE_ID,
        column2::TIMESTAMP_NTZ AS EVENT_TIMESTAMP,
        column3 AS ACTIVITY_COUNT
    FROM VALUES
        ('S500', '2026-10-05 12:00:00', 125),
        ('S500', '2026-10-10 14:00:00', 200),
        ('S500', '2026-10-11 15:00:00', 175),
        ('S500', '2026-10-13 09:00:00', 300),
        ('S725', '2026-10-14 10:00:00', 250)
) AS source
ON target.DEVICE_ID = source.DEVICE_ID
   AND target.EVENT_TIMESTAMP = source.EVENT_TIMESTAMP
   AND target.ACTIVITY_COUNT = source.ACTIVITY_COUNT
WHEN NOT MATCHED THEN
    INSERT (
        DEVICE_ID,
        EVENT_TIMESTAMP,
        ACTIVITY_COUNT
    )
    VALUES (
        source.DEVICE_ID,
        source.EVENT_TIMESTAMP,
        source.ACTIVITY_COUNT
    );


-- =====================================================
-- DEMONSTRATION QUERY: Historical Device Assignment
-- =====================================================
-- Associates each sensor reading with the animal
-- assigned to that device at the event timestamp.
-- Uses half-open intervals [START, END).
-- This query is for inspection, not data modification.

-- TEMPORAL JOIN
SELECT
    r.READING_ID,
    r.DEVICE_ID,
    r.EVENT_TIMESTAMP,
    r.ACTIVITY_COUNT,
    a.ANIMAL_ID
FROM SENSOR_READINGS r
LEFT JOIN DEVICE_ASSIGNMENTS a
    ON r.DEVICE_ID = a.DEVICE_ID
    AND r.EVENT_TIMESTAMP >= a.ASSIGNMENT_START
    AND (
        r.EVENT_TIMESTAMP < a.ASSIGNMENT_END
        OR a.ASSIGNMENT_END IS NULL
    )
ORDER BY r.EVENT_TIMESTAMP;