
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

FILE_PATH = (
    BASE_DIR
    / "dataset"
    / "processed"
    / "bank_transactions_cleaned.csv"
)

CHUNK_SIZE = 200_000

total_rows = 0
transaction_ids = set()
duplicate_ids = 0

missing_counts = {}
dob_status_counts = {}
gender_counts = {}

invalid_dates = 0
invalid_times = 0
negative_amounts = 0
negative_balances = 0

zero_amounts = 0
zero_balances = 0

min_date = None
max_date = None

print("=" * 65)
print("CLEANED DATASET VALIDATION")
print("=" * 65)

if not FILE_PATH.exists():
    print("ERROR: Cleaned dataset not found.")
    raise SystemExit(1)

for chunk_number, chunk in enumerate(
    pd.read_csv(FILE_PATH, chunksize=CHUNK_SIZE),
    start=1,
):

    print(f"\nValidating chunk {chunk_number}...")

    total_rows += len(chunk)

    # 1. Transaction ID uniqueness
    ids = chunk["transaction_id"].astype(str)

    duplicate_ids += int(ids.isin(transaction_ids).sum())
    transaction_ids.update(ids.unique())

    # 2. Missing values
    for column in chunk.columns:
        missing_counts[column] = (
            missing_counts.get(column, 0)
            + int(chunk[column].isna().sum())
        )

    # 3. DOB status distribution
    for key, value in chunk["dob_status"].value_counts().items():
        dob_status_counts[key] = (
            dob_status_counts.get(key, 0) + int(value)
        )

    # 4. Gender distribution
    for key, value in chunk["gender"].value_counts().items():
        gender_counts[key] = (
            gender_counts.get(key, 0) + int(value)
        )

    # 5. Transaction date validation
    dates = pd.to_datetime(
        chunk["transaction_date"],
        format="%Y-%m-%d",
        errors="coerce",
    )

    invalid_dates += int(dates.isna().sum())

    if dates.notna().any():
        chunk_min = dates.min()
        chunk_max = dates.max()

        min_date = (
            chunk_min if min_date is None
            else min(min_date, chunk_min)
        )

        max_date = (
            chunk_max if max_date is None
            else max(max_date, chunk_max)
        )

    # 6. Transaction time validation
    times = pd.to_datetime(
        chunk["transaction_time"],
        format="%H:%M:%S",
        errors="coerce",
    )

    invalid_times += int(times.isna().sum())

    # 7. Numeric checks
    amounts = pd.to_numeric(
        chunk["transaction_amount"],
        errors="coerce",
    )

    balances = pd.to_numeric(
        chunk["account_balance"],
        errors="coerce",
    )

    negative_amounts += int((amounts < 0).sum())
    negative_balances += int((balances < 0).sum())

    zero_amounts += int((amounts == 0).sum())
    zero_balances += int((balances == 0).sum())


# ============================================================
# FINAL VALIDATION REPORT
# ============================================================

print("\n" + "=" * 65)
print("FINAL VALIDATION REPORT")
print("=" * 65)

print(f"\nTotal rows: {total_rows:,}")
print(f"Unique transaction IDs: {len(transaction_ids):,}")
print(f"Duplicate transaction IDs: {duplicate_ids:,}")

print("\nDATE RANGE")
print(f"Minimum date: {min_date}")
print(f"Maximum date: {max_date}")

print("\nINVALID VALUES")
print(f"Invalid transaction dates: {invalid_dates:,}")
print(f"Invalid transaction times: {invalid_times:,}")
print(f"Negative transaction amounts: {negative_amounts:,}")
print(f"Negative account balances: {negative_balances:,}")

print("\nZERO VALUES")
print(f"Zero transaction amounts: {zero_amounts:,}")
print(f"Zero account balances: {zero_balances:,}")

print("\nDOB STATUS")
for key, value in dob_status_counts.items():
    print(f"{key}: {value:,}")

print("\nGENDER DISTRIBUTION")
for key, value in gender_counts.items():
    print(f"{key}: {value:,}")

print("\nMISSING VALUES")
for key, value in missing_counts.items():
    if value > 0:
        print(f"{key}: {value:,}")

print("\n" + "=" * 65)
print("VALIDATION COMPLETED")
print("=" * 65)
