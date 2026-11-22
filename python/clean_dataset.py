import pandas as pd
from pathlib import Path

# ============================================================
# BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
# DATA CLEANING AND PREPARATION
# ============================================================

BASE_DIR = Path(__file__).resolve().parent.parent

INPUT_FILE = BASE_DIR / "dataset" / "raw" / "bank_transactions.csv"
OUTPUT_FILE = BASE_DIR / "dataset" / "processed" / "bank_transactions_cleaned.csv"

CHUNK_SIZE = 200_000


def calculate_age(dob, transaction_date):
    """Calculate age on the transaction date."""
    age = transaction_date.dt.year - dob.dt.year

    birthday_not_reached = (transaction_date.dt.month < dob.dt.month) | (
        (transaction_date.dt.month == dob.dt.month)
        & (transaction_date.dt.day < dob.dt.day)
    )

    return age - birthday_not_reached.astype("int64")


def clean_dob(raw_dob, transaction_date):
    """
    Interpret two-digit DOB years using a documented assumption:
    choose the latest candidate DOB that is not after the transaction
    date and produces an age between 0 and 100.
    """

    raw = raw_dob.astype("string").str.strip()

    # Identify the known 1800 placeholder.
    placeholder = raw.eq("1/1/1800").fillna(False)

    # Extract only DOBs with the expected D/M/YY format.
    parts = raw.str.extract(r"^(\d{1,2})/(\d{1,2})/(\d{2})$")

    format_valid = parts.notna().all(axis=1) & ~placeholder

    day = pd.to_numeric(parts[0], errors="coerce")
    month = pd.to_numeric(parts[1], errors="coerce")
    year = pd.to_numeric(parts[2], errors="coerce")

    # Build candidate dates for both centuries.
    dob_1900 = pd.to_datetime(
        {
            "year": (year + 1900).fillna(1900),
            "month": month.fillna(1),
            "day": day.fillna(1),
        },
        errors="coerce",
    )

    dob_2000 = pd.to_datetime(
        {
            "year": (year + 2000).fillna(2000),
            "month": month.fillna(1),
            "day": day.fillna(1),
        },
        errors="coerce",
    )

    age_1900 = calculate_age(dob_1900, transaction_date)
    age_2000 = calculate_age(dob_2000, transaction_date)

    # IMPORTANT: Candidates are valid only when the original
    # DOB follows the expected two-digit-year format.
    valid_1900 = (
        format_valid
        & dob_1900.notna()
        & transaction_date.notna()
        & (dob_1900 <= transaction_date)
        & age_1900.between(0, 100)
    )

    valid_2000 = (
        format_valid
        & dob_2000.notna()
        & transaction_date.notna()
        & (dob_2000 <= transaction_date)
        & age_2000.between(0, 100)
    )

    # Prefer the latest valid DOB.
    cleaned_dob = dob_1900.where(valid_1900)
    cleaned_dob = dob_2000.where(valid_2000, cleaned_dob)

    # Assign cleaning status.
    status = pd.Series(
        "invalid_format_or_date",
        index=raw.index,
        dtype="string",
    )

    status.loc[raw.isna() | raw.eq("")] = "missing"
    status.loc[placeholder] = "placeholder_1800"

    status.loc[valid_1900 & ~valid_2000] = "assumed_1900s"
    status.loc[valid_2000] = "assumed_2000s"

    unresolved = (
        format_valid
        & dob_1900.notna()
        & dob_2000.notna()
        & transaction_date.notna()
        & ~valid_1900
        & ~valid_2000
    )

    status.loc[unresolved] = "future_or_age_out_of_range"

    return cleaned_dob, status


def main():

    print("=" * 65)
    print("BANK TRANSACTION DATA CLEANING")
    print("=" * 65)

    if not INPUT_FILE.exists():
        print(f"ERROR: Input file not found: {INPUT_FILE}")
        return

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    if OUTPUT_FILE.exists():
        OUTPUT_FILE.unlink()

    total_rows = 0
    dob_status_counts = {}
    missing_counts = {}
    gender_counts = {}

    first_chunk = True

    for chunk_number, chunk in enumerate(
        pd.read_csv(INPUT_FILE, chunksize=CHUNK_SIZE),
        start=1,
    ):

        print(f"\nProcessing chunk {chunk_number}...")

        # ----------------------------------------------------
        # 1. Rename columns
        # ----------------------------------------------------

        chunk.columns = [
            "transaction_id",
            "customer_id",
            "customer_dob_raw",
            "gender",
            "customer_location",
            "account_balance",
            "transaction_date",
            "transaction_time",
            "transaction_amount",
        ]

        # ----------------------------------------------------
        # 2. Clean transaction date
        # ----------------------------------------------------

        chunk["transaction_date"] = pd.to_datetime(
            chunk["transaction_date"],
            format="%d/%m/%y",
            errors="coerce",
        )

        # ----------------------------------------------------
        # 3. Clean customer DOB
        # ----------------------------------------------------

        cleaned_dob, dob_status = clean_dob(
            chunk["customer_dob_raw"],
            chunk["transaction_date"],
        )

        chunk["customer_dob"] = cleaned_dob.dt.strftime("%Y-%m-%d")
        chunk["dob_status"] = dob_status

        for key, value in dob_status.value_counts(dropna=False).items():
            dob_status_counts[str(key)] = dob_status_counts.get(str(key), 0) + int(
                value
            )

        # ----------------------------------------------------
        # 4. Clean gender
        # ----------------------------------------------------

        chunk["gender"] = chunk["gender"].astype("string").str.strip().str.upper()

        chunk["gender"] = chunk["gender"].where(
            chunk["gender"].isin(["M", "F"]),
            "Unknown",
        )

        for key, value in chunk["gender"].value_counts().items():
            gender_counts[str(key)] = gender_counts.get(str(key), 0) + int(value)

        # ----------------------------------------------------
        # 5. Clean customer location
        # ----------------------------------------------------

        chunk["customer_location"] = (
            chunk["customer_location"]
            .astype("string")
            .str.strip()
            .str.upper()
            .replace("", pd.NA)
            .fillna("Unknown")
        )

        # ----------------------------------------------------
        # 6. Convert numeric columns
        # ----------------------------------------------------

        chunk["account_balance"] = pd.to_numeric(
            chunk["account_balance"],
            errors="coerce",
        )

        chunk["transaction_amount"] = pd.to_numeric(
            chunk["transaction_amount"],
            errors="coerce",
        )

        # ----------------------------------------------------
        # 7. Convert transaction time to HH:MM:SS
        # ----------------------------------------------------

        time_numeric = pd.to_numeric(
            chunk["transaction_time"],
            errors="coerce",
        )

        time_string = time_numeric.map(
            lambda x: str(int(x)).zfill(6) if pd.notna(x) else None
        )

        parsed_time = pd.to_datetime(
            time_string,
            format="%H%M%S",
            errors="coerce",
        )

        chunk["transaction_time"] = parsed_time.dt.strftime("%H:%M:%S")

        # ----------------------------------------------------
        # 8. Format transaction date
        # ----------------------------------------------------

        chunk["transaction_date"] = chunk["transaction_date"].dt.strftime("%Y-%m-%d")

        # ----------------------------------------------------
        # 9. Count missing values after cleaning
        # ----------------------------------------------------

        for column in chunk.columns:
            count = int(chunk[column].isna().sum())
            missing_counts[column] = missing_counts.get(column, 0) + count

        # Reorder columns to match PostgreSQL table structure
        chunk = chunk[
            [
                "transaction_id",
                "customer_id",
                "customer_dob_raw",
                "customer_dob",
                "dob_status",
                "gender",
                "customer_location",
                "account_balance",
                "transaction_date",
                "transaction_time",
                "transaction_amount",
            ]
        ]

        # ----------------------------------------------------
        # 10. Save cleaned chunk
        # ----------------------------------------------------

        chunk.to_csv(
            OUTPUT_FILE,
            index=False,
            mode="w" if first_chunk else "a",
            header=first_chunk,
        )

        first_chunk = False
        total_rows += len(chunk)

        print(f"Rows processed: {total_rows:,}")

    # ========================================================
    # FINAL CLEANING REPORT
    # ========================================================

    print("\n" + "=" * 65)
    print("DATA CLEANING COMPLETED")
    print("=" * 65)

    print(f"\nTotal rows processed: {total_rows:,}")

    print("\nDOB CLEANING STATUS")
    for key, value in dob_status_counts.items():
        print(f"{key}: {value:,}")

    print("\nGENDER DISTRIBUTION")
    for key, value in gender_counts.items():
        print(f"{key}: {value:,}")

    print("\nMISSING VALUES AFTER CLEANING")
    for key, value in missing_counts.items():
        if value > 0:
            print(f"{key}: {value:,}")

    print("\nOUTPUT FILE")
    print(OUTPUT_FILE)

    print("\nRaw dataset has not been modified.")
    print("Cleaning process completed successfully.")


if __name__ == "__main__":
    main()
