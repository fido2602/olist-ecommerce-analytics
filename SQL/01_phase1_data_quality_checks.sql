
-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 1: DATA QUALITY CHECKS
-- Database: olist_analytics
-- =====================================================

USE olist_analytics;

-- =====================================================
-- TABLE 1: CUSTOMERS — DATA QUALITY CHECKS
-- Source: olist_customers_dataset.csv
-- =====================================================

-- Check 1: Confirm the total number of customer records
SELECT COUNT(*) AS total_rows
FROM olist_customers;

-- Check 2: Inspect column names and data types
DESCRIBE olist_customers;

-- Check 3: Check for missing values in customer columns
SELECT
COUNT(*) AS total_records,
SUM(customer_id IS NULL) AS missing_customer_id,
SUM(customer_unique_id IS NULL) AS missing_unique_id,
SUM(customer_zip_code_prefix IS NULL) AS missing_zip_prefix,
SUM(customer_city IS NULL) AS missing_city,
SUM(customer_state IS NULL) AS missing_state
FROM olist_customers;

-- Check 4: Check uniqueness of customer_id
SELECT
COUNT(*) AS total_records,
COUNT(DISTINCT customer_id) AS distinct_customer_ids,
COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_id_count
FROM olist_customers;

-- Check 5: Check repeated customer_unique_id values
-- Repeated values can be legitimate: one person may have
-- multiple customer records associated with different orders.
SELECT
COUNT(*) AS total_records,
COUNT(DISTINCT customer_unique_id) AS distinct_unique_ids,
COUNT(*) - COUNT(DISTINCT customer_unique_id) AS repeated_id_count
FROM olist_customers;

-- Check 6: Inspect the most frequently repeated customer identities
SELECT
customer_unique_id,
COUNT(*) AS record_count
FROM olist_customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 10;

-- Check 7: Check for exact duplicate customer records
SELECT
customer_id,
customer_unique_id,
customer_zip_code_prefix,
customer_city,
customer_state,
COUNT(*) AS record_count
FROM olist_customers
GROUP BY
customer_id,
customer_unique_id,
customer_zip_code_prefix,
customer_city,
customer_state
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 10;

-- Check 8: Inspect customer state codes and record counts
SELECT
customer_state,
COUNT(*) AS customer_records
FROM olist_customers
GROUP BY customer_state
ORDER BY customer_records DESC;

-- Check 9: Check for missing, blank, or unexpected state codes
SELECT
COUNT(*) AS total_records,
SUM(customer_state IS NULL) AS null_states,
SUM(TRIM(customer_state) = '') AS blank_states,
SUM(
customer_state IS NOT NULL
AND TRIM(customer_state) <> ''
AND customer_state NOT IN (
'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF',
'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA',
'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS',
'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
)
) AS unexpected_state_codes
FROM olist_customers;

-- Check 10: Validate ZIP-code prefix format
-- Expected format: exactly five numeric characters.
SELECT
COUNT(*) AS total_records,
SUM(customer_zip_code_prefix IS NULL) AS null_prefixes,
SUM(
customer_zip_code_prefix IS NOT NULL
AND TRIM(customer_zip_code_prefix) = ''
) AS blank_prefixes,
SUM(
customer_zip_code_prefix IS NOT NULL
AND customer_zip_code_prefix NOT REGEXP '^[0-9]{5}$'
) AS invalid_prefixes
FROM olist_customers;

-- =====================================================
-- CUSTOMERS: VALIDATION SUMMARY
-- =====================================================
-- Expected row count: 99,441.
-- customer_id: 99,441 distinct values; no duplicates.
-- customer_unique_id: 96,096 distinct values.
-- Repeated customer_unique_id values are not automatically errors.
-- Exact duplicate customer records: 0.
-- Missing values: 0 across the five columns.
-- State codes: 27 expected Brazilian state/DF codes.
-- ZIP-prefix format violations: 0 after the previous correction.
-- Note: ZIP format validation checks structure, not official
-- postal-address validity.
-- Cross-table checks are maintained in the relationship script.
-- Historical UPDATE and ALTER TABLE operations are intentionally
-- excluded from this repeatable validation section.


-- =====================================================
-- TABLE 2: ORDERS — DATA QUALITY CHECKS
-- Source: olist_orders_dataset.csv
-- =====================================================

-- Check 1: Confirm the total number of order records
SELECT COUNT(*) AS total_rows
FROM olist_orders_dataset;

-- Check 2: Inspect column names and data types
DESCRIBE olist_orders_dataset;

-- Check 3: Check missing values across all order columns
SELECT
    COUNT(*) AS total_records,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(order_status IS NULL) AS missing_order_status,
    SUM(order_purchase_timestamp IS NULL) AS missing_purchase_timestamp,
    SUM(order_approved_at IS NULL) AS missing_approved_at,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS missing_customer_date,
    SUM(order_estimated_delivery_date IS NULL) AS missing_estimated_delivery_date
FROM olist_orders_dataset;

-- Check 4: Verify order ID uniqueness and completeness
SELECT
    COUNT(*) AS total_records,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_or_null_count
FROM olist_orders_dataset;

-- Check 5: Check for exact duplicate order records
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    COUNT(*) AS record_count
FROM olist_orders_dataset
GROUP BY
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 25;

-- Check 6: Inspect order-status distribution
SELECT
    order_status,
    COUNT(*) AS order_count
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY order_count DESC;

-- Check 7: Check for missing, blank, or whitespace-padded statuses
SELECT
    COUNT(*) AS total_records,
    SUM(order_status IS NULL) AS null_statuses,
    SUM(
        order_status IS NOT NULL
        AND TRIM(order_status) = ''
    ) AS blank_statuses,
    SUM(
        order_status IS NOT NULL
        AND order_status <> TRIM(order_status)
    ) AS whitespace_padded_statuses
FROM olist_orders_dataset;

-- Check 8: Check for blank order and customer IDs
SELECT
    SUM(order_id IS NOT NULL AND TRIM(order_id) = '')
        AS blank_order_ids,
    SUM(customer_id IS NOT NULL AND TRIM(customer_id) = '')
        AS blank_customer_ids
FROM olist_orders_dataset;

-- Check 9: Check whether one order ID has multiple statuses
SELECT
    order_id,
    COUNT(DISTINCT order_status) AS distinct_status_count
FROM olist_orders_dataset
GROUP BY order_id
HAVING COUNT(DISTINCT order_status) > 1;

-- Check 10: Inspect timestamp ranges
SELECT
    MIN(order_purchase_timestamp) AS earliest_purchase,
    MAX(order_purchase_timestamp) AS latest_purchase,
    MIN(order_approved_at) AS earliest_approval,
    MAX(order_approved_at) AS latest_approval,
    MIN(order_delivered_carrier_date) AS earliest_carrier_date,
    MAX(order_delivered_carrier_date) AS latest_carrier_date,
    MIN(order_delivered_customer_date) AS earliest_delivery,
    MAX(order_delivered_customer_date) AS latest_delivery,
    MIN(order_estimated_delivery_date) AS earliest_estimated_delivery,
    MAX(order_estimated_delivery_date) AS latest_estimated_delivery
FROM olist_orders_dataset;

-- Check 11: Count timestamps outside the broad source-data period
-- Expected period used in this project: 2016-09-01 to 2018-12-01.
-- NULL timestamps are evaluated separately in Check 3.
SELECT
    SUM(
        order_purchase_timestamp < '2016-09-01'
        OR order_purchase_timestamp >= '2018-12-01'
    ) AS purchase_outside_period,
    SUM(
        order_approved_at < '2016-09-01'
        OR order_approved_at >= '2018-12-01'
    ) AS approval_outside_period,
    SUM(
        order_delivered_carrier_date < '2016-09-01'
        OR order_delivered_carrier_date >= '2018-12-01'
    ) AS carrier_outside_period,
    SUM(
        order_delivered_customer_date < '2016-09-01'
        OR order_delivered_customer_date >= '2018-12-01'
    ) AS delivery_outside_period,
    SUM(
        order_estimated_delivery_date < '2016-09-01'
        OR order_estimated_delivery_date >= '2018-12-01'
    ) AS estimated_delivery_outside_period
FROM olist_orders_dataset;

-- Check 12: Count timestamp chronology anomalies
-- These are investigation flags, not automatic proof of bad data.
SELECT
    SUM(
        order_approved_at IS NOT NULL
        AND order_approved_at < order_purchase_timestamp
    ) AS approval_before_purchase,
    SUM(
        order_delivered_carrier_date IS NOT NULL
        AND order_approved_at IS NOT NULL
        AND order_delivered_carrier_date < order_approved_at
    ) AS carrier_before_approval,
    SUM(
        order_delivered_customer_date IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date < order_delivered_carrier_date
    ) AS delivery_before_carrier
FROM olist_orders_dataset;

-- Check 13: Count delivered orders completed after estimated delivery
SELECT
    COUNT(*) AS late_delivered_orders,
    ROUND(
        COUNT(*) * 100.0 /
        NULLIF(
            (SELECT COUNT(*)
             FROM olist_orders_dataset
             WHERE order_status = 'delivered'),
            0
        ),
        2
    ) AS percent_of_delivered_orders
FROM olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_delivered_customer_date > order_estimated_delivery_date;

-- Check 14: Reconcile status-group counts with the table row count
SELECT
    SUM(status_count) AS total_rows_from_status_groups,
    (SELECT COUNT(*) FROM olist_orders_dataset) AS total_table_rows
FROM (
    SELECT
        order_status,
        COUNT(*) AS status_count
    FROM olist_orders_dataset
    GROUP BY order_status
) AS status_summary;


-- =====================================================
-- TABLE: ORDERS
-- CHECK: Missing timestamps
-- Source: olist_orders_dataset
-- Purpose: Identify missing order dates after converting
--          timestamp columns to DATETIME.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(order_purchase_timestamp IS NULL) AS missing_purchase_timestamp,
    SUM(order_approved_at IS NULL) AS missing_approved_timestamp,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_timestamp,
    SUM(order_delivered_customer_date IS NULL) AS missing_customer_timestamp,
    SUM(order_estimated_delivery_date IS NULL) AS missing_estimated_delivery_timestamp
FROM olist_orders_dataset;

-- =====================================================
-- ORDERS: VALIDATION SUMMARY
-- =====================================================
-- Source row count: 99,441; imported row count: 99,441.
-- order_id: 99,441 distinct IDs; no duplicate IDs.
-- Exact duplicate order records: 0.
-- Missing values are present in several optional timestamps.
-- Status distribution and missing/blank status checks completed.
-- Timestamp chronology anomalies were identified and investigated.
-- Late-delivery count was measured against estimated delivery dates.
-- Orders-to-Customers relationship checks belong in the relationship file.
-- No data-changing statements are included in this section.



-- =====================================================
-- TABLE 3: ORDER ITEMS — DATA QUALITY CHECKS
-- Table: olist_order_items_dataset
-- Source: olist_order_items_dataset.csv
-- =====================================================

-- Check 1: Confirm the total number of order-item records
SELECT COUNT(*) AS total_rows
FROM olist_order_items_dataset;

-- Check 2: Inspect column names and data types
DESCRIBE olist_order_items_dataset;

-- Check 3: Check for missing values
SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(order_item_id IS NULL) AS missing_order_item_id,
    SUM(product_id IS NULL) AS missing_product_id,
    SUM(seller_id IS NULL) AS missing_seller_id,
    SUM(shipping_limit_date IS NULL) AS missing_shipping_limit_date,
    SUM(price IS NULL) AS missing_price,
    SUM(freight_value IS NULL) AS missing_freight_value
FROM olist_order_items_dataset;

-- Check 4: Validate the composite key
-- Each order_id + order_item_id combination should be unique.
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS duplicate_count
FROM olist_order_items_dataset
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- Check 5: Validate price, freight, and shipping-date ranges
SELECT
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    SUM(price < 0) AS negative_price_count,
    MIN(freight_value) AS min_freight_value,
    MAX(freight_value) AS max_freight_value,
    SUM(freight_value < 0) AS negative_freight_count,
    MIN(shipping_limit_date) AS earliest_shipping_limit,
    MAX(shipping_limit_date) AS latest_shipping_limit
FROM olist_order_items_dataset;

-- Check 6: Inspect shipping-limit dates from 2019 onward
-- These four records were previously checked against the source CSV.
SELECT
    COUNT(*) AS records_from_2019_onwards,
    MIN(shipping_limit_date) AS earliest_shipping_limit,
    MAX(shipping_limit_date) AS latest_shipping_limit
FROM olist_order_items_dataset
WHERE shipping_limit_date >= '2019-01-01';

-- Check 7: Validate order_item_id values
SELECT
    MIN(order_item_id) AS min_order_item_id,
    MAX(order_item_id) AS max_order_item_id,
    SUM(order_item_id <= 0) AS non_positive_order_item_ids,
    COUNT(DISTINCT order_item_id) AS distinct_item_numbers,
    SUM(order_item_id IS NULL) AS missing_item_numbers
FROM olist_order_items_dataset;

-- Check 8: Check the distribution of item positions
SELECT
    order_item_id AS item_number,
    COUNT(*) AS records
FROM olist_order_items_dataset
GROUP BY order_item_id
ORDER BY item_number;

-- Check 9: Count zero-valued prices and freight amounts
-- Zero freight is not automatically an error.
SELECT
    SUM(price = 0) AS zero_price_count,
    SUM(freight_value = 0) AS zero_freight_count,
    SUM(price = 0 AND freight_value = 0) AS both_zero_count
FROM olist_order_items_dataset;

-- Check 10: Check monetary decimal precision
SELECT
    SUM(price <> ROUND(price, 2))
        AS price_more_than_2_decimals,
    SUM(freight_value <> ROUND(freight_value, 2))
        AS freight_more_than_2_decimals
FROM olist_order_items_dataset;

-- Check 11: Reconcile total item rows with grouped item counts
-- This is a table-level reconciliation; relationship-specific
-- summaries remain in the relationship validation file.
SELECT
    COUNT(*) AS total_item_rows,
    (
        SELECT SUM(item_count)
        FROM (
            SELECT order_id, COUNT(*) AS item_count
            FROM olist_order_items_dataset
            GROUP BY order_id
        ) AS order_item_counts
    ) AS summed_item_counts
FROM olist_order_items_dataset;

-- =====================================================
-- ORDER ITEMS: VALIDATION SUMMARY
-- =====================================================
-- Source CSV rows: 112,650.
-- MySQL rows: 112,650; source count manually confirmed.
-- Composite key: (order_id, order_item_id).
-- order_item_id is stored as INT NOT NULL.
-- price and freight_value are stored as DECIMAL(10,2) NOT NULL.
-- Price range: 0.85 to 6,735.00.
-- Freight range: 0.00 to 409.68.
-- Negative prices: 0.
-- Negative freight values: 0.
-- Values flagged for more than two decimal places: 0.
-- Zero prices: 0; zero freight values: 383.
-- Shipping-limit dates from 2019 onward: 4; source-checked.
-- Order Items to Orders checks belong in the relationship file.
-- Historical ALTER TABLE statements are intentionally excluded.



-- =====================================================
-- TABLE 4: ORDER PAYMENTS
-- Table: olist_order_payments_dataset
-- =====================================================

-- Check 1: Confirm total row count
-- Purpose: Count payment records imported into MySQL
-- Expected: 103,886 rows, confirmed against source CSV

SELECT COUNT(*) AS total_rows
FROM olist_order_payments_dataset;


-- Check 2: Inspect column names and data types
-- Purpose: Confirm the imported table structure

DESCRIBE olist_order_payments_dataset;


-- Check 3: Check for missing values
-- Purpose: Count NULL values in each column

SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(payment_sequential IS NULL) AS missing_payment_sequential,
    SUM(payment_type IS NULL) AS missing_payment_type,
    SUM(payment_installments IS NULL) AS missing_payment_installments,
    SUM(payment_value IS NULL) AS missing_payment_value
FROM olist_order_payments_dataset;


-- Check 4: Review payment type categories
-- Purpose: Identify each payment type and its record count

SELECT
    payment_type,
    COUNT(*) AS record_count
FROM olist_order_payments_dataset
GROUP BY payment_type
ORDER BY record_count DESC;


-- Check 5: Check for blank text values
-- Purpose: Identify empty or whitespace-only identifiers
-- and payment types
SELECT
    SUM(TRIM(order_id) = '') AS blank_order_id,
    SUM(TRIM(payment_type) = '') AS blank_payment_type
FROM olist_order_payments_dataset;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 6: Validate payment sequence numbers
-- Purpose: Inspect the minimum, maximum, and
-- non-positive payment sequence values
-- =====================================================

SELECT
    MIN(payment_sequential) AS minimum_sequence,
    MAX(payment_sequential) AS maximum_sequence,
    SUM(payment_sequential <= 0) AS non_positive_sequences,
    COUNT(DISTINCT payment_sequential) AS distinct_sequence_values
FROM olist_order_payments_dataset;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 7: Validate payment installment counts
-- Purpose: Identify the range and any non-positive
-- installment values
-- =====================================================

SELECT
    MIN(payment_installments) AS minimum_installments,
    MAX(payment_installments) AS maximum_installments,
    SUM(payment_installments <= 0) AS non_positive_installments,
    COUNT(DISTINCT payment_installments) AS distinct_installment_values
FROM olist_order_payments_dataset;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 8: Inspect non-positive installment values
-- Purpose: Identify the exact rows with zero or
-- negative payment installments
-- =====================================================

SELECT
    order_id,payment_sequential,payment_type,payment_installments,payment_value
FROM olist_order_payments_dataset
WHERE payment_installments <= 0
ORDER BY order_id;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 10: Validate payment amounts
-- Purpose: Inspect the range and identify zero or
-- negative payment values
-- =====================================================

SELECT
    MIN(payment_value) AS minimum_payment_value,
    MAX(payment_value) AS maximum_payment_value,
    SUM(payment_value = 0) AS zero_payment_values,
    SUM(payment_value < 0) AS negative_payment_values
FROM olist_order_payments_dataset;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 11: Inspect zero-value payment records
-- Purpose: Review payment details and order statuses
-- before deciding whether zero amounts are valid
-- =====================================================

SELECT
    p.order_id,p.payment_sequential,p.payment_type,p.payment_installments,p.payment_value,o.order_status
FROM olist_order_payments_dataset AS p
LEFT JOIN olist_orders_dataset AS o
    ON p.order_id = o.order_id
WHERE p.payment_value = 0
ORDER BY o.order_status, p.order_id;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 12: Inspect all payment rows for zero-value
-- voucher orders
-- Purpose: Determine whether zero-value vouchers
-- appear alongside other payment methods
-- =====================================================

SELECT
    p.order_id,p.payment_sequential,p.payment_type,p.payment_installments,p.payment_value,o.order_status
FROM olist_order_payments_dataset AS p
LEFT JOIN olist_orders_dataset AS o
    ON p.order_id = o.order_id
WHERE p.order_id IN (
    '45ed6e85398a87c253db47c2d9f48216',
    '6ccb433e00daae1283ccc956189c82ae',
    '8bcbe01d44d147f901cd3192671144db',
    'b23878b3e8eb4d25a158f57d96331b18',
    'fa65dad1b0e818e3ccc5cb0e39231352'
)
ORDER BY p.order_id, p.payment_sequential;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 13: Confirm complete payment sequence for
-- the order with multiple zero-value voucher entries
-- =====================================================

SELECT
    order_id,payment_sequential,payment_type,payment_installments,payment_value
FROM olist_order_payments_dataset
WHERE order_id = 'fa65dad1b0e818e3ccc5cb0e39231352'
ORDER BY payment_sequential;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 14: Recheck zero-value rows for this order
-- Purpose: Confirm whether sequence numbers 13 and
-- 14 are present in the current table
-- =====================================================

SELECT
    order_id,payment_sequential,payment_type,payment_value
FROM olist_order_payments_dataset
WHERE order_id = 'fa65dad1b0e818e3ccc5cb0e39231352'
  AND payment_value = 0;
  
  -- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 16: Reconfirm zero-value payment records
-- Purpose: Create a definitive list for source review
-- =====================================================

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_value
FROM olist_order_payments_dataset
WHERE payment_value = 0
ORDER BY order_id, payment_sequential;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 17: Cross-check zero payment values and
-- non-positive installment counts
-- Purpose: Identify records with both conditions
-- =====================================================

SELECT
    SUM(payment_value = 0 AND payment_installments <= 0)
        AS zero_value_and_nonpositive_installments,
    SUM(payment_value > 0 AND payment_installments <= 0)
        AS positive_value_and_nonpositive_installments,
    SUM(payment_value = 0 AND payment_installments > 0)
        AS zero_value_and_positive_installments
FROM olist_order_payments_dataset;

-- Finding:
-- 0 rows have both zero payment value and non-positive installments.
-- 2 rows have positive payment value and zero installments.
-- 2 rows have zero payment value and positive installments.
-- The two zero-installment records were verified against the source CSV.
-- All nine zero-value payment records were verified against the source CSV.
-- No data was modified; these source-data observations are retained.

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 18: Check payment amount decimal precision
-- Purpose: Identify values with more than two
-- decimal places
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(
        ABS(payment_value - ROUND(payment_value, 2)) > 0.000001
    ) AS values_with_more_than_two_decimals
FROM olist_order_payments_dataset;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 19: Summarize payment values by payment type
-- Purpose: Review payment ranges and totals by type
-- =====================================================

SELECT
    payment_type,
    COUNT(*) AS payment_rows,
    MIN(payment_value) AS minimum_payment_value,
    MAX(payment_value) AS maximum_payment_value,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM olist_order_payments_dataset
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 20: Validate order ID coverage
-- Purpose: Compare total rows with distinct orders
-- and identify repeated order IDs
-- =====================================================

SELECT
    COUNT(*) AS total_payment_rows,
    COUNT(order_id) AS nonnull_order_ids,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT order_id) AS rows_beyond_one_per_order
FROM olist_order_payments_dataset;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 21: Identify orders with multiple payment rows
-- Purpose: Measure repeated payment records per order
-- =====================================================

SELECT
    COUNT(*) AS orders_with_multiple_payment_rows,
    MAX(payment_row_count) AS maximum_rows_for_one_order
FROM (
    SELECT
        order_id,
        COUNT(*) AS payment_row_count
    FROM olist_order_payments_dataset
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS payment_counts;

-- =====================================================
-- Phase 1 | Table 4: Order Payments
-- Check 22: Check for duplicate payment sequence pairs
-- Purpose: Identify repeated order_id + payment_sequential
-- combinations
-- =====================================================

SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS duplicate_count
FROM olist_order_payments_dataset
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, order_id;

-- =====================================================
-- Payments Table: Validation Summary
-- =====================================================
-- Source row count: 103,886; MySQL row count: 103,886.
-- NULL counts: 0 across all five columns.
-- Blank order_id and payment_type counts: 0.
-- Payment types: credit_card, boleto, voucher,
-- debit_card, not_defined.
-- Non-positive payment sequence values: 0.
-- Zero payment values: 9; negative payment values: 0.
-- Values flagged for more than two decimal places: 0.
-- Zero installment values: 2; both verified in source CSV.
-- All nine zero-value payment records verified in source CSV.
-- Distinct orders: 99,440.
-- Orders with multiple payment rows: 2,961.
-- Maximum payment rows for one order: 29.
-- Duplicate (order_id, payment_sequential) pairs: 0.
-- No payment data was modified during these checks.


-- =====================================================
-- TABLE 5: ORDER REVIEWS — DATA QUALITY CHECKS
-- Source: olist_order_reviews_dataset.csv
-- =====================================================
-- Check 1: Verify the total number of imported records.
SELECT COUNT(*) AS total_rows
FROM olist_order_reviews_dataset;


-- =====================================================
-- TABLE 5: ORDER REVIEWS — STAGING TABLE CREATION
-- Source: olist_order_reviews_dataset.csv
-- Purpose: Create a fresh table for importing and
-- validating all Order Reviews records.
-- =====================================================

CREATE TABLE olist_order_reviews_stage (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date VARCHAR(30),
    review_answer_timestamp VARCHAR(30)
);

-- Confirm the staging table has been created.
DESCRIBE olist_order_reviews_stage;



-- =====================================================
-- TABLE 5: ORDER REVIEWS — STAGING TABLE CHECK
-- Source: olist_order_reviews_dataset.csv
-- Purpose: Check whether a staging table already exists
-- before creating another table.
-- =====================================================

SHOW TABLES LIKE 'olist_order_reviews_stage';

-- =====================================================
-- TABLE 5: ORDER REVIEWS — STAGING TABLE ROW COUNT
-- Source: olist_order_reviews_dataset.csv
-- Purpose: Confirm the staging table is empty before
-- loading the source CSV.
-- =====================================================

SELECT COUNT(*) AS total_rows
FROM olist_order_reviews_stage;


-- =====================================================
-- TABLE 5: ORDER REVIEWS — CSV DATA IMPORT
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Import all source records into the empty
-- staging table while preserving raw date/time values.
-- =====================================================

LOAD DATA LOCAL INFILE
'C:/Users/riodo/OneDrive/Desktop/Olist_Flagship_Project/Raw Data/olist_order_reviews_dataset.csv/olist_order_reviews_dataset.csv'
INTO TABLE olist_order_reviews_stage
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
);

-- =====================================================
-- TABLE 5: ORDER REVIEWS — IMPORT WARNING VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Inspect warnings produced by the CSV import.
-- =====================================================





-- =====================================================
-- TABLE 5: ORDER REVIEWS — IMPORT WARNING VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Inspect warnings produced by the CSV import.
-- =====================================================


-- =====================================================
-- TABLE 5: ORDER REVIEWS — LOCAL IMPORT CONFIGURATION
-- Source: MySQL server configuration
-- Purpose: Check whether local CSV loading is enabled
-- on the server.
-- =====================================================

SHOW GLOBAL VARIABLES LIKE 'local_infile';

-- =====================================================
-- TABLE 5: ORDER REVIEWS — ENABLE LOCAL CSV IMPORT
-- Purpose: Allow the MySQL server to accept LOCAL INFILE
-- imports for the current server runtime.
-- =====================================================

SET GLOBAL local_infile = 1;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — CLIENT IMPORT SETTING CHECK
-- Purpose: Verify the current session's local-infile
-- capability before retrying the CSV import.
-- =====================================================

SHOW SESSION VARIABLES LIKE 'local_infile';

-- =====================================================
-- TABLE 5: ORDER REVIEWS — IMPORT ROW COUNT VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Confirm the total number of imported records.
-- Expected source row count: 99,224
-- =====================================================

SELECT COUNT(*) AS total_rows
FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — SAMPLE RECORD VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Inspect imported values across all seven
-- columns for obvious parsing or alignment issues.
-- =====================================================

SELECT *
FROM olist_order_reviews_stage
LIMIT 5;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — TIMESTAMP FORMAT VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Identify carriage returns and unexpected
-- formatting in review date and answer timestamp fields.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(review_creation_date LIKE '%\r%') AS creation_date_cr_count,
    SUM(review_answer_timestamp LIKE '%\r%') AS answer_timestamp_cr_count,
    SUM(review_creation_date IS NULL OR review_creation_date = '') AS missing_creation_dates,
    SUM(review_answer_timestamp IS NULL OR review_answer_timestamp = '') AS missing_answer_timestamps
FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — CARRIAGE RETURN INSPECTION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Confirm the trailing character in answer
-- timestamps before planning a safe cleanup.
-- =====================================================

SELECT
    review_id,
    review_answer_timestamp,
    HEX(RIGHT(review_answer_timestamp, 1)) AS final_character_hex
FROM olist_order_reviews_stage
LIMIT 5;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — TIMESTAMP CLEANUP
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Remove trailing carriage-return characters
-- from review answer timestamps before date validation.
-- =====================================================

set sql_safe_updates=0;

UPDATE olist_order_reviews_stage
SET review_answer_timestamp = TRIM(TRAILING '\r' FROM review_answer_timestamp)
WHERE review_answer_timestamp LIKE CONCAT('%', CHAR(13));

-- =====================================================
-- TABLE 5: ORDER REVIEWS — TIMESTAMP CLEANUP VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Confirm trailing carriage returns were
-- removed and the total row count remains unchanged.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(review_answer_timestamp LIKE CONCAT('%', CHAR(13)))
        AS remaining_carriage_returns
FROM olist_order_reviews_stage;

set sql_safe_updates=1;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DATA FORMAT VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Check review scores and date/time formats
-- before converting the raw text columns to DATETIME.
-- =====================================================

SELECT
COUNT(*) AS total_rows,

    SUM(review_score IS NULL OR review_score NOT BETWEEN 1 AND 5)
        AS invalid_review_scores,

    SUM(
        review_creation_date IS NULL
        OR review_creation_date NOT REGEXP
           '^[0-9]{4}-[0-9]{2}-[0-9]{2} 00:00:00$'
    ) AS invalid_creation_dates,

    SUM(
        review_answer_timestamp IS NULL
        OR review_answer_timestamp NOT REGEXP
           '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
    ) AS invalid_answer_timestamps

FROM olist_order_reviews_stage;


-- =====================================================
-- TABLE 5: ORDER REVIEWS — CREATION DATE EXCEPTIONS
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Inspect creation-date values that failed
-- the expected format check before deciding on cleanup.
-- =====================================================

SELECT
    review_id,
    review_creation_date,
    HEX(review_creation_date) AS creation_date_hex
FROM olist_order_reviews_stage
WHERE review_creation_date IS NULL
   OR review_creation_date NOT REGEXP
      '^[0-9]{4}-[0-9]{2}-[0-9]{2} 00:00:00$'
LIMIT 20;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — CREATION DATE VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Validate the expected date/time structure
-- without incorrectly requiring midnight timestamps.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(
        review_creation_date IS NULL
        OR review_creation_date NOT REGEXP
           '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
    ) AS invalid_creation_dates
FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — REVIEW ID VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Check missing IDs and duplicate review IDs
-- before creating the final analytical table.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(review_id IS NULL OR TRIM(review_id) = '')
        AS missing_review_ids,
    COUNT(DISTINCT review_id) AS distinct_review_ids
FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DUPLICATE ID INVESTIGATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Count repeated review IDs and determine
-- how many rows belong to duplicated IDs.
-- =====================================================

SELECT
    COUNT(*) AS duplicated_review_id_count,
    SUM(id_counts.id_rows) AS rows_with_duplicated_ids
FROM (
    SELECT
        review_id,
        COUNT(*) AS id_rows
    FROM olist_order_reviews_stage
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS id_counts;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DUPLICATE ID INVESTIGATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Inspect the most frequently repeated review
-- IDs before determining whether records are duplicates.
-- =====================================================

SELECT
    review_id,
    COUNT(*) AS occurrences
FROM olist_order_reviews_stage
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC, review_id
LIMIT 10;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DUPLICATE RECORD INSPECTION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Compare every record for one review ID
-- that appears multiple times.
-- =====================================================

SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM olist_order_reviews_stage
WHERE review_id = '08528f70f579f0c830189efc523d2182';

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DUPLICATE PATTERN ANALYSIS
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Determine whether repeated review IDs are
-- associated with multiple distinct orders.
-- =====================================================

SELECT
    review_id,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT review_score) AS distinct_scores
FROM olist_order_reviews_stage
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY distinct_orders DESC, total_rows DESC
LIMIT 10;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DUPLICATE PATTERN SUMMARY
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Quantify repeated review IDs linked to
-- multiple orders versus repeated IDs for one order.
-- =====================================================

SELECT
    CASE
        WHEN distinct_orders > 1
            THEN 'Multiple distinct orders'
        ELSE 'One distinct order'
    END AS order_pattern,
    COUNT(*) AS repeated_review_ids,
    SUM(total_rows) AS associated_rows
FROM (
    SELECT
        review_id,
        COUNT(*) AS total_rows,
        COUNT(DISTINCT order_id) AS distinct_orders
    FROM olist_order_reviews_stage
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS duplicate_summary
GROUP BY
    CASE
        WHEN distinct_orders > 1
            THEN 'Multiple distinct orders'
        ELSE 'One distinct order'
    END;
    
    -- =====================================================
-- TABLE 5: ORDER REVIEWS — REVIEW CONTENT CONSISTENCY
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Check whether repeated review IDs have
-- consistent review content across different orders.
-- =====================================================

SELECT
    COUNT(*) AS repeated_ids_checked,
    SUM(content_versions = 1) AS ids_with_consistent_content,
    SUM(content_versions > 1) AS ids_with_different_content
FROM (
    SELECT
        review_id,
        COUNT(
            DISTINCT CONCAT_WS(
                '|',
                COALESCE(CAST(review_score AS CHAR), '<NULL>'),
                COALESCE(review_comment_title, '<NULL>'),
                COALESCE(review_comment_message, '<NULL>'),
                COALESCE(review_creation_date, '<NULL>'),
                COALESCE(review_answer_timestamp, '<NULL>')
            )
        ) AS content_versions
    FROM olist_order_reviews_stage
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS review_content;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DUPLICATE FREQUENCY SUMMARY
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Count repeated review IDs by occurrence
-- frequency before deciding how to handle them.
-- =====================================================

SELECT
    occurrences,
    COUNT(*) AS review_id_count
FROM (
    SELECT
        review_id,
        COUNT(*) AS occurrences
    FROM olist_order_reviews_stage
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS repeated_ids
GROUP BY occurrences
ORDER BY occurrences;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — EXACT DUPLICATE CHECK
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Identify rows identical across all seven
-- columns, separately from repeated review IDs.
-- =====================================================

SELECT
    COUNT(*) AS exact_duplicate_groups,
    SUM(row_count - 1) AS extra_exact_duplicate_rows
FROM (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        COUNT(*) AS row_count
    FROM olist_order_reviews_stage
    GROUP BY
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    HAVING COUNT(*) > 1
) AS exact_duplicates;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — MISSING VALUE CHECK
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Count NULL and blank values in key fields
-- before finalizing the review data-quality assessment.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(order_id IS NULL OR TRIM(order_id) = '')
        AS missing_order_ids,

    SUM(review_score IS NULL)
        AS missing_review_scores,

    SUM(review_comment_title IS NULL
        OR TRIM(review_comment_title) = '')
        AS missing_review_titles,

    SUM(review_comment_message IS NULL
        OR TRIM(review_comment_message) = '')
        AS missing_review_messages,

    SUM(review_creation_date IS NULL
        OR TRIM(review_creation_date) = '')
        AS missing_creation_dates,

    SUM(review_answer_timestamp IS NULL
        OR TRIM(review_answer_timestamp) = '')
        AS missing_answer_timestamps

FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — SCORE VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Verify that review scores are integers
-- between 1 and 5, inclusive.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    MIN(review_score) AS minimum_score,
    MAX(review_score) AS maximum_score,
    SUM(
        review_score IS NULL
        OR review_score NOT BETWEEN 1 AND 5
    ) AS invalid_scores
FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — SCORE DISTRIBUTION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Measure review counts and percentages
-- for each valid review score.
-- =====================================================

SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM olist_order_reviews_stage),
        2
    ) AS percentage_of_reviews
FROM olist_order_reviews_stage
GROUP BY review_score
ORDER BY review_score;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — DATE RANGE VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Inspect the earliest and latest review
-- creation and answer timestamps before conversion.
-- =====================================================

SELECT
    MIN(review_creation_date) AS earliest_creation_date,
    MAX(review_creation_date) AS latest_creation_date,
    MIN(review_answer_timestamp) AS earliest_answer_timestamp,
    MAX(review_answer_timestamp) AS latest_answer_timestamp
FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — TIMESTAMP CHRONOLOGY CHECK
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Identify reviews answered before their
-- recorded creation timestamps.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(
        STR_TO_DATE(review_answer_timestamp, '%Y-%m-%d %H:%i:%s')
        <
        STR_TO_DATE(review_creation_date, '%Y-%m-%d %H:%i:%s')
    ) AS answers_before_creation
FROM olist_order_reviews_stage;

-- =====================================================
-- TABLE 5: ORDER REVIEWS — CALENDAR DATE VALIDATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Detect date strings that do not round-trip
-- through MySQL date parsing as expected.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(
        STR_TO_DATE(review_creation_date, '%Y-%m-%d %H:%i:%s') IS NULL
        OR DATE_FORMAT(
            STR_TO_DATE(review_creation_date, '%Y-%m-%d %H:%i:%s'),
            '%Y-%m-%d %H:%i:%s'
        ) <> review_creation_date
    ) AS invalid_creation_dates,

    SUM(
        STR_TO_DATE(review_answer_timestamp, '%Y-%m-%d %H:%i:%s') IS NULL
        OR DATE_FORMAT(
            STR_TO_DATE(review_answer_timestamp, '%Y-%m-%d %H:%i:%s'),
            '%Y-%m-%d %H:%i:%s'
        ) <> review_answer_timestamp
    ) AS invalid_answer_timestamps

FROM olist_order_reviews_stage;


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Validate row count and required fields
-- Source: olist_order_reviews_stage
-- Expected result: 99,224 rows and 0 missing values
-- for review_id, order_id, and review_score
-- =====================================================
SELECT
    COUNT(*) AS total_rows,
    SUM(
        review_id IS NULL OR TRIM(review_id) = ''
    ) AS missing_review_ids,
    SUM(
        order_id IS NULL OR TRIM(order_id) = ''
    ) AS missing_order_ids,
    SUM(review_score IS NULL) AS missing_review_scores
FROM olist_order_reviews_stage;

-- Actual result:
-- Total rows: 99,224
-- Missing review IDs: 0
-- Missing order IDs: 0
-- Missing review scores: 0
-- Status: PASS


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Validate review scores are between 1 and 5
-- Source: olist_order_reviews_stage
-- Expected result: 0 invalid scores
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(
        review_score IS NULL
        OR review_score < 1
        OR review_score > 5
    ) AS invalid_review_scores,
    MIN(review_score) AS minimum_score,
    MAX(review_score) AS maximum_score
FROM olist_order_reviews_stage;



-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Quantify missing optional review comments
-- Source: olist_order_reviews_stage
-- Expected result: Missing counts and percentages
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(
        review_comment_title IS NULL
        OR TRIM(review_comment_title) = ''
    ) AS missing_comment_titles,

    ROUND(
        100.0 * SUM(
            review_comment_title IS NULL
            OR TRIM(review_comment_title) = ''
        ) / COUNT(*),
        2
    ) AS missing_title_pct,

    SUM(
        review_comment_message IS NULL
        OR TRIM(review_comment_message) = ''
    ) AS missing_comment_messages,

    ROUND(
        100.0 * SUM(
            review_comment_message IS NULL
            OR TRIM(review_comment_message) = ''
        ) / COUNT(*),
        2
    ) AS missing_message_pct

FROM olist_order_reviews_stage;


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Validate review timestamp formats
-- Source: olist_order_reviews_stage
-- Expected result: 0 invalid timestamps
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(
        review_creation_date IS NULL
        OR TRIM(review_creation_date) = ''
        OR STR_TO_DATE(
            review_creation_date,
            '%Y-%m-%d %H:%i:%s'
        ) IS NULL
        OR DATE_FORMAT(
            STR_TO_DATE(
                review_creation_date,
                '%Y-%m-%d %H:%i:%s'
            ),
            '%Y-%m-%d %H:%i:%s'
        ) <> review_creation_date
    ) AS invalid_creation_dates,

    SUM(
        review_answer_timestamp IS NULL
        OR TRIM(review_answer_timestamp) = ''
        OR STR_TO_DATE(
            review_answer_timestamp,
            '%Y-%m-%d %H:%i:%s'
        ) IS NULL
        OR DATE_FORMAT(
            STR_TO_DATE(
                review_answer_timestamp,
                '%Y-%m-%d %H:%i:%s'
            ),
            '%Y-%m-%d %H:%i:%s'
        ) <> review_answer_timestamp
    ) AS invalid_answer_timestamps

FROM olist_order_reviews_stage;

-- Actual result:
-- Total rows: 99,224
-- Invalid creation dates: 0
-- Invalid answer timestamps: 0
-- Status: PASS
-- Decision: Timestamp values are valid and consistently
-- formatted; retain the source values in staging.


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Identify answers recorded before review
-- creation
-- Source: olist_order_reviews_stage
-- Expected result: 0 rows with answer before creation
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(
        STR_TO_DATE(
            review_answer_timestamp,
            '%Y-%m-%d %H:%i:%s'
        ) <
        STR_TO_DATE(
            review_creation_date,
            '%Y-%m-%d %H:%i:%s'
        )
    ) AS answers_before_creation
FROM olist_order_reviews_stage;

-- Actual result:
-- Total rows: 99,224
-- Answers before creation: 0
-- Status: PASS
-- Decision: No chronological inconsistencies detected.


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Identify exact duplicate records
-- Source: olist_order_reviews_stage
-- Expected result: 0 duplicate groups
-- =====================================================

SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    COUNT(*) AS duplicate_count
FROM olist_order_reviews_stage
GROUP BY
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Actual result:
-- Exact duplicate groups: 0
-- Status: PASS
-- Decision: No exact duplicate records identified.
-- No rows deleted.


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Confirm review timestamp coverage
-- Source: olist_order_reviews_stage
-- Expected result: Earliest and latest timestamps
-- =====================================================

SELECT
    MIN(
        STR_TO_DATE(
            review_creation_date,
            '%Y-%m-%d %H:%i:%s'
        )
    ) AS earliest_review_creation,
    MAX(
        STR_TO_DATE(
            review_creation_date,
            '%Y-%m-%d %H:%i:%s'
        )
    ) AS latest_review_creation,
    MIN(
        STR_TO_DATE(
            review_answer_timestamp,
            '%Y-%m-%d %H:%i:%s'
        )
    ) AS earliest_answer_timestamp,
    MAX(
        STR_TO_DATE(
            review_answer_timestamp,
            '%Y-%m-%d %H:%i:%s'
        )
    ) AS latest_answer_timestamp
FROM olist_order_reviews_stage;

-- Actual result:
-- Earliest review creation: 2016-10-02 00:00:00
-- Latest review creation: 2018-08-31 00:00:00
-- Earliest answer timestamp: 2016-10-07 18:32:28
-- Latest answer timestamp: 2018-10-29 12:27:35
-- Status: Documented
-- Decision: Timestamp coverage recorded for later analysis.


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Quantify review IDs linked to multiple orders
-- Source: olist_order_reviews_stage
-- Expected result: Anomaly count documented
-- =====================================================

SELECT
    COUNT(*) AS repeated_review_ids,
    SUM(order_count > 1) AS review_ids_linked_to_multiple_orders
FROM (
    SELECT
        review_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM olist_order_reviews_stage
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS repeated_ids;

-- Actual result:
-- Repeated review IDs: 789
-- Review IDs linked to multiple orders: 789
-- Status: Anomaly documented
-- Decision: Preserve all records; do not deduplicate
-- without further evidence or source documentation.


-- =====================================================
-- Phase 1 | Data Quality Check — Order Reviews
-- Purpose: Check content consistency for repeated IDs
-- Source: olist_order_reviews_stage
-- Expected result: No repeated IDs with conflicting
-- review content
-- =====================================================

SELECT
    COUNT(*) AS repeated_review_ids_checked,
    SUM(
        distinct_content_versions > 1
    ) AS review_ids_with_conflicting_content
FROM (
    SELECT
        review_id,
        COUNT(
            DISTINCT CONCAT_WS(
                '|',
                COALESCE(CAST(review_score AS CHAR), '<NULL>'),
                COALESCE(review_comment_title, '<NULL>'),
                COALESCE(review_comment_message, '<NULL>'),
                COALESCE(review_creation_date, '<NULL>'),
                COALESCE(review_answer_timestamp, '<NULL>')
            )
        ) AS distinct_content_versions
    FROM olist_order_reviews_stage
    GROUP BY review_id
    HAVING COUNT(*) > 1
) AS repeated_id_content;

-- Actual result:
-- Repeated review IDs checked: 789
-- Review IDs with conflicting content: 0
-- Status: Content consistency confirmed
-- Decision: Preserve all records. The repeated IDs
-- across different orders remain a source-data anomaly.




-- =====================================================
-- OLIST PRODUCTS: DATA QUALITY VALIDATION
-- Source: olist_products_stage
-- Expected source row count: 32,951
-- =====================================================



-- 1. Row count and product ID integrity
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids,
    SUM(product_id IS NULL) AS null_product_ids
FROM olist_products_stage;

-- 2. Missing descriptive attributes
SELECT
    SUM(product_name_lenght IS NULL) AS null_name_lengths,
    SUM(product_description_lenght IS NULL) AS null_description_lengths,
    SUM(product_photos_qty IS NULL) AS null_photo_quantities
FROM olist_products_stage;

-- 3. Missing weights and dimensions
SELECT
    SUM(product_weight_g IS NULL) AS null_weights,
    SUM(product_length_cm IS NULL) AS null_lengths,
    SUM(product_height_cm IS NULL) AS null_heights,
    SUM(product_width_cm IS NULL) AS null_widths,
    SUM(product_weight_g = 0) AS zero_weights
FROM olist_products_stage;




-- STEP 1: Check whether the production table already exists.
-- WHY: We must avoid accidentally overwriting an existing table.
-- EXPECTED: No rows returned if olist_products does not exist.

SHOW TABLES LIKE 'olist_products';

-- STEP 2A: Create an empty production table.
-- WHY: CREATE TABLE LIKE copies the column structure and data types
-- from the validated staging table without copying its data.
-- The staging table remains unchanged.

CREATE TABLE olist_products LIKE olist_products_stage;


-- STEP 2B: Copy the validated product records into the production table.
-- WHY: INSERT INTO ... SELECT copies all rows and columns.
-- It preserves the NULL values we've carefully corrected.
-- The source staging table is not modified.

INSERT INTO olist_products
SELECT *
FROM olist_products_stage;

-- STEP 3: Verify row counts, product ID integrity, and missing values.
-- WHY: We need evidence that the copied table contains the expected data
-- and that missing source values were preserved correctly.

SELECT
    COUNT(*) AS total_rows,  -- Total number of product records
    COUNT(DISTINCT product_id) AS distinct_product_ids, -- Unique IDs
    SUM(product_id IS NULL) AS null_product_ids, -- IDs that are missing
    SUM(product_name_lenght IS NULL) AS null_name_lengths, -- Missing name lengths
    SUM(product_description_lenght IS NULL) AS null_description_lengths, -- Missing description lengths
    SUM(product_photos_qty IS NULL) AS null_photo_quantities, -- Missing photo counts
    SUM(product_weight_g IS NULL) AS null_weights -- Missing product weights
FROM olist_products;

-- RESULT: olist_products contains 32,951 records and 32,951 distinct
-- product IDs. Missing descriptive values and weights are preserved
-- as NULL where present in the source data.
-- STATUS: PASS, pending completion of all production-table checks.


-- ============================================================
-- STEP 5: COMPLETE NULL AND ZERO-VALUE VALIDATION
-- Table: olist_products
-- Purpose: Check missing values and genuine zero values
-- ============================================================

-- WHY:
-- A missing value (NULL) is different from a genuine zero (0).
-- We must understand both before calculating averages or building
-- Power BI dashboards.

SELECT
    COUNT(*) AS total_rows,

    -- Check whether any product IDs are missing
    SUM(product_id IS NULL) AS null_product_ids,

    -- Check missing product categories
    SUM(product_category_name IS NULL) AS null_categories,

    -- Check missing descriptive attributes
    SUM(product_name_lenght IS NULL) AS null_name_lengths,
    SUM(product_description_lenght IS NULL) AS null_description_lengths,
    SUM(product_photos_qty IS NULL) AS null_photo_quantities,

    -- Check missing physical measurements
    SUM(product_weight_g IS NULL) AS null_weights,
    SUM(product_length_cm IS NULL) AS null_lengths,
    SUM(product_height_cm IS NULL) AS null_heights,
    SUM(product_width_cm IS NULL) AS null_widths,

    -- Check genuine zero weights separately from missing weights
    SUM(product_weight_g = 0) AS zero_weights,

    -- Check whether any physical measurements are zero
    SUM(product_length_cm = 0) AS zero_lengths,
    SUM(product_height_cm = 0) AS zero_heights,
    SUM(product_width_cm = 0) AS zero_widths

FROM olist_products;





-- ============================================================
-- STEP 6: DUPLICATE PRODUCT ID CHECK
-- Purpose: Confirm each product has a unique identifier.
-- ============================================================

-- WHY:
-- Duplicate IDs could cause incorrect joins, inflated counts,
-- and misleading Power BI results.

SELECT
    product_id,             -- Product identifier
    COUNT(*) AS occurrences  -- Number of times each ID appears
FROM olist_products
GROUP BY product_id
HAVING COUNT(*) > 1;         -- Return only duplicated IDs

-- EXPECTED:
-- Zero rows returned, meaning no duplicate product IDs exist.



-- ============================================================
-- STEP 7: NEGATIVE VALUE CHECK
-- Table: olist_products
-- Purpose: Identify potentially invalid product measurements.
-- ============================================================

-- WHY:
-- Product weights and physical dimensions should not be negative.
-- Negative values could indicate import or data-entry problems.
-- We check first and investigate any findings before changing data.

SELECT
    SUM(product_name_lenght < 0) AS negative_name_lengths,
    SUM(product_description_lenght < 0) AS negative_description_lengths,
    SUM(product_photos_qty < 0) AS negative_photo_quantities,
    SUM(product_weight_g < 0) AS negative_weights,
    SUM(product_length_cm < 0) AS negative_lengths,
    SUM(product_height_cm < 0) AS negative_heights,
    SUM(product_width_cm < 0) AS negative_widths
FROM olist_products;



-- ============================================================
-- STEP 8: ZERO-VALUE AND DESCRIPTIVE FIELD CHECKS
-- Table: olist_products
-- Purpose: Identify potentially suspicious values for review.
-- ============================================================

-- WHY:
-- Zero values are not always errors. We already confirmed that
-- four products have genuine zero weights in the source data.
-- This query checks other fields without modifying any records.

SELECT
    SUM(product_name_lenght = 0) AS zero_name_lengths,
    SUM(product_description_lenght = 0) AS zero_description_lengths,
    SUM(product_photos_qty = 0) AS zero_photo_quantities,
    SUM(product_weight_g = 0) AS zero_weights,
    SUM(product_length_cm = 0) AS zero_lengths,
    SUM(product_height_cm = 0) AS zero_heights,
    SUM(product_width_cm = 0) AS zero_widths
FROM olist_products;


-- ============================================================
-- OLIST PRODUCTS: DATA QUALITY SUMMARY
-- ============================================================

-- VALIDATION RESULTS:
-- 1. Total records: 32,951
-- 2. Distinct product IDs: 32,951
-- 3. Missing product IDs: 0
-- 4. Duplicate product IDs: None found
-- 5. Missing descriptive values: Preserved as NULL
-- 6. Missing weights and dimensions: Preserved as NULL
-- 7. Negative values: None found
-- 8. Zero weights: 4, verified against the source CSV
-- 9. Zero dimensions: None found
--
-- DECISION:
-- No automatic deletion or replacement of missing values.
-- Genuine zero weights are preserved.
-- Original staging and backup tables are retained.
--
-- STATUS:
-- Initial row-count, uniqueness, missing-value, and range checks
-- passed. Continue with schema and business-level validation
-- before declaring the dataset fully production-ready.



-- ============================================================
-- STEP 10: PRODUCTION TABLE SCHEMA INSPECTION
-- Table: olist_products
-- Purpose: Review column names, data types, and NULL allowance.
-- ============================================================

-- WHY:
-- Before using a table for analytics, we need to understand
-- its structure and confirm the column definitions.
-- This also helps us identify source spelling errors such as
-- 'product_name_lenght' instead of 'product_name_length'.
--
-- This query only inspects metadata. It does not modify data.

DESCRIBE olist_products;



-- ============================================================
-- STEP 11: CORRECT COLUMN NAME SPELLING
-- Table: olist_products
-- Purpose: Improve consistency and readability for analytics.
-- ============================================================

-- WHY:
-- The original dataset spells "length" incorrectly as "lenght".
-- We correct the names in the production table while keeping
-- the staging table unchanged for source traceability.
--
-- MySQL 8 supports RENAME COLUMN for this operation.

-- Rename the product name length column
ALTER TABLE olist_products
RENAME COLUMN product_name_lenght TO product_name_length;

-- Rename the product description length column
ALTER TABLE olist_products
RENAME COLUMN product_description_lenght TO product_description_length;

-- Rename the product_name_length column
ALTER TABLE olist_products
RENAME COLUMN product_name_lenght TO product_name_length;




-- STEP 12: Confirm that the corrected column names exist.
-- WHY: Verifies the schema changes were applied successfully.

DESCRIBE olist_products;


-- ============================================================
-- STEP 13: POST-SCHEMA-CHANGE VALIDATION
-- Table: olist_products
-- Purpose: Confirm data integrity after renaming columns.
-- ============================================================

-- WHY:
-- Renaming columns should not change the records or their values.
-- We recheck row counts, unique IDs, and missing descriptive data.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids,
    SUM(product_id IS NULL) AS null_product_ids,
    SUM(product_name_length IS NULL) AS null_name_lengths,
    SUM(product_description_length IS NULL) AS null_description_lengths,
    SUM(product_photos_qty IS NULL) AS null_photo_quantities,
    SUM(product_weight_g IS NULL) AS null_weights
FROM olist_products;



-- ============================================================
-- STEP 14: FINAL PRODUCTION SCHEMA CHECK
-- Table: olist_products
-- Purpose: Verify the corrected column names and data types.
-- ============================================================

-- WHY:
-- This confirms the production table uses the corrected names
-- and retains the expected data types after our changes.

DESCRIBE olist_products;





-- =====================================================
-- Phase 1 | Data Quality Check — Sellers
-- Purpose: Verify imported row count, inspect column
--          definitions, and review sample records
-- Source: olist_sellers_dataset
-- Expected result: Successful import with expected
--                  columns and records matching the source
-- Table: 7
-- =====================================================

USE olist_analytics;

-- 1. Verify imported row count
SELECT COUNT(*) AS total_rows
FROM olist_sellers_dataset;

-- 2. Inspect column definitions
DESCRIBE olist_sellers_dataset;

-- 3. Inspect sample records
SELECT *
FROM olist_sellers_dataset
LIMIT 10;



-- =====================================================
-- Phase 1 | Data Quality Check — Sellers
-- Purpose: Check missing values, duplicate seller IDs,
--          duplicate records, and location-field quality
-- Source: olist_sellers_dataset
-- Expected result: Identify any data-quality issues
-- Table: 7
-- =====================================================

USE olist_analytics;

-- 4. Check missing or blank values in each column
SELECT
    SUM(seller_id IS NULL OR TRIM(seller_id) = '') AS missing_seller_id,
    SUM(seller_zip_code_prefix IS NULL OR TRIM(seller_zip_code_prefix) = '') AS missing_zip_prefix,
    SUM(seller_city IS NULL OR TRIM(seller_city) = '') AS missing_city,
    SUM(seller_state IS NULL OR TRIM(seller_state) = '') AS missing_state
FROM olist_sellers_dataset;

-- 5. Check whether seller IDs are unique
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids,
    SUM(seller_id IS NULL OR TRIM(seller_id) = '') AS missing_seller_ids
FROM olist_sellers_dataset;

-- 6. Identify duplicated seller IDs
SELECT
    seller_id,
    COUNT(*) AS occurrences
FROM olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 7. Check for exact duplicate records
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    COUNT(*) AS occurrences
FROM olist_sellers_dataset
GROUP BY
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 8. Inspect distinct state codes
SELECT
    seller_state,
    COUNT(*) AS seller_count
FROM olist_sellers_dataset
GROUP BY seller_state
ORDER BY seller_count DESC;


-- =====================================================
-- Phase 1 | Data Quality Check — Sellers
-- Purpose: Inspect postal-code lengths and whitespace
--          before defining production data types
-- Source: olist_sellers_dataset
-- Expected result: Identify values requiring cleanup
-- Table: 7
-- =====================================================

-- 9. Inspect postal-code prefix lengths
SELECT
    CHAR_LENGTH(TRIM(seller_zip_code_prefix)) AS zip_length,
    COUNT(*) AS record_count
FROM olist_sellers_dataset
WHERE seller_zip_code_prefix IS NOT NULL
  AND TRIM(seller_zip_code_prefix) <> ''
GROUP BY CHAR_LENGTH(TRIM(seller_zip_code_prefix))
ORDER BY zip_length;

-- =====================================================
-- 10. Check for leading or trailing whitespace
-- =====================================================

-- WHY:
-- Leading or trailing whitespace can cause inconsistent
-- identifiers, incorrect comparisons, and join problems.
-- This query is read-only and does not modify records.

SELECT
    COALESCE(SUM(seller_id <> TRIM(seller_id)), 0)
        AS seller_id_whitespace,

    COALESCE(
        SUM(seller_zip_code_prefix <> TRIM(seller_zip_code_prefix)),
        0
    ) AS zip_whitespace,

    COALESCE(SUM(seller_city <> TRIM(seller_city)), 0)
        AS city_whitespace,

    COALESCE(SUM(seller_state <> TRIM(seller_state)), 0)
        AS state_whitespace

FROM olist_sellers_dataset
WHERE seller_id IS NOT NULL
   OR seller_zip_code_prefix IS NOT NULL
   OR seller_city IS NOT NULL
   OR seller_state IS NOT NULL;

-- =====================================================
-- RESULTS:
-- Check 9: Record the actual postal-code length counts.
-- Check 10: Record the actual whitespace counts for
--           seller_id, postal-code prefix, city, and state.
--
-- No records are modified or deleted by these checks.
-- =====================================================




-- =====================================================
-- RESULTS: Seller Data Quality Checks 9–10
-- =====================================================

-- Check 9: Postal-Code Prefix Lengths
-- Result:
-- 5-character postal-code prefixes: 3,095 records.
-- PASS: All 3,095 nonblank postal-code prefixes have
--       the expected length of 5 characters.

-- Check 10: Leading or Trailing Whitespace
-- Result:
-- seller_id whitespace: 0
-- postal-code whitespace: 0
-- seller_city whitespace: 0
-- seller_state whitespace: 0
-- PASS: No leading or trailing whitespace detected
--       in the four seller columns.

-- CONCLUSION:
-- All 3,095 seller records have five-character
-- postal-code prefixes, and no whitespace issues
-- were detected by these checks.
-- No records were modified or deleted.
-- =====================================================




-- =====================================================
-- Phase 1 | Data Quality Check — Sellers
-- Check 11: Missing and Blank Values
-- Purpose: Identify NULL and blank values in all columns
-- Source: olist_sellers_dataset
-- Table: 7
-- =====================================================

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN seller_id IS NULL THEN 1 ELSE 0
    END) AS null_seller_id,
    SUM(CASE
        WHEN seller_id IS NOT NULL
         AND TRIM(seller_id) = '' THEN 1 ELSE 0
    END) AS blank_seller_id,

    SUM(CASE
        WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0
    END) AS null_zip,
    SUM(CASE
        WHEN seller_zip_code_prefix IS NOT NULL
         AND TRIM(seller_zip_code_prefix) = '' THEN 1 ELSE 0
    END) AS blank_zip,

    SUM(CASE
        WHEN seller_city IS NULL THEN 1 ELSE 0
    END) AS null_city,
    SUM(CASE
        WHEN seller_city IS NOT NULL
         AND TRIM(seller_city) = '' THEN 1 ELSE 0
    END) AS blank_city,

    SUM(CASE
        WHEN seller_state IS NULL THEN 1 ELSE 0
    END) AS null_state,
    SUM(CASE
        WHEN seller_state IS NOT NULL
         AND TRIM(seller_state) = '' THEN 1 ELSE 0
    END) AS blank_state

FROM olist_sellers_dataset;


SHOW KEYS
FROM olist_sellers_dataset
WHERE Key_name = 'PRIMARY';



-- =====================================================
-- Phase 1 | Table 8 — Product Category Name Translation
-- Step 1: Verify Imported Table
-- Source Table: product_category_name_translation
-- =====================================================

-- 1. Check total row count
SELECT COUNT(*) AS total_rows
FROM product_category_name_translation;

-- 2. Inspect column definitions
DESCRIBE product_category_name_translation;

-- 3. Preview sample records
SELECT *
FROM product_category_name_translation
LIMIT 10;


-- Check 4: Check NULL and blank values in both category columns

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN product_category_name IS NULL THEN 1
        ELSE 0
    END) AS null_portuguese_category,

    SUM(CASE
        WHEN product_category_name IS NOT NULL
         AND TRIM(product_category_name) = ''
        THEN 1
        ELSE 0
    END) AS blank_portuguese_category,

    SUM(CASE
        WHEN product_category_name_english IS NULL THEN 1
        ELSE 0
    END) AS null_english_category,

    SUM(CASE
        WHEN product_category_name_english IS NOT NULL
         AND TRIM(product_category_name_english) = ''
        THEN 1
        ELSE 0
    END) AS blank_english_category

FROM product_category_name_translation;


-- Check 5: Find duplicate Portuguese category names

SELECT
    product_category_name,
    COUNT(*) AS duplicate_count
FROM product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- Check 6: Find duplicate English category names

SELECT
    product_category_name_english,
    COUNT(*) AS duplicate_count
FROM product_category_name_translation
GROUP BY product_category_name_english
HAVING COUNT(*) > 1;



-- =====================================================
-- SECTION 9: OLIST GEOLOCATION DATASET
-- =====================================================

-- Check 1: Identify NULL and blank values in geolocation columns

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN geolocation_zip_code_prefix IS NULL THEN 1
        ELSE 0
    END) AS null_zip_code,

    SUM(CASE
        WHEN geolocation_lat IS NULL THEN 1
        ELSE 0
    END) AS null_latitude,

    SUM(CASE
        WHEN geolocation_lng IS NULL THEN 1
        ELSE 0
    END) AS null_longitude,

    SUM(CASE
        WHEN geolocation_city IS NULL
          OR TRIM(geolocation_city) = ''
        THEN 1 ELSE 0
    END) AS missing_city,

    SUM(CASE
        WHEN geolocation_state IS NULL
          OR TRIM(geolocation_state) = ''
        THEN 1 ELSE 0
    END) AS missing_state

FROM olist_geolocation_dataset;


-- Result: 1,000,163 rows checked.
-- No NULL postal-code prefixes, latitude, or longitude values found.
-- No NULL or blank city or state values found.
-- Status: No missing values detected in the five columns.

-- Check 2: Identify invalid latitude and longitude values
-- Valid latitude range: -90 to 90
-- Valid longitude range: -180 to 180

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN CAST(geolocation_lat AS DECIMAL(12,8)) < -90
          OR CAST(geolocation_lat AS DECIMAL(12,8)) > 90
        THEN 1 ELSE 0
    END) AS invalid_latitude,

    SUM(CASE
        WHEN CAST(geolocation_lng AS DECIMAL(12,8)) < -180
          OR CAST(geolocation_lng AS DECIMAL(12,8)) > 180
        THEN 1 ELSE 0
    END) AS invalid_longitude

FROM olist_geolocation_dataset;

-- Result: 0 invalid latitude values and 0 invalid longitude values.
-- All coordinates fall within the valid global ranges:
-- Latitude: -90 to 90
-- Longitude: -180 to 180
-- Status: Coordinate range validation passed.

-- Check 3: Identify duplicate complete geolocation records

SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    COUNT(*) AS duplicate_count
FROM olist_geolocation_dataset
GROUP BY
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Result: 131,544 duplicate groups identified.
-- Each returned group contains multiple records with identical values
-- across all five geolocation columns.
-- Note: The number of duplicate groups is not the same as the
-- total number of excess duplicate records.
-- Status: Exact duplicate records require further assessment.

-- Check 4: Quantify exact duplicate geolocation records

SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT CONCAT_WS(
        '|',
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )) AS distinct_records,

    COUNT(*) - COUNT(DISTINCT CONCAT_WS(
        '|',
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )) AS excess_duplicate_records

FROM olist_geolocation_dataset;

-- Result:
-- Total rows: 1,000,163
-- Distinct complete records: 720,496
-- Preliminary excess duplicate records: 279,667
--
-- Interpretation:
-- The imported dataset contains repeated complete geolocation records.
-- This count was calculated using CONCAT_WS and should be verified
-- with a grouped calculation before final documentation.
-- No records have been deleted or modified.


-- Check 5: Verify excess duplicate records using grouped counts

SELECT
    SUM(duplicate_count) AS rows_in_duplicate_groups,
    COUNT(*) AS duplicate_groups,
    SUM(duplicate_count - 1) AS excess_duplicate_records
FROM (
    SELECT
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state,
        COUNT(*) AS duplicate_count
    FROM olist_geolocation_dataset
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    HAVING COUNT(*) > 1
) AS duplicate_groups;

-- Result:
-- Rows belonging to duplicate groups: 411,211
-- Duplicate groups: 131,544
-- Excess duplicate records: 279,667
--
-- Interpretation:
-- Grouped validation confirmed 279,667 excess records
-- across 131,544 groups of identical five-column records.
-- The original imported data remains unchanged.
-- Status: Duplicate count verified.


-- Check 6: Validate postal-code prefix length

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN geolocation_zip_code_prefix IS NULL
          OR TRIM(geolocation_zip_code_prefix) = ''
        THEN 1 ELSE 0
    END) AS missing_zip_prefix,

    SUM(CASE
        WHEN CHAR_LENGTH(TRIM(geolocation_zip_code_prefix)) <> 5
        THEN 1 ELSE 0
    END) AS invalid_zip_prefix_length

FROM olist_geolocation_dataset;

-- Result:
-- Missing postal-code prefixes: 0
-- Invalid postal-code prefix lengths: 0
--
-- Interpretation:
-- No missing postal-code prefixes or prefixes with a length
-- other than five characters were detected.
-- Postal-code prefixes are retained as text to preserve leading zeros.
-- Status: Postal-code prefix validation passed.

-- Check 7: Identify nonnumeric latitude and longitude values

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN TRIM(geolocation_lat) NOT REGEXP
             '^-?[0-9]+(\\.[0-9]+)?$'
        THEN 1 ELSE 0
    END) AS invalid_latitude_format,

    SUM(CASE
        WHEN TRIM(geolocation_lng) NOT REGEXP
             '^-?[0-9]+(\\.[0-9]+)?$'
        THEN 1 ELSE 0
    END) AS invalid_longitude_format

FROM olist_geolocation_dataset;

-- Result:
-- Invalid latitude formats: 0
-- Invalid longitude formats: 0
--
-- Interpretation:
-- No coordinate values failed the numeric-format validation.
-- The latitude and longitude columns currently remain TEXT.
-- Status: Coordinate format validation passed.

-- Check 8: Validate geolocation state-code format

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN geolocation_state IS NULL
          OR TRIM(geolocation_state) = ''
        THEN 1 ELSE 0
    END) AS missing_state,

    SUM(CASE
        WHEN CHAR_LENGTH(TRIM(geolocation_state)) <> 2
        THEN 1 ELSE 0
    END) AS invalid_state_length

FROM olist_geolocation_dataset;

-- Result:
-- Missing state values: 0
-- Invalid state-code lengths: 0
--
-- Interpretation:
-- No missing state values or state codes with a length other
-- than two characters were detected.
-- Status: State-code length validation passed.

-- Check 9: Identify state codes with whitespace or inconsistent casing

SELECT
    geolocation_state,
    COUNT(*) AS affected_rows
FROM olist_geolocation_dataset
WHERE geolocation_state <> TRIM(geolocation_state)
   OR BINARY geolocation_state <> BINARY UPPER(geolocation_state)
GROUP BY geolocation_state
ORDER BY affected_rows DESC;

-- Result: No rows returned.
--
-- Interpretation:
-- No state codes with leading/trailing whitespace or lowercase
-- letters were detected.
-- Status: State-code whitespace and casing validation passed.

-- Check 10: Identify city names with leading/trailing whitespace

SELECT
    geolocation_city,
    COUNT(*) AS affected_rows
FROM olist_geolocation_dataset
WHERE geolocation_city <> TRIM(geolocation_city)
GROUP BY geolocation_city
ORDER BY affected_rows DESC;

-- Result: 1 city value with leading/trailing whitespace detected.
-- Affected city value: 'salvador ' (trailing space)
-- Affected rows: 1
--
-- Interpretation:
-- One city value contains trailing whitespace.
-- This may cause inconsistent grouping or filtering by city name.
-- No data has been modified.
-- Status: One city whitespace issue identified for cleaning.

-- Check 11: Identify city names with inconsistent casing

SELECT
    geolocation_city,
    COUNT(*) AS affected_rows
FROM olist_geolocation_dataset
WHERE BINARY geolocation_city <> BINARY LOWER(geolocation_city)
GROUP BY geolocation_city
ORDER BY affected_rows DESC;

-- Result: No rows returned.
--
-- Interpretation:
-- No city names containing uppercase letters were detected.
-- City names are consistently lowercase.
-- Note: Check 10 identified one city value with trailing whitespace.
-- Status: City casing validation passed.

-- Check 12: Count distinct geolocation postal-code prefixes

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes
FROM olist_geolocation_dataset;

-- Result:
-- Total geolocation records: 1,000,163
-- Distinct postal-code prefixes: 19,015
--
-- Interpretation:
-- Multiple geolocation records may share the same postal-code prefix.
-- Repeated prefixes are expected and are not treated as exact duplicates.
-- Exact duplicate records were assessed separately in Checks 3–5.
-- Status: Distinct postal-code prefixes counted successfully.

-- Check 13: Summarize geolocation records by state

SELECT
    geolocation_state,
    COUNT(*) AS geolocation_records,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes
FROM olist_geolocation_dataset
GROUP BY geolocation_state
ORDER BY geolocation_records DESC,
         geolocation_state;
         
         -- Result:
-- 26 state codes returned.
-- State with the most geolocation records: SP
-- SP geolocation records: 404,268
-- SP share of total records: approximately 40.42%
--
-- Interpretation:
-- Geolocation records are not evenly distributed across state codes.
-- SP accounts for the largest share of records in the result.
-- The state-level record totals should be reconciled against the
-- overall table row count before final documentation.
-- Status: State distribution summarized; total reconciliation pending.

-- Check 14A: Total geolocation records

SELECT COUNT(*) AS total_rows
FROM olist_geolocation_dataset;

-- Check 14B: Sum of state-level record counts

SELECT SUM(state_records) AS state_total_rows
FROM (
    SELECT
        geolocation_state,
        COUNT(*) AS state_records
    FROM olist_geolocation_dataset
    GROUP BY geolocation_state
) AS state_summary;

-- Result:
-- Total geolocation records match the sum of state-level record counts.
-- State-level aggregation reconciles with the full table row count.
-- Status: State distribution reconciliation passed.

-- Check 15: Inspect the city value with trailing whitespace

SELECT
    CONCAT('[', geolocation_city, ']') AS visible_city_value,
    CHAR_LENGTH(geolocation_city) AS city_length,
    COUNT(*) AS affected_rows
FROM olist_geolocation_dataset
WHERE geolocation_city <> TRIM(geolocation_city)
GROUP BY geolocation_city;

-- Result:
-- City value: 'salvador ' (one trailing space)
-- Stored character length: 9
-- Affected records: 1
--
-- Interpretation:
-- One record contains a trailing space in geolocation_city.
-- The raw imported table remains unchanged.
-- Recommended cleaning action: apply TRIM to city values
-- in a cleaned table or transformation layer.
-- Status: Whitespace issue confirmed.

