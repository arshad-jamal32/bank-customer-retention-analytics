
-- ============================================================
-- PROJECT: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- FILE: 05_customer_value_analysis.sql
-- ANALYSIS: CUSTOMER VALUE ANALYSIS
-- ============================================================


-- QUERY 1: Overall Customer Value Summary

SELECT
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value,
    ROUND(
        SUM(transaction_amount) / COUNT(DISTINCT customer_id),
        2
    ) AS average_value_per_customer
FROM bank_transactions;


-- QUERY 2: Top 20 Customers by Total Transaction Value

SELECT
    customer_id,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value,
    MAX(transaction_amount) AS highest_transaction
FROM bank_transactions
GROUP BY customer_id
ORDER BY total_transaction_value DESC
LIMIT 20;


-- QUERY 3: Top 20 Customers by Average Transaction Value
-- Minimum 2 transactions required

SELECT
    customer_id,
    COUNT(*) AS total_transactions,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
GROUP BY customer_id
HAVING COUNT(*) >= 2
ORDER BY average_transaction_value DESC
LIMIT 20;



-- QUERY 4: Customer Value Segmentation

WITH customer_value AS (
    SELECT
        customer_id,
        SUM(transaction_amount) AS total_value
    FROM bank_transactions
    GROUP BY customer_id
),
segmented AS (
    SELECT
        customer_id,
        total_value,
        CASE
            WHEN total_value = 0 THEN 'Zero Value'
            WHEN total_value <= 500 THEN 'Low Value'
            WHEN total_value <= 2000 THEN 'Medium Value'
            WHEN total_value <= 10000 THEN 'High Value'
            ELSE 'Very High Value'
        END AS customer_value_segment
    FROM customer_value
)
SELECT
    customer_value_segment,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_value), 2) AS total_transaction_value,
    ROUND(AVG(total_value), 2) AS average_customer_value,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage
FROM segmented
GROUP BY customer_value_segment
ORDER BY
    CASE customer_value_segment
        WHEN 'Zero Value' THEN 1
        WHEN 'Low Value' THEN 2
        WHEN 'Medium Value' THEN 3
        WHEN 'High Value' THEN 4
        WHEN 'Very High Value' THEN 5
    END;



-- QUERY 5: Repeat vs Single-Transaction Customers

WITH customer_frequency AS (
    SELECT
        customer_id,
        COUNT(*) AS transaction_count,
        SUM(transaction_amount) AS total_value
    FROM bank_transactions
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN transaction_count = 1 THEN 'Single Transaction'
        ELSE 'Repeat Transactions'
    END AS customer_type,
    COUNT(*) AS total_customers,
    ROUND(SUM(total_value), 2) AS total_transaction_value,
    ROUND(AVG(total_value), 2) AS average_customer_value,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage
FROM customer_frequency
GROUP BY customer_type
ORDER BY total_customers DESC;


-- QUERY 6: Top Customers by Transaction Frequency

SELECT
    customer_id,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value
FROM bank_transactions
GROUP BY customer_id
ORDER BY total_transactions DESC, total_transaction_value DESC
LIMIT 20;


-- QUERY 7: Customer Transaction Value Contribution

WITH customer_value AS (
    SELECT
        customer_id,
        SUM(transaction_amount) AS total_value
    FROM bank_transactions
    GROUP BY customer_id
),
ranked_customers AS (
    SELECT
        customer_id,
        total_value,
        SUM(total_value) OVER (
            ORDER BY total_value DESC, customer_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_value,
        SUM(total_value) OVER () AS overall_value
    FROM customer_value
)
SELECT
    customer_id,
    ROUND(total_value, 2) AS customer_value,
    ROUND(
        total_value * 100.0 / NULLIF(overall_value, 0),
        4
    ) AS individual_contribution_percentage,
    ROUND(
        cumulative_value * 100.0 / NULLIF(overall_value, 0),
        2
    ) AS cumulative_contribution_percentage
FROM ranked_customers
ORDER BY total_value DESC
LIMIT 20;


-- QUERY 8: Customer Value by Gender
-- Customer-level derived gender classification.
-- Conflicting M/F records are kept separate.

WITH customer_gender AS (
    SELECT
        customer_id,
        COUNT(DISTINCT gender) FILTER (
            WHERE gender IN ('M', 'F')
        ) AS known_gender_count,
        MAX(gender) FILTER (
            WHERE gender IN ('M', 'F')
        ) AS known_gender,
        SUM(transaction_amount) AS total_value,
        COUNT(*) AS total_transactions
    FROM bank_transactions
    GROUP BY customer_id
),
classified AS (
    SELECT
        *,
        CASE
            WHEN known_gender_count = 2 THEN 'Conflicting'
            WHEN known_gender_count = 1 AND known_gender = 'M' THEN 'Male'
            WHEN known_gender_count = 1 AND known_gender = 'F' THEN 'Female'
            ELSE 'Unknown'
        END AS customer_gender
    FROM customer_gender
)
SELECT
    customer_gender,
    COUNT(*) AS total_customers,
    SUM(total_transactions) AS total_transactions,
    ROUND(SUM(total_value), 2) AS total_transaction_value,
    ROUND(AVG(total_value), 2) AS average_customer_value
FROM classified
GROUP BY customer_gender
ORDER BY total_transaction_value DESC;


-- ============================================================
-- END OF CUSTOMER VALUE ANALYSIS
-- ============================================================
