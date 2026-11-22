
-- ============================================================
-- PROJECT: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- FILE: 02_customer_demographics.sql
-- PURPOSE: Customer Demographics Analysis
-- DATABASE: bank_customer_analytics
-- ============================================================


-- ============================================================
-- QUERY 1: GENDER DISTRIBUTION
-- Business Question:
-- How are customers distributed by gender?
-- ============================================================

SELECT
    gender,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(*) AS total_transactions,
    ROUND(
        COUNT(DISTINCT customer_id) * 100.0 /
        (SELECT COUNT(DISTINCT customer_id) FROM bank_transactions),
        2
    ) AS customer_percentage
FROM bank_transactions
GROUP BY gender
ORDER BY total_customers DESC;


-- ============================================================
-- QUERY 2: CUSTOMER AGE DISTRIBUTION
-- Business Question:
-- How are customers distributed across different age groups?
-- Age is calculated as of the transaction date.
-- ============================================================

WITH customer_ages AS (
    SELECT DISTINCT
        customer_id,
        customer_dob,
        transaction_date,
        EXTRACT(YEAR FROM AGE(transaction_date, customer_dob)) AS age
    FROM bank_transactions
    WHERE customer_dob IS NOT NULL
),

age_groups AS (
    SELECT
        customer_id,
        CASE
            WHEN age < 18 THEN 'Under 18'
            WHEN age BETWEEN 18 AND 25 THEN '18-25'
            WHEN age BETWEEN 26 AND 35 THEN '26-35'
            WHEN age BETWEEN 36 AND 45 THEN '36-45'
            WHEN age BETWEEN 46 AND 55 THEN '46-55'
            WHEN age BETWEEN 56 AND 65 THEN '56-65'
            ELSE 'Above 65'
        END AS age_group
    FROM customer_ages
)

SELECT
    age_group,
    COUNT(DISTINCT customer_id) AS total_customers
FROM age_groups
GROUP BY age_group
ORDER BY
    CASE age_group
        WHEN 'Under 18' THEN 1
        WHEN '18-25' THEN 2
        WHEN '26-35' THEN 3
        WHEN '36-45' THEN 4
        WHEN '46-55' THEN 5
        WHEN '56-65' THEN 6
        ELSE 7
    END;


-- ============================================================
-- QUERY 3: AVERAGE AGE BY GENDER
-- Business Question:
-- What is the average estimated age of customers by gender?
-- ============================================================

WITH customer_ages AS (
    SELECT DISTINCT ON (customer_id)
        customer_id,
        gender,
        EXTRACT(
            YEAR FROM AGE(transaction_date, customer_dob)
        ) AS age
    FROM bank_transactions
    WHERE customer_dob IS NOT NULL
    ORDER BY customer_id, transaction_date DESC
)

SELECT
    gender,
    COUNT(*) AS customers_with_dob,
    ROUND(AVG(age), 2) AS average_customer_age,
    MIN(age) AS minimum_age,
    MAX(age) AS maximum_age
FROM customer_ages
GROUP BY gender
ORDER BY customers_with_dob DESC;


-- ============================================================
-- QUERY 4: TOP 10 CUSTOMER LOCATIONS
-- Business Question:
-- Which locations have the highest number of customers?
-- ============================================================

SELECT
    customer_location,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
WHERE customer_location <> 'Unknown'
GROUP BY customer_location
ORDER BY total_customers DESC
LIMIT 10;


-- ============================================================
-- QUERY 5: LOCATION-WISE TRANSACTION PERFORMANCE
-- Business Question:
-- Which locations generate the highest transaction value?
-- ============================================================

SELECT
    customer_location,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_value
FROM bank_transactions
WHERE customer_location <> 'Unknown'
GROUP BY customer_location
ORDER BY total_transaction_value DESC
LIMIT 10;


-- ============================================================
-- QUERY 6: ACCOUNT BALANCE DISTRIBUTION
-- Business Question:
-- How are transaction-level account balance records
-- distributed across balance ranges?
-- ============================================================

SELECT
    CASE
        WHEN account_balance = 0 THEN 'Zero Balance'
        WHEN account_balance <= 10000 THEN '1 - 10,000'
        WHEN account_balance <= 50000 THEN '10,001 - 50,000'
        WHEN account_balance <= 100000 THEN '50,001 - 1,00,000'
        WHEN account_balance <= 500000 THEN '1,00,001 - 5,00,000'
        ELSE 'Above 5,00,000'
    END AS balance_range,
    COUNT(*) AS transaction_records,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(AVG(account_balance), 2) AS average_account_balance
FROM bank_transactions
WHERE account_balance IS NOT NULL
GROUP BY balance_range
ORDER BY MIN(account_balance);


-- ============================================================
-- QUERY 7: CUSTOMER AGE GROUP VS TRANSACTION BEHAVIOR
-- Business Question:
-- Which age groups have higher transaction activity
-- and transaction values?
-- ============================================================

WITH customer_age AS (
    SELECT DISTINCT ON (customer_id)
        customer_id,
        EXTRACT(
            YEAR FROM AGE(transaction_date, customer_dob)
        ) AS age
    FROM bank_transactions
    WHERE customer_dob IS NOT NULL
    ORDER BY customer_id, transaction_date DESC
),

customer_age_groups AS (
    SELECT
        customer_id,
        CASE
            WHEN age < 18 THEN 'Under 18'
            WHEN age BETWEEN 18 AND 25 THEN '18-25'
            WHEN age BETWEEN 26 AND 35 THEN '26-35'
            WHEN age BETWEEN 36 AND 45 THEN '36-45'
            WHEN age BETWEEN 46 AND 55 THEN '46-55'
            WHEN age BETWEEN 56 AND 65 THEN '56-65'
            ELSE 'Above 65'
        END AS age_group
    FROM customer_age
),

customer_transactions AS (
    SELECT
        customer_id,
        COUNT(*) AS total_transactions,
        SUM(transaction_amount) AS total_transaction_value
    FROM bank_transactions
    GROUP BY customer_id
)

SELECT
    ag.age_group,
    COUNT(*) AS total_customers,
    SUM(ct.total_transactions) AS total_transactions,
    ROUND(
        AVG(ct.total_transactions),
        2
    ) AS average_transactions_per_customer,
    ROUND(
        SUM(ct.total_transaction_value),
        2
    ) AS total_transaction_value,
    ROUND(
        AVG(ct.total_transaction_value),
        2
    ) AS average_customer_transaction_value
FROM customer_age_groups ag
JOIN customer_transactions ct
    ON ag.customer_id = ct.customer_id
GROUP BY ag.age_group
ORDER BY total_transaction_value DESC;


-- ============================================================
-- QUERY 8: CUSTOMER ACCOUNT BALANCE SUMMARY
-- Business Question:
-- What are the overall account balance statistics?
-- Note: Balance is recorded at transaction level.
-- ============================================================

SELECT
    COUNT(*) AS records_with_balance,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(AVG(account_balance), 2) AS average_recorded_balance,
    ROUND(MIN(account_balance), 2) AS minimum_recorded_balance,
    ROUND(MAX(account_balance), 2) AS maximum_recorded_balance,
    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY account_balance)::NUMERIC,
        2
    ) AS median_recorded_balance
FROM bank_transactions
WHERE account_balance IS NOT NULL;


-- ============================================================
-- END OF CUSTOMER DEMOGRAPHICS ANALYSIS
-- ============================================================
