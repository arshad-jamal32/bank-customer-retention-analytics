
-- ============================================================
-- PROJECT: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- FILE: 01_banking_overview.sql
-- PURPOSE: Overall Banking Performance Analysis
-- DATABASE: bank_customer_analytics
-- ============================================================


-- ============================================================
-- QUERY 1: OVERALL BANKING PERFORMANCE
-- Business Question:
-- What is the overall transaction performance of the bank?
-- ============================================================

SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value,
    ROUND(MAX(transaction_amount), 2) AS highest_transaction,
    ROUND(MIN(transaction_amount), 2) AS lowest_transaction
FROM bank_transactions;


-- ============================================================
-- QUERY 2: DAILY TRANSACTION PERFORMANCE
-- Business Question:
-- How does transaction activity vary from day to day?
-- ============================================================

SELECT
    transaction_date,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value
FROM bank_transactions
GROUP BY transaction_date
ORDER BY transaction_date;


-- ============================================================
-- QUERY 3: MONTHLY TRANSACTION PERFORMANCE
-- Business Question:
-- How does transaction performance vary across months?
-- ============================================================

SELECT
    TO_CHAR(transaction_date, 'Month') AS month_name,
    EXTRACT(MONTH FROM transaction_date) AS month_number,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value
FROM bank_transactions
GROUP BY
    EXTRACT(MONTH FROM transaction_date),
    TO_CHAR(transaction_date, 'Month')
ORDER BY month_number;


-- ============================================================
-- QUERY 4: TRANSACTION ACTIVITY BY HOUR
-- Business Question:
-- During which hours does the bank experience the
-- highest transaction activity?
-- ============================================================

SELECT
    EXTRACT(HOUR FROM transaction_time) AS transaction_hour,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value
FROM bank_transactions
GROUP BY EXTRACT(HOUR FROM transaction_time)
ORDER BY total_transactions DESC;


-- ============================================================
-- QUERY 5: TRANSACTION AMOUNT DISTRIBUTION
-- Business Question:
-- How are transactions distributed across amount ranges?
-- ============================================================

SELECT
    CASE
        WHEN transaction_amount = 0 THEN 'Zero'
        WHEN transaction_amount <= 500 THEN '1 - 500'
        WHEN transaction_amount <= 1000 THEN '501 - 1000'
        WHEN transaction_amount <= 5000 THEN '1001 - 5000'
        WHEN transaction_amount <= 10000 THEN '5001 - 10000'
        WHEN transaction_amount <= 50000 THEN '10001 - 50000'
        ELSE 'Above 50000'
    END AS transaction_range,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
GROUP BY transaction_range
ORDER BY MIN(transaction_amount);


-- ============================================================
-- QUERY 6: TOP 10 HIGHEST TRANSACTION DAYS
-- Business Question:
-- Which dates generated the highest transaction value?
-- ============================================================

SELECT
    transaction_date,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
GROUP BY transaction_date
ORDER BY total_transaction_value DESC
LIMIT 10;


-- ============================================================
-- QUERY 7: ZERO-VALUE TRANSACTION ANALYSIS
-- Business Question:
-- How many transactions have zero transaction value?
-- ============================================================

SELECT
    COUNT(*) AS zero_value_transactions,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM bank_transactions),
        2
    ) AS percentage_of_total_transactions
FROM bank_transactions
WHERE transaction_amount = 0;


-- ============================================================
-- QUERY 8: TRANSACTION ACTIVITY BY WEEKDAY
-- Business Question:
-- Which weekdays experience the highest transaction activity?
-- ============================================================

SELECT
    TO_CHAR(transaction_date, 'Day') AS weekday,
    EXTRACT(ISODOW FROM transaction_date) AS weekday_number,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
GROUP BY
    EXTRACT(ISODOW FROM transaction_date),
    TO_CHAR(transaction_date, 'Day')
ORDER BY weekday_number;


-- ============================================================
-- END OF BANKING OVERVIEW ANALYSIS
-- ============================================================
