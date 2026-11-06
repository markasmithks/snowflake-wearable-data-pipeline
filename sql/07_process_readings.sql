-- 07_process_readings.sql
USE DATABASE WEARABLE_DEMO;

CREATE OR REPLACE PROCEDURE
    CURATED.PROCESS_SENSOR_READINGS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
    BEGIN TRANSACTION;

    -- 1. Remove readings that are no longer valid
    DELETE FROM CURATED.SENSOR_READINGS
    WHERE READING_ID IN (
        SELECT READING_ID
        FROM STAGING.VALIDATED_READINGS
        WHERE VALIDATION_STATUS <> 'VALID'
    );

    -- 2. Insert or update valid readings
    MERGE INTO CURATED.SENSOR_READINGS AS target
    USING (
        SELECT
            READING_ID,
            ANIMAL_ID,
            DEVICE_ID,
            EVENT_TIMESTAMP,
            ACTIVITY_COUNT
        FROM STAGING.VALIDATED_READINGS
        WHERE VALIDATION_STATUS = 'VALID'
    ) AS source
    ON target.READING_ID = source.READING_ID

    WHEN MATCHED THEN UPDATE SET
        target.ANIMAL_ID = source.ANIMAL_ID,
        target.DEVICE_ID = source.DEVICE_ID,
        target.EVENT_TIMESTAMP = source.EVENT_TIMESTAMP,
        target.ACTIVITY_COUNT = source.ACTIVITY_COUNT

    WHEN NOT MATCHED THEN INSERT (
        READING_ID,
        ANIMAL_ID,
        DEVICE_ID,
        EVENT_TIMESTAMP,
        ACTIVITY_COUNT
    )
    VALUES (
        source.READING_ID,
        source.ANIMAL_ID,
        source.DEVICE_ID,
        source.EVENT_TIMESTAMP,
        source.ACTIVITY_COUNT
    );

    -- 3. Insert or update rejected readings
    MERGE INTO CURATED.REJECTED_READINGS AS target
    USING (
        SELECT
            READING_ID,
            DEVICE_ID,
            EVENT_TIMESTAMP,
            ACTIVITY_COUNT,
            VALIDATION_STATUS AS REJECTION_REASON
        FROM STAGING.VALIDATED_READINGS
        WHERE VALIDATION_STATUS <> 'VALID'
    ) AS source
    ON target.READING_ID = source.READING_ID

    WHEN MATCHED THEN UPDATE SET
        target.DEVICE_ID = source.DEVICE_ID,
        target.EVENT_TIMESTAMP = source.EVENT_TIMESTAMP,
        target.ACTIVITY_COUNT = source.ACTIVITY_COUNT,
        target.REJECTION_REASON = source.REJECTION_REASON

    WHEN NOT MATCHED THEN INSERT (
        READING_ID,
        DEVICE_ID,
        EVENT_TIMESTAMP,
        ACTIVITY_COUNT,
        REJECTION_REASON
    )
    VALUES (
        source.READING_ID,
        source.DEVICE_ID,
        source.EVENT_TIMESTAMP,
        source.ACTIVITY_COUNT,
        source.REJECTION_REASON
    );

    -- 4. Remove resolved rejections
    DELETE FROM CURATED.REJECTED_READINGS
    WHERE READING_ID IN (
        SELECT READING_ID
        FROM STAGING.VALIDATED_READINGS
        WHERE VALIDATION_STATUS = 'VALID'
    );

    COMMIT;

    RETURN 'Processing completed successfully';

EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;

-- =====================================================
-- OPTIONAL VERIFICATION
-- =====================================================
-- Execute after loading sensor data.

-- CALL CURATED.PROCESS_SENSOR_READINGS();

-- SELECT COUNT(*) AS CURATED_COUNT
-- FROM CURATED.SENSOR_READINGS;

-- SELECT COUNT(*) AS REJECTED_COUNT
-- FROM CURATED.REJECTED_READINGS;

-- Repeat the procedure call to test repeatability.
-- CALL CURATED.PROCESS_SENSOR_READINGS();
