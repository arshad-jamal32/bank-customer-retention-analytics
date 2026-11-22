
-- ============================================================
-- PROJECT: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- FILE: 04_geographic_analysis.sql
-- PURPOSE: Geographic Analysis
-- DATABASE: bank_customer_analytics
-- ============================================================


-- ============================================================
-- QUERY 1: OVERALL GEOGRAPHIC SUMMARY
-- ============================================================

SELECT
    COUNT(DISTINCT customer_location) AS total_locations,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(*) AS total_transactions,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
WHERE customer_location <> 'Unknown';


-- ============================================================
-- QUERY 2: TOP 20 LOCATIONS BY CUSTOMER COUNT
-- ============================================================

SELECT
    customer_location,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(*) AS total_transactions,
    ROUND(
        COUNT(DISTINCT customer_id) * 100.0 /
        (SELECT COUNT(DISTINCT customer_id)
         FROM bank_transactions
         WHERE customer_location <> 'Unknown'),
        2
    ) AS customer_percentage
FROM bank_transactions
WHERE customer_location <> 'Unknown'
GROUP BY customer_location
ORDER BY total_customers DESC
LIMIT 20;


-- ============================================================
-- QUERY 3: TOP 20 LOCATIONS BY TRANSACTION VALUE
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
-- QUERY 4: TOP 20 LOCATIONS BY AVERAGE TRANSACTION VALUE
-- Minimum 100 transactions to avoid very small samples.
-- ============================================================

SELECT
    customer_location,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(AVG(transaction_amount), 2) AS average_transaction_amount,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
WHERE customer_location <> 'Unknown'
GROUP BY customer_location
HAVING COUNT(*) >= 100
ORDER BY average_transaction_amount DESC
LIMIT 20;


-- ============================================================
-- QUERY 5: LOCATION-WISE HIGH-VALUE TRANSACTIONS
-- High-value threshold: Above ₹50,000.
-- ============================================================

SELECT
    customer_location,
    COUNT(*) AS high_value_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS high_value_transaction_total,
    ROUND(AVG(transaction_amount), 2) AS average_high_value_transaction
FROM bank_transactions
WHERE customer_location <> 'Unknown'
  AND transaction_amount > 50000
GROUP BY customer_location
ORDER BY high_value_transactions DESC
LIMIT 20;


-- ============================================================
-- QUERY 6: LOCATION-WISE GENDER DISTRIBUTION
-- Transaction-row-level gender distribution.
-- ============================================================

SELECT
    customer_location,
    gender,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,
    ROUND(SUM(transaction_amount), 2) AS total_transaction_value
FROM bank_transactions
WHERE customer_location <> 'Unknown'
GROUP BY customer_location, gender
ORDER BY customer_location, total_transactions DESC;


-- ============================================================
-- QUERY 7: LOCATION-WISE AGE GROUP DISTRIBUTION
-- Uses estimated DOB-based age at each transaction date.
-- ============================================================

WITH customer_age_records AS (
    SELECT
        customer_id,
        customer_location,
        EXTRACT(
            YEAR FROM AGE(transaction_date, customer_dob)
        ) AS age
    FROM bank_transactions
    WHERE customer_dob IS NOT NULL
),

age_groups AS (
    SELECT
        customer_id,
        customer_location,
        CASE
            WHEN age < 18 THEN 'Under 18'
            WHEN age BETWEEN 18 AND 25 THEN '18-25'
            WHEN age BETWEEN 26 AND 35 THEN '26-35'
            WHEN age BETWEEN 36 AND 45 THEN '36-45'
            WHEN age BETWEEN 46 AND 55 THEN '46-55'
            WHEN age BETWEEN 56 AND 65 THEN '56-65'
            ELSE 'Above 65'
        END AS age_group
    FROM customer_age_records
)

SELECT
    customer_location,
    age_group,
    COUNT(DISTINCT customer_id) AS total_customers
FROM age_groups
WHERE customer_location <> 'Unknown'
GROUP BY customer_location, age_group
ORDER BY customer_location, total_customers DESC;


-- ============================================================
-- QUERY 8: LOCATION-WISE CUSTOMER TRANSACTION BEHAVIOR
-- ============================================================

WITH customer_location_summary AS (
    SELECT
        customer_id,
        customer_location,
        COUNT(*) AS total_transactions,
        SUM(transaction_amount) AS total_transaction_value,
        AVG(transaction_amount) AS average_transaction_amount
    FROM bank_transactions
    WHERE customer_location <> 'Unknown'
    GROUP BY customer_id, customer_location
)

SELECT
    customer_location,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(total_transactions) AS total_transactions,
    ROUND(
        AVG(total_transactions),
        2
    ) AS average_transactions_per_customer,
    ROUND(
        AVG(total_transaction_value),
        2
    ) AS average_customer_transaction_value,
    ROUND(
        SUM(total_transaction_value),
        2
    ) AS total_transaction_value
FROM customer_location_summary
GROUP BY customer_location
ORDER BY total_transaction_value DESC
LIMIT 20;


-- ============================================================
-- END OF GEOGRAPHIC ANALYSIS
-- ============================================================
