-- ============================================================
-- PROJECT 05: BANK CUSTOMER TRANSACTION & RETENTION ANALYTICS
-- SQL ANALYSIS 06: RFM CUSTOMER SEGMENTATION
-- ============================================================
-- RFM:
-- Recency   = Days since customer's last transaction
-- Frequency = Number of transactions
-- Monetary  = Total transaction amount
-- Reference date:
-- Maximum transaction date in the dataset.
-- This avoids assuming that the dataset is current.
-- QUERY 1: Overall RFM Summary
WITH reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
),
customer_rfm AS (
    SELECT customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS frequency,
        SUM(transaction_amount) AS monetary
    FROM bank_transactions
    GROUP BY customer_id
)
SELECT COUNT(*) AS total_customers,
    ROUND(AVG(max_date - last_transaction_date), 2) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary_value,
    MAX(max_date) AS reference_date
FROM customer_rfm
    CROSS JOIN reference_date;
-- QUERY 2: Customer-Level RFM Metrics
WITH reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
)
SELECT bt.customer_id,
    MAX(bt.transaction_date) AS last_transaction_date,
    (rd.max_date - MAX(bt.transaction_date)) AS recency_days,
    COUNT(*) AS frequency,
    ROUND(SUM(bt.transaction_amount), 2) AS monetary_value
FROM bank_transactions bt
    CROSS JOIN reference_date rd
GROUP BY bt.customer_id,
    rd.max_date
ORDER BY monetary_value DESC
LIMIT 20;
-- QUERY 3: Recency Distribution
WITH reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
),
customer_recency AS (
    SELECT customer_id,
        rd.max_date - MAX(transaction_date) AS recency_days
    FROM bank_transactions
        CROSS JOIN reference_date rd
    GROUP BY customer_id,
        rd.max_date
),
recency_groups AS (
    SELECT CASE
            WHEN recency_days = 0 THEN '0 Days'
            WHEN recency_days BETWEEN 1 AND 7 THEN '1-7 Days'
            WHEN recency_days BETWEEN 8 AND 15 THEN '8-15 Days'
            WHEN recency_days BETWEEN 16 AND 30 THEN '16-30 Days'
            WHEN recency_days BETWEEN 31 AND 60 THEN '31-60 Days'
            WHEN recency_days BETWEEN 61 AND 90 THEN '61-90 Days'
            ELSE 'Above 90 Days'
        END AS recency_group,
        customer_id
    FROM customer_recency
)
SELECT recency_group,
    COUNT(*) AS total_customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage
FROM recency_groups
GROUP BY recency_group
ORDER BY CASE
        recency_group
        WHEN '0 Days' THEN 1
        WHEN '1-7 Days' THEN 2
        WHEN '8-15 Days' THEN 3
        WHEN '16-30 Days' THEN 4
        WHEN '31-60 Days' THEN 5
        WHEN '61-90 Days' THEN 6
        ELSE 7
    END;
-- QUERY 4: Frequency Distribution
WITH customer_frequency AS (
    SELECT customer_id,
        COUNT(*) AS frequency
    FROM bank_transactions
    GROUP BY customer_id
)
SELECT CASE
        WHEN frequency = 1 THEN '1 Transaction'
        WHEN frequency BETWEEN 2 AND 3 THEN '2-3 Transactions'
        WHEN frequency BETWEEN 4 AND 5 THEN '4-5 Transactions'
        ELSE '6+ Transactions'
    END AS frequency_group,
    COUNT(*) AS total_customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage
FROM customer_frequency
GROUP BY 1
ORDER BY MIN(frequency);

-- QUERY 5: Monetary Value Distribution

WITH customer_monetary AS (
    SELECT
        customer_id,
        SUM(transaction_amount) AS monetary_value
    FROM bank_transactions
    GROUP BY customer_id
),
monetary_groups AS (
    SELECT
        CASE
            WHEN monetary_value = 0 THEN 'Zero Value'
            WHEN monetary_value <= 500 THEN 'Up to 500'
            WHEN monetary_value <= 2000 THEN '501-2000'
            WHEN monetary_value <= 10000 THEN '2001-10000'
            WHEN monetary_value <= 50000 THEN '10001-50000'
            ELSE 'Above 50000'
        END AS monetary_group,
        monetary_value
    FROM customer_monetary
)
SELECT
    monetary_group,
    COUNT(*) AS total_customers,
    ROUND(SUM(monetary_value), 2) AS total_transaction_value,
    ROUND(AVG(monetary_value), 2) AS avg_customer_value
FROM monetary_groups
GROUP BY monetary_group
ORDER BY
    CASE monetary_group
        WHEN 'Zero Value' THEN 1
        WHEN 'Up to 500' THEN 2
        WHEN '501-2000' THEN 3
        WHEN '2001-10000' THEN 4
        WHEN '10001-50000' THEN 5
        ELSE 6
    END;


-- QUERY 6: Corrected RFM Scoring

WITH customer_rfm AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS frequency,
        SUM(transaction_amount) AS monetary_value
    FROM bank_transactions
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
),
rfm_metrics AS (
    SELECT
        c.customer_id,
        r.max_date - c.last_transaction_date AS recency_days,
        c.frequency,
        c.monetary_value
    FROM customer_rfm c
    CROSS JOIN reference_date r
),
rfm_scores AS (
    SELECT
        *,
        CASE
            WHEN recency_days <= 7 THEN 5
            WHEN recency_days <= 30 THEN 4
            WHEN recency_days <= 60 THEN 3
            WHEN recency_days <= 90 THEN 2
            ELSE 1
        END AS recency_score,

        CASE
            WHEN frequency >= 6 THEN 5
            WHEN frequency >= 4 THEN 4
            WHEN frequency >= 2 THEN 3
            ELSE 1
        END AS frequency_score,

        CASE
            WHEN monetary_value > 50000 THEN 5
            WHEN monetary_value > 10000 THEN 4
            WHEN monetary_value > 2000 THEN 3
            WHEN monetary_value > 500 THEN 2
            ELSE 1
        END AS monetary_score
    FROM rfm_metrics
)
SELECT
    customer_id,
    recency_days,
    frequency,
    ROUND(monetary_value, 2) AS monetary_value,
    recency_score,
    frequency_score,
    monetary_score,
    recency_score + frequency_score + monetary_score AS rfm_total_score
FROM rfm_scores
ORDER BY rfm_total_score DESC, monetary_value DESC
LIMIT 20;


-- QUERY 7: Corrected RFM Customer Segments

WITH customer_rfm AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS frequency,
        SUM(transaction_amount) AS monetary_value
    FROM bank_transactions
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
),
rfm_metrics AS (
    SELECT
        c.customer_id,
        r.max_date - c.last_transaction_date AS recency_days,
        c.frequency,
        c.monetary_value
    FROM customer_rfm c
    CROSS JOIN reference_date r
),
rfm_scores AS (
    SELECT
        *,
        CASE
            WHEN recency_days <= 7 THEN 5
            WHEN recency_days <= 30 THEN 4
            WHEN recency_days <= 60 THEN 3
            WHEN recency_days <= 90 THEN 2
            ELSE 1
        END AS recency_score,

        CASE
            WHEN frequency >= 6 THEN 5
            WHEN frequency >= 4 THEN 4
            WHEN frequency >= 2 THEN 3
            ELSE 1
        END AS frequency_score,

        CASE
            WHEN monetary_value > 50000 THEN 5
            WHEN monetary_value > 10000 THEN 4
            WHEN monetary_value > 2000 THEN 3
            WHEN monetary_value > 500 THEN 2
            ELSE 1
        END AS monetary_score
    FROM rfm_metrics
),
rfm_segments AS (
    SELECT
        *,
        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4
                THEN 'High Value Customers'

            WHEN recency_score >= 4
             AND frequency_score >= 3
                THEN 'Potential Customers'

            WHEN recency_score >= 3
             AND frequency_score >= 3
                THEN 'Regular Customers'

            WHEN recency_score <= 2
             AND frequency_score >= 3
                THEN 'At Risk - Inactivity Proxy'

            WHEN frequency_score = 1
                THEN 'Low Engagement Customers'

            ELSE 'Other Customers'
        END AS customer_segment
    FROM rfm_scores
)
SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS customer_percentage,
    ROUND(SUM(monetary_value), 2) AS total_transaction_value,
    ROUND(AVG(monetary_value), 2) AS avg_customer_value,
    ROUND(AVG(recency_days), 2) AS avg_recency_days,
    ROUND(AVG(frequency), 2) AS avg_frequency
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_customers DESC;


-- QUERY 8: Corrected RFM Segment Performance

WITH customer_rfm AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS frequency,
        SUM(transaction_amount) AS monetary_value
    FROM bank_transactions
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM bank_transactions
),
rfm_metrics AS (
    SELECT
        c.customer_id,
        r.max_date - c.last_transaction_date AS recency_days,
        c.frequency,
        c.monetary_value
    FROM customer_rfm c
    CROSS JOIN reference_date r
),
rfm_scores AS (
    SELECT
        *,
        CASE
            WHEN recency_days <= 7 THEN 5
            WHEN recency_days <= 30 THEN 4
            WHEN recency_days <= 60 THEN 3
            WHEN recency_days <= 90 THEN 2
            ELSE 1
        END AS recency_score,

        CASE
            WHEN frequency >= 6 THEN 5
            WHEN frequency >= 4 THEN 4
            WHEN frequency >= 2 THEN 3
            ELSE 1
        END AS frequency_score,

        CASE
            WHEN monetary_value > 50000 THEN 5
            WHEN monetary_value > 10000 THEN 4
            WHEN monetary_value > 2000 THEN 3
            WHEN monetary_value > 500 THEN 2
            ELSE 1
        END AS monetary_score
    FROM rfm_metrics
),
rfm_segments AS (
    SELECT
        *,
        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4
                THEN 'High Value Customers'
            WHEN recency_score >= 4
             AND frequency_score >= 3
                THEN 'Potential Customers'
            WHEN recency_score >= 3
             AND frequency_score >= 3
                THEN 'Regular Customers'
            WHEN recency_score <= 2
             AND frequency_score >= 3
                THEN 'At Risk - Inactivity Proxy'
            WHEN frequency_score = 1
                THEN 'Low Engagement Customers'
            ELSE 'Other Customers'
        END AS customer_segment
    FROM rfm_scores
)
SELECT
    customer_segment,
    MIN(recency_days) AS min_recency_days,
    MAX(recency_days) AS max_recency_days,
    MIN(frequency) AS min_frequency,
    MAX(frequency) AS max_frequency,
    ROUND(MIN(monetary_value), 2) AS min_customer_value,
    ROUND(MAX(monetary_value), 2) AS max_customer_value
FROM rfm_segments
GROUP BY customer_segment
ORDER BY customer_segment;
