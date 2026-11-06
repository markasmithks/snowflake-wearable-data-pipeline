-- 08_automation.sql
-- Schedule automated processing of sensor readings.
-- The task calls CURATED.PROCESS_SENSOR_READINGS()
-- every five minutes when enabled.

USE DATABASE WEARABLE_DEMO;

-- =====================================================
-- 1. Create the scheduled task
-- =====================================================
-- Replace TEST_WH with an available warehouse.

CREATE OR REPLACE TASK CURATED.PROCESS_READINGS_TASK
    WAREHOUSE = TEST_WH
    SCHEDULE = '5 MINUTES'
AS
    CALL CURATED.PROCESS_SENSOR_READINGS();


-- =====================================================
-- 2. Keep the task suspended by default
-- =====================================================
-- Avoid unnecessary compute usage in a demo environment.

ALTER TASK CURATED.PROCESS_READINGS_TASK SUSPEND;


-- =====================================================
-- 3. Verify task configuration
-- =====================================================

SHOW TASKS LIKE 'PROCESS_READINGS_TASK'
IN SCHEMA CURATED;


-- =====================================================
-- 4. Optional manual execution
-- =====================================================
-- Run only when intentionally testing the task.

-- EXECUTE TASK CURATED.PROCESS_READINGS_TASK;


-- =====================================================
-- 5. Inspect task execution history
-- =====================================================

SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'PROCESS_READINGS_TASK',
        RESULT_LIMIT => 10
    )
)
ORDER BY SCHEDULED_TIME DESC;


-- =====================================================
-- 6. Verify processed data
-- =====================================================

SELECT COUNT(*) AS CURATED_COUNT
FROM CURATED.SENSOR_READINGS;

SELECT COUNT(*) AS REJECTED_COUNT
FROM CURATED.REJECTED_READINGS;


-- =====================================================
-- 7. Optional: enable scheduled processing
-- =====================================================
-- Enabling this task may incur compute charges.

-- ALTER TASK CURATED.PROCESS_READINGS_TASK RESUME;
