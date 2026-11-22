
import pandas as pd
import matplotlib.pyplot as plt
import psycopg2
from pathlib import Path

# ============================================================
# BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
# PYTHON DATA VISUALIZATIONS
# ============================================================

BASE_DIR = Path(__file__).resolve().parent.parent
OUTPUT_DIR = BASE_DIR / "reports" / "visualizations"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

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

# Consistent chart formatting
plt.rcParams["figure.figsize"] = (12, 7)
plt.rcParams["font.size"] = 10
plt.rcParams["axes.titlesize"] = 15
plt.rcParams["axes.titleweight"] = "bold"

def save_chart(filename):
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / filename, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"Created: {filename}")


def main():
    print("=" * 65)
    print("BANK CUSTOMER ANALYTICS - PYTHON VISUALIZATIONS")
    print("=" * 65)

    connection = psycopg2.connect(**DB_CONFIG)

    # --------------------------------------------------------
    # 1. TRANSACTION AMOUNT DISTRIBUTION
    # --------------------------------------------------------
    query = """
        SELECT
            CASE
                WHEN transaction_amount = 0 THEN 'Zero'
                WHEN transaction_amount <= 500 THEN '1-500'
                WHEN transaction_amount <= 1000 THEN '501-1000'
                WHEN transaction_amount <= 5000 THEN '1001-5000'
                WHEN transaction_amount <= 10000 THEN '5001-10000'
                WHEN transaction_amount <= 50000 THEN '10001-50000'
                ELSE 'Above 50000'
            END AS amount_range,
            COUNT(*) AS total_transactions
        FROM bank_transactions
        GROUP BY 1
        ORDER BY MIN(transaction_amount);
    """

    df = pd.read_sql_query(query, connection)

    plt.figure()
    plt.bar(df["amount_range"], df["total_transactions"])
    plt.title("Transaction Amount Distribution")
    plt.xlabel("Transaction Amount Range (INR)")
    plt.ylabel("Number of Transactions")
    plt.xticks(rotation=30)
    save_chart("01_transaction_amount_distribution.png")

    # --------------------------------------------------------
    # 2. DAILY TRANSACTION TRENDS
    # --------------------------------------------------------
    query = """
        SELECT
            transaction_date,
            COUNT(*) AS total_transactions,
            SUM(transaction_amount) AS transaction_value
        FROM bank_transactions
        GROUP BY transaction_date
        ORDER BY transaction_date;
    """

    df = pd.read_sql_query(query, connection)

    fig, ax1 = plt.subplots(figsize=(14, 7))

    ax1.plot(
        df["transaction_date"],
        df["total_transactions"],
        marker="o",
        linewidth=1.5,
        label="Transactions"
    )

    ax1.set_xlabel("Transaction Date")
    ax1.set_ylabel("Number of Transactions")
    ax1.tick_params(axis="x", rotation=45)
    ax1.set_title("Daily Transaction Trends")

    ax2 = ax1.twinx()
    ax2.plot(
        df["transaction_date"],
        df["transaction_value"] / 100000,
        linestyle="--",
        linewidth=1.5,
        label="Transaction Value"
    )
    ax2.set_ylabel("Transaction Value (INR Lakhs)")

    fig.tight_layout()
    fig.savefig(
        OUTPUT_DIR / "02_daily_transaction_trends.png",
        dpi=300,
        bbox_inches="tight"
    )
    plt.close(fig)
    print("Created: 02_daily_transaction_trends.png")

    # --------------------------------------------------------
    # 3. HOURLY TRANSACTION ACTIVITY
    # --------------------------------------------------------
    query = """
        SELECT
            EXTRACT(HOUR FROM transaction_time)::INTEGER AS hour,
            COUNT(*) AS total_transactions
        FROM bank_transactions
        GROUP BY hour
        ORDER BY hour;
    """

    df = pd.read_sql_query(query, connection)

    plt.figure()
    plt.bar(df["hour"], df["total_transactions"])
    plt.title("Hourly Transaction Activity")
    plt.xlabel("Hour of Day")
    plt.ylabel("Number of Transactions")
    plt.xticks(range(24))
    save_chart("03_hourly_transaction_activity.png")

    # --------------------------------------------------------
    # 4. TOP 10 LOCATIONS BY TRANSACTION VALUE
    # --------------------------------------------------------
    query = """
        SELECT
            customer_location,
            SUM(transaction_amount) AS transaction_value
        FROM bank_transactions
        WHERE customer_location <> 'Unknown'
        GROUP BY customer_location
        ORDER BY transaction_value DESC
        LIMIT 10;
    """

    df = pd.read_sql_query(query, connection)

    plt.figure()
    plt.barh(
        df["customer_location"][::-1],
        df["transaction_value"][::-1] / 10000000
    )
    plt.title("Top 10 Locations by Transaction Value")
    plt.xlabel("Transaction Value (INR Crores)")
    plt.ylabel("Customer Location")
    save_chart("04_top_10_locations.png")

    # --------------------------------------------------------
    # 5. CUSTOMER TRANSACTION FREQUENCY
    # --------------------------------------------------------
    query = """
        WITH customer_frequency AS (
            SELECT
                customer_id,
                COUNT(*) AS frequency
            FROM bank_transactions
            GROUP BY customer_id
        )
        SELECT
            CASE
                WHEN frequency = 1 THEN '1 Transaction'
                WHEN frequency BETWEEN 2 AND 3 THEN '2-3 Transactions'
                WHEN frequency BETWEEN 4 AND 5 THEN '4-5 Transactions'
                ELSE '6+ Transactions'
            END AS frequency_group,
            COUNT(*) AS total_customers
        FROM customer_frequency
        GROUP BY 1
        ORDER BY MIN(frequency);
    """

    df = pd.read_sql_query(query, connection)

    plt.figure()
    plt.bar(df["frequency_group"], df["total_customers"])
    plt.title("Customer Transaction Frequency")
    plt.xlabel("Transaction Frequency")
    plt.ylabel("Number of Customers")
    plt.xticks(rotation=15)
    save_chart("05_customer_transaction_frequency.png")

    # --------------------------------------------------------
    # 6. RFM CUSTOMER SEGMENTS
    # --------------------------------------------------------
    rfm_file = OUTPUT_DIR.parent / "rfm_segment_summary.csv"
    df = pd.read_csv(rfm_file)

    plt.figure()
    plt.barh(
        df["customer_segment"][::-1],
        df["total_customers"][::-1]
    )
    plt.title("RFM Customer Segmentation")
    plt.xlabel("Number of Customers")
    plt.ylabel("Customer Segment")
    save_chart("06_rfm_customer_segments.png")

    # --------------------------------------------------------
    # 7. CUSTOMER INACTIVITY DISTRIBUTION
    # --------------------------------------------------------
    query = """
        WITH customer_activity AS (
            SELECT
                customer_id,
                MAX(transaction_date) AS last_transaction_date
            FROM bank_transactions
            GROUP BY customer_id
        ),
        reference_date AS (
            SELECT MAX(transaction_date) AS max_date
            FROM bank_transactions
        ),
        inactivity AS (
            SELECT
                customer_id,
                max_date - last_transaction_date AS inactive_days
            FROM customer_activity
            CROSS JOIN reference_date
        )
        SELECT
            CASE
                WHEN inactive_days = 0 THEN 'Active on Reference Date'
                WHEN inactive_days <= 30 THEN '1-30 Days'
                WHEN inactive_days <= 60 THEN '31-60 Days'
                WHEN inactive_days <= 90 THEN '61-90 Days'
                ELSE 'Above 90 Days'
            END AS inactivity_group,
            COUNT(*) AS total_customers
        FROM inactivity
        GROUP BY 1
        ORDER BY MIN(inactive_days);
    """

    df = pd.read_sql_query(query, connection)

    plt.figure()
    plt.bar(
        df["inactivity_group"],
        df["total_customers"]
    )
    plt.title("Customer Inactivity Distribution")
    plt.xlabel("Inactivity Period")
    plt.ylabel("Number of Customers")
    plt.xticks(rotation=20)
    save_chart("07_customer_inactivity_distribution.png")

    # --------------------------------------------------------
    # 8. HIGH-VALUE INACTIVE CUSTOMERS
    # --------------------------------------------------------
    query = """
        WITH customer_metrics AS (
            SELECT
                customer_id,
                MAX(transaction_date) AS last_transaction_date,
                COUNT(*) AS total_transactions,
                SUM(transaction_amount) AS total_transaction_value
            FROM bank_transactions
            GROUP BY customer_id
        ),
        reference_date AS (
            SELECT MAX(transaction_date) AS max_date
            FROM bank_transactions
        )
        SELECT
            customer_id,
            reference_date.max_date - last_transaction_date
                AS inactive_days,
            total_transaction_value
        FROM customer_metrics
        CROSS JOIN reference_date
        WHERE
            reference_date.max_date - last_transaction_date > 30
            AND total_transaction_value > 10000
        ORDER BY total_transaction_value DESC
        LIMIT 10;
    """

    df = pd.read_sql_query(query, connection)

    plt.figure()
    plt.barh(
        df["customer_id"][::-1],
        df["total_transaction_value"][::-1] / 100000
    )
    plt.title("Top 10 High-Value Inactive Customers")
    plt.xlabel("Total Transaction Value (INR Lakhs)")
    plt.ylabel("Customer ID")
    save_chart("08_high_value_inactive_customers.png")

    connection.close()

    print("\n" + "=" * 65)
    print("ALL 8 VISUALIZATIONS CREATED SUCCESSFULLY")
    print(f"Charts saved in: {OUTPUT_DIR}")
    print("=" * 65)


if __name__ == "__main__":
    main()
