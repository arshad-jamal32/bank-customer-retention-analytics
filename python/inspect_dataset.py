
import pandas as pd
from collections import Counter

file_path = "dataset/raw/bank_transactions.csv"

dob_patterns = Counter()
unusual_values = Counter()
total_rows = 0
missing_dob = 0

for chunk in pd.read_csv(file_path, chunksize=200_000):

    total_rows += len(chunk)

    dob = chunk["CustomerDOB"].astype("string").str.strip()

    missing_dob += dob.isna().sum()

    # Identify common DOB string patterns
    patterns = dob.dropna().str.extract(
        r"^(\d{1,2})/(\d{1,2})/(\d+)$"
    )

    valid_structure = patterns.notna().all(axis=1)

    dob_patterns.update(
        patterns.loc[valid_structure, 2].value_counts().to_dict()
    )

    # Check DOB values that do not follow expected D/M/YY format
    unusual_mask = (
        dob.notna() &
        ~dob.str.match(r"^\d{1,2}/\d{1,2}/\d{2}$", na=False)
    )

    unusual_values.update(
        dob[unusual_mask].value_counts().to_dict()
    )

print("=" * 65)
print("UNUSUAL DOB INVESTIGATION")
print("=" * 65)

print("\n1. TOTAL RECORDS")
print(f"Total rows: {total_rows:,}")
print(f"Missing DOB: {missing_dob:,}")

print("\n2. DOB YEAR COMPONENT DISTRIBUTION")
for length, count in sorted(dob_patterns.items()):
    print(f"{length} digit(s): {count:,}")

print("\n3. MOST COMMON UNUSUAL DOB VALUES")
for value, count in unusual_values.most_common(20):
    print(f"{value}: {count:,}")

print("\n4. TOTAL UNUSUAL DOB RECORDS")
print(f"{sum(unusual_values.values()):,}")

print("\nINVESTIGATION COMPLETED")
