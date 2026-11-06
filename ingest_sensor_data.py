#######################
#
# ingest_sensor_data.py
#
#######################
import os
import re
import argparse
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv
from cryptography.hazmat.primitives import serialization

# File to ingest
parser = argparse.ArgumentParser(
    description="Load wearable sensor readings into Snowflake"
)

parser.add_argument(
    "filename",
    help="CSV filename located in the data folder"
)

args = parser.parse_args()

csv_path = Path(__file__).parent / "data" / args.filename

if not csv_path.is_file():
    raise FileNotFoundError(csv_path)


# Load environment variables
load_dotenv()

# Location of encrypted private key
key_path = Path(__file__).parent / "keys" / "rsa_key.p8"

# Read and decrypt private key
with open(key_path, "rb") as key_file:
    private_key = serialization.load_pem_private_key(
        key_file.read(),
        password=os.environ["SNOWFLAKE_KEY_PASSPHRASE"].encode()
    )

# Convert to DER format for Snowflake
private_key_der = private_key.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)

# Connect to Snowflake
conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    private_key=private_key_der,
    warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
    database=os.environ["SNOWFLAKE_DATABASE"],
    schema=os.environ["SNOWFLAKE_SCHEMA"],
    role=os.environ["SNOWFLAKE_ROLE"]
)




try:
    with conn.cursor() as cursor:

        # 1. Upload CSV to Snowflake
        print("Uploading CSV to Snowflake...")

        put_sql = f"""
            PUT 'file://{csv_path.as_posix()}'
            @RAW.SENSOR_STAGE
            AUTO_COMPRESS = FALSE
            OVERWRITE = FALSE
        """

        cursor.execute(put_sql)
        print("PUT:", cursor.fetchall())

        # 2. Load staged data into RAW
        print("Loading RAW sensor readings...")

        filename_pattern = re.escape(csv_path.name)

        cursor.execute(f"""
            COPY INTO RAW.SENSOR_READINGS
                (DEVICE_ID, EVENT_TIMESTAMP, ACTIVITY_COUNT)
            FROM (
                SELECT
                    $1,
                    TO_TIMESTAMP_NTZ($2),
                    TO_NUMBER($3)
                FROM @RAW.SENSOR_STAGE
            )
            FILE_FORMAT = (
                TYPE = CSV
                SKIP_HEADER = 1
                FIELD_OPTIONALLY_ENCLOSED_BY = '"'
            )
            PATTERN = '.*{filename_pattern}$'
            ON_ERROR = 'ABORT_STATEMENT'
        """)

        copy_results = cursor.fetchall()

        for result in copy_results:
            print("COPY:", result)

        rows_loaded = sum(
            row[3]
            for row in copy_results
            if len(row) > 3 and row[1] == "LOADED"
        )

        print(f"New rows loaded: {rows_loaded}")

        # 3. Run transactional processing
        if rows_loaded > 0:
            print("Processing sensor readings...")

            cursor.execute(
                "CALL CURATED.PROCESS_SENSOR_READINGS()"
            )

            print("PROCEDURE:", cursor.fetchone())
        else:
            print("No new readings. Skipping processing.")

        # 4. Report results
        cursor.execute("""
            SELECT COUNT(*)
            FROM CURATED.SENSOR_READINGS
        """)
        curated_count = cursor.fetchone()[0]

        cursor.execute("""
            SELECT COUNT(*)
            FROM CURATED.REJECTED_READINGS
        """)
        rejected_count = cursor.fetchone()[0]

        print(f"Curated readings: {curated_count}")
        print(f"Rejected readings: {rejected_count}")

finally:
    conn.close()
