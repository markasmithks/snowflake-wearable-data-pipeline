import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

# Reproducuble synthetic data
random.seed(6321)

# Output location
output_dir = Path(__file__).parent / "data"
output_dir.mkdir(exist_ok=True)

output_file = output_dir / "sensor_readings_batch3.csv"


# Starting timestamp
start_time = datetime(2026, 10, 16, 12, 0)

# Generate sensor measurements
with open(output_file, "w", newline="") as file:
    writer = csv.writer(file)

    writer.writerow([
        "DEVICE_ID",
        "EVENT_TIMESTAMP",
        "ACTIVITY_COUNT"
    ])

    for i in range(20):
        device_id = random.choice(["S500", "S725"])
        event_time = start_time + timedelta(minutes=30 * i)
        activity_count = random.randint(0, 500)

        writer.writerow([
            device_id,
            event_time.strftime("%Y-%m-%d %H:%M:%S"),
            activity_count
        ])

print(f"Generated 20 readings: {output_file}")