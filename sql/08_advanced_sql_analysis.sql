
-- ============================================================
-- PROJECT 05: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- FILE: 08_advanced_sql_analysis.sql
-- ADVANCED SQL ANALYSIS
-- Database: bank_customer_analytics
-- Table: bank_transactions
-- ============================================================


-- QUERY 1: Daily Transaction Value with Running Total
-- Concept: CTE + Window Functions

WITH daily_performance AS (
    SELECT
        transaction_date,
        COUNT(*) AS total_transactions,
        SUM(transaction_amount) AS daily_transaction_value
    FROM bank_transactions
    GROUP BY transaction_date
)
SELECT
    transaction_date,
    total_transactions,
    ROUND(daily_transaction_value, 2) AS daily_transaction_value,
    ROUND(
        SUM(daily_transaction_value) OVER (
            ORDER BY transaction_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_transaction_value
FROM daily_performance
ORDER BY transaction_date;


-- QUERY 2: Monthly Transaction Performance Ranking
-- Concept: DENSE_RANK + Window Functions

WITH monthly_performance AS (
    SELECT
        DATE_TRUNC('month', transaction_date)::DATE AS transaction_month,
        COUNT(*) AS total_transactions,
        COUNT(DISTINCT customer_id) AS unique_customers,
        SUM(transaction_amount) AS total_transaction_value,
        AVG(transaction_amount) AS average_transaction_value
    FROM bank_transactions
    GROUP BY DATE_TRUNC('month', transaction_date)::DATE
)
SELECT
    transaction_month,
    total_transactions,
    unique_customers,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    DENSE_RANK() OVER (
        ORDER BY total_transaction_value DESC
    ) AS revenue_rank,
    ROUND(
        total_transaction_value * 100.0
        / SUM(total_transaction_value) OVER (),
        2
    ) AS revenue_contribution_percentage
FROM monthly_performance
ORDER BY transaction_month;


-- QUERY 3: Top 20 Customers by Transaction Value
-- Concept: ROW_NUMBER + Customer-Level Aggregation

WITH customer_performance AS (
    SELECT
        customer_id,
        COUNT(*) AS total_transactions,
        SUM(transaction_amount) AS total_transaction_value,
        AVG(transaction_amount) AS average_transaction_value,
        MAX(transaction_date) AS last_transaction_date
    FROM bank_transactions
    GROUP BY customer_id
),
ranked_customers AS (
    SELECT
        customer_id,
        total_transactions,
        total_transaction_value,
        average_transaction_value,
        last_transaction_date,
        ROW_NUMBER() OVER (
            ORDER BY
                total_transaction_value DESC,
                customer_id ASC
        ) AS customer_rank
    FROM customer_performance
)
SELECT
    customer_rank,
    customer_id,
    total_transactions,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    last_transaction_date
FROM ranked_customers
WHERE customer_rank <= 20
ORDER BY customer_rank;


-- QUERY 4: Transaction Amount Distribution with Cumulative Contribution
-- Concept: CASE + Window Functions

WITH transaction_buckets AS (
    SELECT
        CASE
            WHEN transaction_amount = 0 THEN 'Zero'
            WHEN transaction_amount <= 500 THEN '1-500'
            WHEN transaction_amount <= 1000 THEN '501-1000'
            WHEN transaction_amount <= 5000 THEN '1001-5000'
            WHEN transaction_amount <= 10000 THEN '5001-10000'
            WHEN transaction_amount <= 50000 THEN '10001-50000'
            ELSE 'Above 50000'
        END AS transaction_amount_group,
        CASE
            WHEN transaction_amount = 0 THEN 1
            WHEN transaction_amount <= 500 THEN 2
            WHEN transaction_amount <= 1000 THEN 3
            WHEN transaction_amount <= 5000 THEN 4
            WHEN transaction_amount <= 10000 THEN 5
            WHEN transaction_amount <= 50000 THEN 6
            ELSE 7
        END AS group_order,
        transaction_amount
    FROM bank_transactions
),
bucket_summary AS (
    SELECT
        transaction_amount_group,
        group_order,
        COUNT(*) AS total_transactions,
        SUM(transaction_amount) AS total_transaction_value
    FROM transaction_buckets
    GROUP BY
        transaction_amount_group,
        group_order
)
SELECT
    transaction_amount_group,
    total_transactions,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(
        total_transactions * 100.0
        / SUM(total_transactions) OVER (),
        2
    ) AS transaction_percentage,
    ROUND(
        total_transaction_value * 100.0
        / NULLIF(SUM(total_transaction_value) OVER (), 0),
        2
    ) AS value_contribution_percentage,
    ROUND(
        SUM(total_transaction_value) OVER (
            ORDER BY group_order
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cumulative_transaction_value
FROM bucket_summary
ORDER BY group_order;


-- QUERY 5: Customer Revenue Contribution and Cumulative Share
-- Corrected: Percentage calculated against ALL customers

WITH customer_revenue AS (
    SELECT
        customer_id,
        COUNT(*) AS total_transactions,
        SUM(transaction_amount) AS total_transaction_value
    FROM bank_transactions
    GROUP BY customer_id
),
ranked_revenue AS (
    SELECT
        customer_id,
        total_transactions,
        total_transaction_value,

        ROW_NUMBER() OVER (
            ORDER BY
                total_transaction_value DESC,
                customer_id ASC
        ) AS customer_rank,

        SUM(total_transaction_value) OVER (
            ORDER BY
                total_transaction_value DESC,
                customer_id ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue,

        SUM(total_transaction_value) OVER () AS overall_revenue

    FROM customer_revenue
)
SELECT
    customer_rank,
    customer_id,
    total_transactions,
    ROUND(total_transaction_value, 2) AS total_transaction_value,

    ROUND(
        total_transaction_value * 100.0
        / NULLIF(overall_revenue, 0),
        4
    ) AS individual_revenue_percentage,

    ROUND(
        cumulative_revenue * 100.0
        / NULLIF(overall_revenue, 0),
        2
    ) AS cumulative_revenue_percentage

FROM ranked_revenue
WHERE customer_rank <= 20
ORDER BY customer_rank;



-- QUERY 6: Time Gap Between Consecutive Customer Transactions
-- Concept: LAG + Window Functions

WITH customer_transaction_history AS (
    SELECT
        customer_id,
        transaction_date,
        transaction_time,
        transaction_amount,
        LAG(transaction_date) OVER (
            PARTITION BY customer_id
            ORDER BY transaction_date, transaction_time, transaction_id
        ) AS previous_transaction_date
    FROM bank_transactions
),
transaction_gaps AS (
    SELECT
        customer_id,
        previous_transaction_date,
        transaction_date,
        transaction_time,
        transaction_amount,
        transaction_date - previous_transaction_date
            AS days_between_transactions
    FROM customer_transaction_history
    WHERE previous_transaction_date IS NOT NULL
)
SELECT
    customer_id,
    previous_transaction_date,
    transaction_date AS current_transaction_date,
    transaction_time,
    days_between_transactions,
    ROUND(transaction_amount, 2) AS transaction_amount
FROM transaction_gaps
ORDER BY
    days_between_transactions DESC,
    customer_id ASC
LIMIT 50;


-- QUERY 7: Hourly Transaction Ranking and Contribution
-- Concept: CTE + DENSE_RANK + Window Functions

WITH hourly_performance AS (
    SELECT
        EXTRACT(HOUR FROM transaction_time)::INTEGER AS transaction_hour,
        COUNT(*) AS total_transactions,
        COUNT(DISTINCT customer_id) AS unique_customers,
        SUM(transaction_amount) AS total_transaction_value,
        AVG(transaction_amount) AS average_transaction_value
    FROM bank_transactions
    GROUP BY EXTRACT(HOUR FROM transaction_time)::INTEGER
)
SELECT
    transaction_hour,
    total_transactions,
    unique_customers,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    DENSE_RANK() OVER (
        ORDER BY total_transactions DESC
    ) AS transaction_volume_rank,
    ROUND(
        total_transactions * 100.0
        / SUM(total_transactions) OVER (),
        2
    ) AS transaction_percentage
FROM hourly_performance
ORDER BY transaction_hour;


-- QUERY 8: Location-Wise Transaction Performance Ranking
-- Concept: CTE + ROW_NUMBER + Window Functions

WITH location_performance AS (
    SELECT
        customer_location,
        COUNT(*) AS total_transactions,
        COUNT(DISTINCT customer_id) AS unique_customers,
        SUM(transaction_amount) AS total_transaction_value,
        AVG(transaction_amount) AS average_transaction_value
    FROM bank_transactions
    WHERE customer_location IS NOT NULL
      AND customer_location <> 'Unknown'
    GROUP BY customer_location
    HAVING COUNT(*) >= 100
),
ranked_locations AS (
    SELECT
        customer_location,
        total_transactions,
        unique_customers,
        total_transaction_value,
        average_transaction_value,
        ROW_NUMBER() OVER (
            ORDER BY
                total_transaction_value DESC,
                customer_location ASC
        ) AS revenue_rank
    FROM location_performance
)
SELECT
    revenue_rank,
    customer_location,
    total_transactions,
    unique_customers,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    ROUND(average_transaction_value, 2) AS average_transaction_value,
    ROUND(
        total_transaction_value * 100.0
        / SUM(total_transaction_value) OVER (),
        2
    ) AS percentage_of_top_location_revenue
FROM ranked_locations
WHERE revenue_rank <= 20
ORDER BY revenue_rank;


-- ============================================================
-- END OF ADVANCED SQL ANALYSIS
-- ============================================================
