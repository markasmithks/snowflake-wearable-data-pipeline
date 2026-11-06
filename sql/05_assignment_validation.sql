-- 05_assignment_validation.sql
-- Demonstrate detection of overlapping device assignments.

USE DATABASE WEARABLE_DEMO;
USE SCHEMA RAW;

-- =====================================================
-- 1. Optional test: introduce overlapping assignments
-- =====================================================
-- S500 is already assigned to A102 beginning 2026-10-12.
-- This additional assignment to A103 creates an overlap.
-- Uncomment only when intentionally testing conflicts.

-- INSERT INTO DEVICE_ASSIGNMENTS
--     (ANIMAL_ID, DEVICE_ID,
--      ASSIGNMENT_START, ASSIGNMENT_END)
-- VALUES
--     ('A103', 'S500', '2026-10-12', '2026-10-15');


-- =====================================================
-- 2. Inspect historical device assignments
-- =====================================================

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
WHERE r.DEVICE_ID = 'S500'
ORDER BY r.EVENT_TIMESTAMP, a.ANIMAL_ID;


-- =====================================================
-- 3. Detect ambiguous readings
-- =====================================================

SELECT
    r.READING_ID,
    r.DEVICE_ID,
    r.EVENT_TIMESTAMP,
    COUNT(a.ASSIGNMENT_ID) AS MATCH_COUNT
FROM SENSOR_READINGS r
LEFT JOIN DEVICE_ASSIGNMENTS a
    ON r.DEVICE_ID = a.DEVICE_ID
    AND r.EVENT_TIMESTAMP >= a.ASSIGNMENT_START
    AND (
        r.EVENT_TIMESTAMP < a.ASSIGNMENT_END
        OR a.ASSIGNMENT_END IS NULL
    )
GROUP BY
    r.READING_ID,
    r.DEVICE_ID,
    r.EVENT_TIMESTAMP
HAVING COUNT(a.ASSIGNMENT_ID) > 1;
