-- 06_validation_pipeline.sql
-- Validate sensor readings using historical device assignments.
-- The view automatically reflects changes in assignment history.

USE DATABASE WEARABLE_DEMO;

CREATE OR REPLACE VIEW STAGING.VALIDATED_READINGS AS

WITH ASSIGNMENT_MATCHES AS (
    SELECT
        r.READING_ID,
        r.DEVICE_ID,
        r.EVENT_TIMESTAMP,
        r.ACTIVITY_COUNT,
        COUNT(a.ASSIGNMENT_ID) AS MATCH_COUNT,
        MAX(a.ANIMAL_ID) AS ANIMAL_ID

    FROM RAW.SENSOR_READINGS r

    LEFT JOIN RAW.DEVICE_ASSIGNMENTS a
        ON r.DEVICE_ID = a.DEVICE_ID
        AND r.EVENT_TIMESTAMP >= a.ASSIGNMENT_START
        AND (
            r.EVENT_TIMESTAMP < a.ASSIGNMENT_END
            OR a.ASSIGNMENT_END IS NULL
        )

    GROUP BY
        r.READING_ID,
        r.DEVICE_ID,
        r.EVENT_TIMESTAMP,
        r.ACTIVITY_COUNT
)

SELECT
    *,
    CASE
        WHEN EVENT_TIMESTAMP IS NULL
            THEN 'MISSING_TIMESTAMP'
        WHEN ACTIVITY_COUNT IS NULL
             OR ACTIVITY_COUNT < 0
            THEN 'INVALID_ACTIVITY'
        WHEN MATCH_COUNT = 0
            THEN 'NO_DEVICE_ASSIGNMENT'
        WHEN MATCH_COUNT > 1
            THEN 'OVERLAPPING_ASSIGNMENTS'
        ELSE 'VALID'
    END AS VALIDATION_STATUS

FROM ASSIGNMENT_MATCHES;


-- =====================================================
-- Verify validation results
-- =====================================================

SELECT
    READING_ID,
    DEVICE_ID,
    ANIMAL_ID,
    MATCH_COUNT,
    VALIDATION_STATUS
FROM STAGING.VALIDATED_READINGS
ORDER BY READING_ID;


/*
RECOVERY SCENARIO

1. A reading is initially valid and enters CURATED.SENSOR_READINGS.

2. A conflicting device assignment is introduced.
   The validation view identifies multiple matching assignments
   and classifies the reading as OVERLAPPING_ASSIGNMENTS.

3. The processing procedure removes the reading from curated
   data and records its rejection.

4. The conflicting assignment is corrected.
   The validation view automatically recognizes the correction.

5. The processing procedure restores the valid reading
   to CURATED.SENSOR_READINGS and removes the obsolete rejection.

This demonstrates reconciliation of previously processed data
when historical assignment information changes.
*/
