# Data Validation and Testing

## Purpose

This document describes the validation rules and observed test results for the Snowflake wearable sensor data pipeline.

The project uses synthetic animal activity data to demonstrate data quality checks, historical device attribution, rejected-record handling, and repeatable ingestion.

## 1. Validation Rules

The `STAGING.VALIDATED_READINGS` view evaluates each incoming sensor reading.

| Validation Status | Condition |
|---|---|
| `VALID` | Valid measurement with exactly one matching historical device assignment |
| `MISSING_TIMESTAMP` | Event timestamp is NULL |
| `INVALID_ACTIVITY` | Activity count is NULL or negative |
| `NO_DEVICE_ASSIGNMENT` | No device assignment matches the event timestamp |
| `OVERLAPPING_ASSIGNMENTS` | Multiple assignments match the event timestamp |

Historical device assignments use inclusive start timestamps and exclusive end timestamps.

This prevents a reading at the exact moment of reassignment from matching both the previous and new assignment, provided the assignment intervals do not overlap.

## 2. Observed Ingestion Results

Three batches of synthetic sensor readings were successfully processed through the Python ingestion pipeline.

| Metric | Observed Result |
|---|---:|
| RAW sensor readings | 67 |
| Curated sensor readings | 64 |
| Rejected sensor readings | 3 |

These results demonstrate that the pipeline separates accepted and rejected records.

## 3. Repeated File Ingestion

The third CSV batch was submitted a second time using `ingest_sensor_data.py`.

Observed results:

- The staged file upload was skipped.
- Snowflake `COPY INTO` processed zero new files.
- Zero new readings were loaded.
- The processing procedure was skipped.
- Curated and rejected record counts remained unchanged.

This demonstrates file-level duplicate-load protection for the tested scenario.

It does not guarantee event-level deduplication if identical sensor events arrive in differently named files.

## 4. Historical Device Assignment Validation

The pipeline uses temporal SQL joins to associate each sensor reading with the animal assigned to the device when the event occurred.

A device may be reassigned to another animal over time.

The validation logic counts matching assignments rather than assuming every reading has exactly one match.

If no assignment matches, the reading is rejected with `NO_DEVICE_ASSIGNMENT`.

If multiple assignments match, the reading is rejected with `OVERLAPPING_ASSIGNMENTS`.

This prevents ambiguous readings from being arbitrarily attributed to an animal.

## 5. Reconciliation Design

The `CURATED.PROCESS_SENSOR_READINGS()` stored procedure is designed to reconcile previously processed readings when assignment history changes.

Its operations are:

1. Remove readings from the curated table when they become invalid.
2. Insert or update valid readings in the curated table.
3. Insert or update invalid readings in the rejected table.
4. Remove obsolete rejection records when readings become valid.

These operations execute within a transaction with rollback handling.

The validation view reflects source-data changes when queried. The curated and rejected tables are reconciled when the stored procedure executes.

## 6. Reconciliation Test — Observed Results

A controlled test was performed using five readings from device `S500` between October 12 and October 15, 2026.

**Initial state:** Device `S500` was assigned to animal `A102`. All five readings were classified as `VALID`, with exactly one matching assignment.

**Conflict introduced:** A temporary assignment was inserted for animal `A103`, overlapping the existing assignment.

The validation view returned:

- 5 readings classified as `OVERLAPPING_ASSIGNMENTS`.
- `MATCH_COUNT = 2` for each reading.

After executing `CURATED.PROCESS_SENSOR_READINGS()`:

- All five readings were removed from `CURATED.SENSOR_READINGS`.
- All five appeared in `CURATED.REJECTED_READINGS` with rejection reason `OVERLAPPING_ASSIGNMENTS`.

**Conflict corrected:** The temporary assignment was deleted, and the stored procedure was executed again.

The final verification returned:

| Reading ID | Final Location | Rejection Reason |
|---|---|---|
| 4 | CURATED | NULL |
| 201 | CURATED | NULL |
| 206 | CURATED | NULL |
| 207 | CURATED | NULL |
| 214 | CURATED | NULL |

**Result: PASS**

The pipeline successfully reclassified previously accepted readings, rejected them during an assignment conflict, and restored them after the conflict was resolved.

This test verifies historical assignment reconciliation for the five selected records. It does not establish correctness under concurrent processing or large-scale workloads.

## 7. Limitations and Future Improvements

This project is a learning and portfolio demonstration, not a production-ready system.

Potential improvements include:

- Automated assertions for each validation category.
- Event-level deduplication using stable source-event identifiers.
- More efficient incremental processing for larger datasets.
- Avoiding unnecessary updates when records are unchanged.
- Testing concurrent changes to assignment history during processing.
- Implementing least-privilege Snowflake access controls.
