# Snowflake Wearable Sensor Data Pipeline

## Project Overview

An end-to-end data engineering demonstration using Python and Snowflake to ingest, validate, and process synthetic animal wearable sensor data.

The project simulates activity-monitoring devices that can be reassigned between animals over time. It addresses the challenge of correctly attributing historical sensor readings while identifying invalid or ambiguous records.

## Architecture

```text
Synthetic Sensor Data (Python)
             |
             v
         CSV Files
             |
             v
    Snowflake Internal Stage
             |
             v
       RAW.SENSOR_READINGS
             |
             v
  STAGING.VALIDATED_READINGS
             |
       +-----+-----+
       |           |
       v           v
 Valid Readings  Rejected Readings
       |           |
       v           v
 CURATED.       CURATED.
 SENSOR_READINGS REJECTED_READINGS
```

## Key Features

- Python-based generation and ingestion of synthetic wearable sensor data.
- Snowflake internal staging and `COPY INTO` loading.
- Historical device-to-animal attribution using temporal SQL joins.
- Validation of missing timestamps, invalid activity counts, missing assignments, and overlapping assignments.
- Separation of validated and rejected records.
- Transactional stored procedure using `MERGE`, `COMMIT`, and `ROLLBACK`.
- Reconciliation of previously processed readings when device assignments change.
- File-level duplicate-load protection using Snowflake load history.
- Optional five-minute scheduled processing using Snowflake Tasks.

## Technologies

- Python
- Snowflake SQL
- Snowflake Python Connector
- Git and GitHub

## Repository Structure

```text
Snowflake_Ingestion_Pipeline/
├── generate_sensor_data.py
├── ingest_sensor_data.py
├── requirements.txt
├── .gitignore
└── sql/
    ├── 01_setup.sql
    ├── 02_create_tables.sql
    ├── 02a_seed_data.sql
    ├── 03_curated_tables.sql
    ├── 04_data_quality.sql
    ├── 05_assignment_validation.sql
    ├── 06_validation_pipeline.sql
    ├── 07_process_readings.sql
    ├── 08_automation.sql
    └── 09_ingestion.sql
```

## Data Processing

Each reading is associated with the animal assigned to its device at the event timestamp.

Assignment intervals use an inclusive start and exclusive end. A reading matching multiple assignments is rejected rather than arbitrarily attributed to an animal.

The validation view classifies readings, and a stored procedure synchronizes the curated and rejected tables. This allows records to be reclassified when historical assignments are corrected.

## Automation

The Python ingestion script uploads CSV files, executes Snowflake `COPY INTO`, and invokes the processing procedure when new rows are loaded.

An optional Snowflake Task can independently execute the procedure every five minutes, allowing reconciliation even when no new sensor files arrive.

The task is suspended by default to avoid unnecessary compute charges.

## Implementation Notes

This is a portfolio demonstration using synthetic data, not a production deployment.

File-level duplicate-load protection does not guarantee event-level deduplication when identical readings arrive in differently named files. The processing procedure maintains the intended resulting record classifications but may perform unnecessary updates on repeated execution.

## Security

Snowflake connections use RSA key-pair authentication. Credentials, private keys, local environment files, and generated CSV data are excluded from version control.