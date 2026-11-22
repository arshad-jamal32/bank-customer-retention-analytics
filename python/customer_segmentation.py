
import pandas as pd
import psycopg2
from pathlib import Path

# ============================================================
# BANK CUSTOMER RFM SEGMENTATION
# ============================================================

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_DIR = BASE_DIR / "reports"
OUTPUT_DIR.mkdir(exist_ok=True)

# PostgreSQL connection
import os
from dotenv import load_dotenv

load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "bank_customer_analytics"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
    "port": int(os.getenv("DB_PORT", 5432))
}


def main():
    print("=" * 65)
    print("BANK CUSTOMER RFM SEGMENTATION")
    print("=" * 65)

    # Connect to PostgreSQL
    connection = psycopg2.connect(**DB_CONFIG)

    query = """
        SELECT
            customer_id,
            MAX(transaction_date) AS last_transaction_date,
            COUNT(*) AS frequency,
            SUM(transaction_amount) AS monetary
        FROM bank_transactions
        GROUP BY customer_id;
    """

    df = pd.read_sql_query(query, connection)
    connection.close()

    print(f"\nTotal customers fetched: {len(df):,}")

    # Reference date = latest date in the dataset
    reference_date = pd.Timestamp("2016-10-21")

    df["recency"] = (
        reference_date - pd.to_datetime(df["last_transaction_date"])
    ).dt.days

    # RFM scoring: analyst-defined thresholds
    df["recency_score"] = df["recency"].apply(
        lambda x: 5 if x <= 7 else
        4 if x <= 30 else
        3 if x <= 60 else
        2 if x <= 90 else 1
    )

    df["frequency_score"] = df["frequency"].apply(
        lambda x: 5 if x >= 6 else
        4 if x >= 4 else
        3 if x >= 2 else 1
    )

    df["monetary_score"] = df["monetary"].apply(
        lambda x: 5 if x > 50000 else
        4 if x > 10000 else
        3 if x > 2000 else
        2 if x > 500 else 1
    )

    df["rfm_score"] = (
        df["recency_score"]
        + df["frequency_score"]
        + df["monetary_score"]
    )

    # Customer segmentation: same priority as SQL Query 7
    conditions = [
        (
            (df["recency_score"] >= 4)
            & (df["frequency_score"] >= 4)
            & (df["monetary_score"] >= 4)
        ),
        (
            (df["recency_score"] >= 4)
            & (df["frequency_score"] >= 3)
        ),
        (
            (df["recency_score"] >= 3)
            & (df["frequency_score"] >= 3)
        ),
        (
            (df["recency_score"] <= 2)
            & (df["frequency_score"] >= 3)
        ),
        df["frequency_score"] == 1
    ]

    segments = [
        "High Value Customers",
        "Potential Customers",
        "Regular Customers",
        "At Risk - Inactivity Proxy",
        "Low Engagement Customers"
    ]

    df["customer_segment"] = pd.Series(
        pd.NA, index=df.index, dtype="object"
    )

    for condition, segment in zip(conditions, segments):
        df.loc[
            df["customer_segment"].isna() & condition,
            "customer_segment"
        ] = segment

    df["customer_segment"] = df["customer_segment"].fillna(
        "Other Customers"
    )

    # Save customer-level segmentation
    customer_file = OUTPUT_DIR / "customer_rfm_segments.csv"
    df.to_csv(customer_file, index=False)

    # Segment summary
    summary = (
        df.groupby("customer_segment")
        .agg(
            total_customers=("customer_id", "count"),
            total_transaction_value=("monetary", "sum"),
            average_customer_value=("monetary", "mean"),
            average_recency=("recency", "mean"),
            average_frequency=("frequency", "mean")
        )
        .reset_index()
    )

    summary["customer_percentage"] = (
        summary["total_customers"] / len(df) * 100
    )

    summary = summary.sort_values(
        "total_customers", ascending=False
    )

    summary_file = OUTPUT_DIR / "rfm_segment_summary.csv"
    summary.to_csv(summary_file, index=False)

    # Display results
    print("\nRFM SEGMENT SUMMARY")
    print("-" * 65)

    print(
        summary.to_string(
            index=False,
            formatters={
                "total_transaction_value": "{:,.2f}".format,
                "average_customer_value": "{:,.2f}".format,
                "average_recency": "{:.2f}".format,
                "average_frequency": "{:.2f}".format,
                "customer_percentage": "{:.2f}%".format
            }
        )
    )

    print("\n" + "=" * 65)
    print("RFM SEGMENTATION COMPLETED SUCCESSFULLY")
    print(f"Customer-level file: {customer_file}")
    print(f"Segment summary: {summary_file}")
    print("=" * 65)


if __name__ == "__main__":
    main()