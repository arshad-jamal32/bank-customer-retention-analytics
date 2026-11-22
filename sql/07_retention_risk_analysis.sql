
-- ============================================================
-- PROJECT 05: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- SQL ANALYSIS 07: RETENTION & INACTIVITY RISK ANALYSIS
-- ============================================================

-- Reference Date: Latest transaction date in dataset
-- This analysis identifies observed inactivity, NOT confirmed churn.


-- QUERY 1: Overall Customer Inactivity Summary

WITH customer_activity AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS transaction_count,
        SUM(transaction_amount) AS total_transaction_value
    FROM bank_transactions
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE max_date - last_transaction_date > 30
    ) AS inactive_30_days,
    COUNT(*) FILTER (
        WHERE max_date - last_transaction_date > 60
    ) AS inactive_60_days,
    COUNT(*) FILTER (
        WHERE max_date - last_transaction_date > 90
    ) AS inactive_90_days,
    ROUND(
        COUNT(*) FILTER (
            WHERE max_date - last_transaction_date > 60
        ) * 100.0 / COUNT(*), 2
    ) AS inactive_60_days_percentage
FROM customer_activity
CROSS JOIN reference_date;



-- QUERY 2: Customer Inactivity Distribution

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
),
inactivity_groups AS (
    SELECT
        CASE
            WHEN inactive_days = 0 THEN 'Active on Reference Date'
            WHEN inactive_days BETWEEN 1 AND 30 THEN '1-30 Days'
            WHEN inactive_days BETWEEN 31 AND 60 THEN '31-60 Days'
            WHEN inactive_days BETWEEN 61 AND 90 THEN '61-90 Days'
            ELSE 'Above 90 Days'
        END AS inactivity_group
    FROM inactivity
)
SELECT
    inactivity_group,
    COUNT(*) AS total_customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS customer_percentage
FROM inactivity_groups
GROUP BY inactivity_group
ORDER BY
    CASE inactivity_group
        WHEN 'Active on Reference Date' THEN 1
        WHEN '1-30 Days' THEN 2
        WHEN '31-60 Days' THEN 3
        WHEN '61-90 Days' THEN 4
        ELSE 5
    END;


-- QUERY 3: Repeat Customers with Inactivity

WITH customer_activity AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS transaction_count,
        SUM(transaction_amount) AS total_transaction_value
    FROM bank_transactions
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
)
SELECT
    CASE
        WHEN max_date - last_transaction_date BETWEEN 31 AND 60
            THEN '31-60 Days'
        WHEN max_date - last_transaction_date BETWEEN 61 AND 90
            THEN '61-90 Days'
        ELSE 'Above 90 Days'
    END AS inactivity_group,
    COUNT(*) AS repeat_customers,
    ROUND(SUM(total_transaction_value), 2) AS total_transaction_value,
    ROUND(AVG(total_transaction_value), 2) AS avg_customer_value,
    ROUND(AVG(transaction_count), 2) AS avg_frequency
FROM customer_activity
CROSS JOIN reference_date
WHERE transaction_count >= 2
  AND max_date - last_transaction_date > 30
GROUP BY 1
ORDER BY 1;


-- QUERY 4: High-Value Inactive Customers

WITH customer_activity AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS transaction_count,
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
    last_transaction_date,
    max_date - last_transaction_date AS inactive_days,
    transaction_count,
    ROUND(total_transaction_value, 2) AS total_transaction_value
FROM customer_activity
CROSS JOIN reference_date
WHERE max_date - last_transaction_date > 30
  AND total_transaction_value > 10000
ORDER BY total_transaction_value DESC
LIMIT 20;


-- QUERY 5: Inactivity Risk by Customer Value

WITH customer_activity AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS transaction_count,
        SUM(transaction_amount) AS total_transaction_value
    FROM bank_transactions
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
),
classified AS (
    SELECT
        *,
        CASE
            WHEN max_date - last_transaction_date > 90
                THEN 'Above 90 Days'
            WHEN max_date - last_transaction_date > 60
                THEN '61-90 Days'
            WHEN max_date - last_transaction_date > 30
                THEN '31-60 Days'
            ELSE '0-30 Days'
        END AS inactivity_group,
        CASE
            WHEN total_transaction_value > 50000 THEN 'Very High Value'
            WHEN total_transaction_value > 10000 THEN 'High Value'
            WHEN total_transaction_value > 2000 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS customer_value_group
    FROM customer_activity
    CROSS JOIN reference_date
)
SELECT
    inactivity_group,
    customer_value_group,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_transaction_value), 2) AS total_transaction_value,
    ROUND(AVG(total_transaction_value), 2) AS avg_customer_value
FROM classified
GROUP BY inactivity_group, customer_value_group
ORDER BY inactivity_group, customer_value_group;



-- QUERY 6: Location-Wise Customer Inactivity
-- Assign each customer to their most frequently used location

WITH location_frequency AS (
    SELECT
        customer_id,
        customer_location,
        COUNT(*) AS transaction_count
    FROM bank_transactions
    WHERE customer_location IS NOT NULL
      AND customer_location <> 'Unknown'
    GROUP BY
        customer_id,
        customer_location
),

ranked_locations AS (
    SELECT
        customer_id,
        customer_location,
        transaction_count,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                transaction_count DESC,
                customer_location ASC
        ) AS rn
    FROM location_frequency
),

customer_primary_location AS (
    SELECT
        customer_id,
        customer_location
    FROM ranked_locations
    WHERE rn = 1
),

customer_metrics AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        SUM(transaction_amount) AS total_transaction_value
    FROM bank_transactions
    GROUP BY customer_id
),

reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
),

customer_inactivity AS (
    SELECT
        cm.customer_id,
        cpl.customer_location,
        cm.total_transaction_value,
        rd.max_date - cm.last_transaction_date AS inactive_days
    FROM customer_metrics cm
    INNER JOIN customer_primary_location cpl
        ON cm.customer_id = cpl.customer_id
    CROSS JOIN reference_date rd
)

SELECT
    customer_location,
    COUNT(*) AS total_customers,

    COUNT(*) FILTER (
        WHERE inactive_days > 60
    ) AS inactive_customers,

    ROUND(
        COUNT(*) FILTER (
            WHERE inactive_days > 60
        ) * 100.0 / COUNT(*),
        2
    ) AS inactive_percentage,

    ROUND(
        SUM(total_transaction_value),
        2
    ) AS total_transaction_value

FROM customer_inactivity
GROUP BY customer_location

HAVING COUNT(*) >= 100

ORDER BY
    inactive_customers DESC,
    customer_location ASC

LIMIT 20;


-- QUERY 7: Customer Retention Activity by Transaction Frequency

WITH customer_activity AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS transaction_count,
        SUM(transaction_amount) AS total_transaction_value
    FROM bank_transactions
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
)
SELECT
    CASE
        WHEN transaction_count = 1 THEN 'Single Transaction'
        WHEN transaction_count BETWEEN 2 AND 3 THEN '2-3 Transactions'
        WHEN transaction_count BETWEEN 4 AND 5 THEN '4-5 Transactions'
        ELSE '6+ Transactions'
    END AS frequency_group,
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE max_date - last_transaction_date > 60
    ) AS inactive_customers,
    ROUND(
        COUNT(*) FILTER (
            WHERE max_date - last_transaction_date > 60
        ) * 100.0 / COUNT(*), 2
    ) AS inactivity_percentage,
    ROUND(SUM(total_transaction_value), 2) AS total_transaction_value
FROM customer_activity
CROSS JOIN reference_date
GROUP BY 1
ORDER BY MIN(transaction_count);


-- QUERY 8: Customers Requiring Retention Attention

WITH customer_activity AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS transaction_count,
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
    last_transaction_date,
    max_date - last_transaction_date AS inactive_days,
    transaction_count,
    ROUND(total_transaction_value, 2) AS total_transaction_value,
    CASE
        WHEN max_date - last_transaction_date > 60
         AND total_transaction_value > 50000
            THEN 'High Priority'
        WHEN max_date - last_transaction_date > 60
         AND total_transaction_value > 10000
            THEN 'Medium Priority'
        ELSE 'Low Priority'
    END AS retention_priority
FROM customer_activity
CROSS JOIN reference_date
WHERE max_date - last_transaction_date > 60
  AND total_transaction_value > 10000
ORDER BY
    CASE
        WHEN max_date - last_transaction_date > 60
         AND total_transaction_value > 50000 THEN 1
        ELSE 2
    END,
    total_transaction_value DESC
LIMIT 50;
