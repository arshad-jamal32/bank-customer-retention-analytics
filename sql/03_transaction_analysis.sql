
-- ============================================================
-- PROJECT: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- FILE: 03_transaction_analysis.sql
-- PURPOSE: Transaction Analysis
-- DATABASE: bank_customer_analytics
-- ============================================================


-- ============================================================
-- QUERY 1: OVERALL TRANSACTION SUMMARY
-- ============================================================

SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY transaction_amount)::NUMERIC,
        2
    ) AS median_transaction_amount,
    ROUND(MIN(transaction_amount), 2) AS minimum_transaction_amount,
    ROUND(MAX(transaction_amount), 2) AS maximum_transaction_amount
FROM bank_transactions;


-- ============================================================
-- QUERY 2: TRANSACTION AMOUNT DISTRIBUTION
-- ============================================================

SELECT
    CASE
        WHEN transaction_amount = 0 THEN 'Zero'
        WHEN transaction_amount <= 500 THEN '1 - 500'
        WHEN transaction_amount <= 1000 THEN '501 - 1,000'
        WHEN transaction_amount <= 5000 THEN '1,001 - 5,000'
        WHEN transaction_amount <= 10000 THEN '5,001 - 10,000'
        WHEN transaction_amount <= 50000 THEN '10,001 - 50,000'
        ELSE 'Above 50,000'
    END AS transaction_amount_range,

    COUNT(*) AS total_transactions,

    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,

    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS transaction_percentage

FROM bank_transactions
GROUP BY transaction_amount_range
ORDER BY MIN(transaction_amount);


-- ============================================================
-- QUERY 3: DAILY TRANSACTION PERFORMANCE
-- ============================================================

SELECT
    transaction_date,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount
FROM bank_transactions
GROUP BY transaction_date
ORDER BY transaction_date;


-- ============================================================
-- QUERY 4: MONTHLY TRANSACTION PERFORMANCE
-- ============================================================

SELECT
    TO_CHAR(transaction_date, 'YYYY-MM') AS transaction_month,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount
FROM bank_transactions
GROUP BY TO_CHAR(transaction_date, 'YYYY-MM')
ORDER BY transaction_month;


-- ============================================================
-- QUERY 5: HOURLY TRANSACTION ACTIVITY
-- ============================================================

SELECT
    EXTRACT(HOUR FROM transaction_time) AS transaction_hour,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount
FROM bank_transactions
GROUP BY EXTRACT(HOUR FROM transaction_time)
ORDER BY total_transactions DESC;


-- ============================================================
-- QUERY 6: WEEKDAY TRANSACTION PATTERNS
-- ============================================================

SELECT
    TO_CHAR(transaction_date, 'Day') AS weekday,
    EXTRACT(ISODOW FROM transaction_date) AS weekday_number,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount
FROM bank_transactions
GROUP BY
    TO_CHAR(transaction_date, 'Day'),
    EXTRACT(ISODOW FROM transaction_date)
ORDER BY weekday_number;


-- ============================================================
-- QUERY 7: TOP 20 HIGHEST-VALUE TRANSACTIONS
-- ============================================================

SELECT
    transaction_id,
    customer_id,
    customer_location,
    transaction_date,
    transaction_time,
    transaction_amount
FROM bank_transactions
ORDER BY transaction_amount DESC
LIMIT 20;


-- ============================================================
-- QUERY 8: TOP 20 CUSTOMERS BY TRANSACTION VALUE
-- ============================================================

SELECT
    customer_id,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount,
    ROUND(MAX(transaction_amount), 2) AS highest_transaction_amount
FROM bank_transactions
GROUP BY customer_id
ORDER BY total_transaction_value DESC
LIMIT 20;


-- ============================================================
-- QUERY 9: CUSTOMER TRANSACTION FREQUENCY
-- ============================================================

WITH customer_frequency AS (
    SELECT
        customer_id,
        COUNT(*) AS total_transactions
    FROM bank_transactions
    GROUP BY customer_id
)

SELECT
    CASE
        WHEN total_transactions = 1 THEN '1 Transaction'
        WHEN total_transactions BETWEEN 2 AND 5 THEN '2 - 5 Transactions'
        WHEN total_transactions BETWEEN 6 AND 10 THEN '6 - 10 Transactions'
        WHEN total_transactions BETWEEN 11 AND 20 THEN '11 - 20 Transactions'
        ELSE 'Above 20 Transactions'
    END AS transaction_frequency_group,

    COUNT(*) AS total_customers,

    ROUND(AVG(total_transactions), 2) AS average_transactions_per_customer

FROM customer_frequency
GROUP BY transaction_frequency_group
ORDER BY MIN(total_transactions);


-- ============================================================
-- QUERY 10: TRANSACTION PERFORMANCE BY GENDER
-- Note: This is transaction-row-level gender analysis.
-- Customers with conflicting genders may appear in
-- multiple gender categories.
-- ============================================================

SELECT
    gender,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount
FROM bank_transactions
GROUP BY gender
ORDER BY total_transaction_value DESC;


-- ============================================================
-- QUERY 11: TRANSACTION PERFORMANCE BY LOCATION
-- ============================================================

SELECT
    customer_location,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount
FROM bank_transactions
WHERE customer_location <> 'Unknown'
GROUP BY customer_location
ORDER BY total_transaction_value DESC
LIMIT 20;


-- ============================================================
-- QUERY 12: HIGH-VALUE TRANSACTION ANALYSIS
-- Business rule: Transaction amount above ₹50,000.
-- ============================================================

SELECT
    COUNT(*) AS high_value_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_high_value_transaction_amount,
    ROUND(AVG(transaction_amount), 2) AS average_high_value_transaction,
    ROUND(MAX(transaction_amount), 2) AS highest_transaction_amount,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM bank_transactions),
        2
    ) AS percentage_of_all_transactions
FROM bank_transactions
WHERE transaction_amount > 50000;


-- ============================================================
-- END OF TRANSACTION ANALYSIS
-- ============================================================
