-- PHASE 1: HISTORICAL IMPORT AND CLEANUP
-- Purpose: Preserve the SQL used to create, import, and clean the Order Reviews staging table.
-- WARNING: Historical record only. Do not execute this entire file from top to bottom.
-- The staging table currently contains validated data; avoid re-importing or repeating cleanup.

-- =====================================================
-- SECTION 1: ORDERS TABLE STRUCTURE AND CLEANUP
-- Table: olist_orders_dataset
-- Source: Olist orders dataset
-- Purpose: Preserve the historical column conversions
--          and blank-to-NULL cleanup operations.
-- =====================================================
ALTER TABLE olist_orders_dataset
    MODIFY COLUMN order_id VARCHAR(100),
    MODIFY COLUMN customer_id VARCHAR(100),
    MODIFY COLUMN order_status VARCHAR(100),
    MODIFY COLUMN order_purchase_timestamp DATETIME,
    MODIFY COLUMN order_approved_at DATETIME NULL,
    MODIFY COLUMN order_delivered_carrier_date DATETIME NULL,
    MODIFY COLUMN order_delivered_customer_date DATETIME NULL,
    MODIFY COLUMN order_estimated_delivery_date DATETIME;
    
    
-- Purpose: Convert empty optional order timestamps to NULL.
-- Reason: Empty strings are not valid DATETIME values.
-- Note: Historical cleanup already performed; do not rerun.

SET SQL_SAFE_UPDATES = 0;

UPDATE olist_orders_dataset
SET order_approved_at = NULL
WHERE order_approved_at = '';

UPDATE olist_orders_dataset
SET order_delivered_carrier_date = NULL
WHERE order_delivered_carrier_date = '';

UPDATE olist_orders_dataset
SET order_delivered_customer_date = NULL
WHERE order_delivered_customer_date = '';

SET SQL_SAFE_UPDATES = 1;



-- =====================================================
-- SECTION 2: ORDER ITEMS TABLE STRUCTURE
-- Table: olist_order_items_dataset
-- Source: Olist order items dataset
-- Purpose: Record the column type conversions.
-- Note: Historical record only; do not execute again.
-- =====================================================

ALTER TABLE olist_order_items_dataset
    MODIFY COLUMN order_id VARCHAR(100),
    MODIFY COLUMN order_item_id VARCHAR(100),
    MODIFY COLUMN product_id VARCHAR(100),
    MODIFY COLUMN seller_id VARCHAR(100),
    MODIFY COLUMN shipping_limit_date DATETIME,
    MODIFY COLUMN price DOUBLE,
    MODIFY COLUMN freight_value DOUBLE;
    
    
-- =====================================================
-- SECTION 3: CUSTOMERS TABLE CREATION
-- Table: olist_customers
-- Source: Olist customers dataset
-- Purpose: Record the original table structure.
-- Note: Historical record only; do not execute again.
-- =====================================================

CREATE TABLE olist_customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state CHAR(2)
);



-- =====================================================

-- Historical experiment 1: Order Reviews import troubleshooting
-- Temporary table: olist_order_reviews_import
-- Status: Table dropped after troubleshooting.
-- Purpose: An initial attempt to import the Reviews CSV.
-- Note: Historical record only. Do not execute the original
-- CREATE TABLE, SET GLOBAL, or LOAD DATA statements again.


-- Historical experiment 2: Order Reviews CSV parsing
-- Temporary table: olist_order_reviews_test2
-- Purpose: Test an alternative CSV import configuration
-- using ESCAPED BY ''.
-- Status: Historical troubleshooting record.
-- Note: Do not recreate the table or rerun LOAD DATA.


-- =====================================================
-- SECTION 4: ORDER REVIEWS CSV IMPORT AND CONFIGURATION
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Document the CSV import process and the
--          MySQL settings used during troubleshooting.
-- Status: Import completed; 99,224 rows validated.
-- WARNING: HISTORICAL RECORD ONLY. DO NOT RERUN.
-- =====================================================


-- -----------------------------------------------------
-- 4.1: LOCAL INFILE SERVER CONFIGURATION CHECK
-- Purpose: Check whether local CSV loading is enabled.
-- -----------------------------------------------------

-- Historical query:
SHOW GLOBAL VARIABLES LIKE 'local_infile';


-- -----------------------------------------------------
-- 4.2: ENABLE LOCAL CSV IMPORT
-- Purpose: Enable LOCAL INFILE on the MySQL server
--          for the troubleshooting session.
-- -----------------------------------------------------

-- Historical statement:
SET GLOBAL local_infile = 1;


-- -----------------------------------------------------
-- 4.3: CLIENT SESSION CONFIGURATION CHECK
-- Purpose: Verify the session's local-infile setting.
-- -----------------------------------------------------

-- Historical query:
SHOW SESSION VARIABLES LIKE 'local_infile';


-- -----------------------------------------------------
-- 4.4: CSV IMPORT
-- Source: olist_order_reviews_dataset.csv
-- Target: olist_order_reviews_stage
-- Purpose: Import source records while preserving
--          raw date/time values for validation.
-- -----------------------------------------------------

-- Historical import statement; already completed.
-- Do not execute again, because it may add duplicate rows.

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


-- -----------------------------------------------------
-- 4.5: IMPORT WARNING VALIDATION
-- Purpose: Inspect warnings immediately after import.
-- -----------------------------------------------------

-- Historical query:
SHOW WARNINGS;


-- -----------------------------------------------------
-- 4.6: IMPORT OUTCOME
-- Total rows imported: 99,224
-- Trailing carriage returns remaining after cleanup: 0
-- -----------------------------------------------------


-- =====================================================
-- SECTION 5: ORDER REVIEWS DATA CLEANUP
-- Table: olist_order_reviews_stage
-- Purpose: Document removal of trailing carriage
--          returns from review_answer_timestamp.
-- Status: Cleanup completed; 0 trailing CRs remain.
-- WARNING: Historical record only. Do not rerun.
-- =====================================================

-- Historical cleanup operation:
UPDATE olist_order_reviews_stage
SET review_answer_timestamp = TRIM(TRAILING '\r'
   FROM review_answer_timestamp);
--
-- The cleanup has already been performed.
-- Do not execute this historical statement again.





-- =====================================================
-- PHASE 1: HISTORICAL IMPORT AND CLEANUP
-- SECTION 6: PRODUCTS TABLE IMPORT AND CLEANUP
--
-- Source: olist_products_dataset.csv
-- Staging: olist_products_stage
-- Test: olist_products_stage_test
-- Backup: olist_products_stage_backup
-- Rebuild: olist_products_stage_rebuild
-- Previous staging: olist_products_stage_old
-- Production: olist_products
--
-- IMPORTANT:
-- This section records the historical workflow.
-- DO NOT execute the entire section from top to bottom.
-- Existing tables and data have already been created,
-- imported, tested, and validated.
-- =====================================================

USE olist_analytics;


-- =====================================================
-- 6.1 CREATE THE ORIGINAL PRODUCTS STAGING TABLE
-- Purpose: Match the original CSV column structure.
-- Historical statement: Already executed.
-- =====================================================

-- CREATE TABLE olist_products_stage (
--     product_id VARCHAR(50),
--     product_category_name VARCHAR(100),
--     product_name_lenght INT,
--     product_description_lenght INT,
--     product_photos_qty INT,
--     product_weight_g INT,
--     product_length_cm INT,
--     product_height_cm INT,
--     product_width_cm INT
-- );


-- =====================================================
-- 6.2 INITIAL PRODUCTS CSV IMPORT
-- Purpose: Import source CSV rows into the staging table.
-- Historical statement: Already executed.
--
-- Initial troubleshooting included Error 13
-- (file not found or permission denied).
-- A later import populated the staging table.
--
-- The path below is preserved from the original SQL.
-- Do not rerun this import into an existing populated table.
-- =====================================================

-- LOAD DATA LOCAL INFILE
-- 'C:/Users/riodo/OneDrive/Desktop/Olist_Flagship_Project/Raw Data/olist_products_dataset.csv/olist_products_dataset.csv'
-- INTO TABLE olist_products_stage
-- CHARACTER SET utf8mb4
-- FIELDS TERMINATED BY ','
-- OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (
--     product_id,
--     product_category_name,
--     product_name_lenght,
--     product_description_lenght,
--     product_photos_qty,
--     product_weight_g,
--     product_length_cm,
--     product_height_cm,
--     product_width_cm
-- );


-- =====================================================
-- 6.3 INITIAL IMPORT VALIDATION
-- Purpose: Check row count, product ID uniqueness,
--          missing IDs, zero values, and NULL values.
-- Historical queries: Preserved for reference.
-- =====================================================

-- SELECT
--     COUNT(*) AS total_rows,
--     COUNT(DISTINCT product_id) AS distinct_product_ids,
--     SUM(product_id IS NULL OR TRIM(product_id) = '')
--         AS missing_product_ids
-- FROM olist_products_stage;

-- SELECT
--     SUM(product_name_lenght = 0) AS name_length_zeros,
--     SUM(product_description_lenght = 0)
--         AS description_length_zeros,
--     SUM(product_photos_qty = 0) AS photos_qty_zeros,
--     SUM(product_weight_g = 0) AS weight_zeros,
--     SUM(product_length_cm = 0) AS length_zeros,
--     SUM(product_height_cm = 0) AS height_zeros,
--     SUM(product_width_cm = 0) AS width_zeros,
--     SUM(product_name_lenght IS NULL) AS name_length_nulls,
--     SUM(product_description_lenght IS NULL)
--         AS description_length_nulls,
--     SUM(product_photos_qty IS NULL) AS photos_qty_nulls,
--     SUM(product_weight_g IS NULL) AS weight_nulls,
--     SUM(product_length_cm IS NULL) AS length_nulls,
--     SUM(product_height_cm IS NULL) AS height_nulls,
--     SUM(product_width_cm IS NULL) AS width_nulls
-- FROM olist_products_stage;


-- =====================================================
-- 6.4 INVESTIGATE ZERO VALUES AND MISSING DESCRIPTIVE DATA
-- Purpose: Determine whether zero values and missing
--          descriptive attributes occur together.
-- =====================================================

-- SELECT
--     product_id,
--     product_category_name,
--     product_name_lenght,
--     product_description_lenght,
--     product_photos_qty,
--     product_weight_g,
--     product_length_cm,
--     product_height_cm,
--     product_width_cm
-- FROM olist_products_stage
-- WHERE product_name_lenght = 0
--    OR product_description_lenght = 0
--    OR product_photos_qty = 0
--    OR product_weight_g = 0
--    OR product_length_cm = 0
--    OR product_height_cm = 0
--    OR product_width_cm = 0
-- LIMIT 20;

-- SELECT
--     COUNT(*) AS products_with_all_three_zeros,
--     SUM(
--         product_category_name IS NULL
--         OR TRIM(product_category_name) = ''
--     ) AS products_with_missing_category
-- FROM olist_products_stage
-- WHERE product_name_lenght = 0
--   AND product_description_lenght = 0
--   AND product_photos_qty = 0;

-- SELECT COUNT(*) AS affected_products
-- FROM olist_products_stage
-- WHERE (product_category_name IS NULL
--        OR TRIM(product_category_name) = '')
--   AND product_name_lenght = 0
--   AND product_description_lenght = 0
--   AND product_photos_qty = 0;


-- =====================================================
-- 6.5 INSPECT SQL MODE, STRUCTURE, AND STORAGE ENGINE
-- Purpose: Investigate import behavior and table properties.
-- Historical diagnostic queries.
-- =====================================================

-- SELECT @@SESSION.sql_mode;

-- DESCRIBE olist_products_stage;

-- SELECT
--     TABLE_NAME,
--     ENGINE
-- FROM information_schema.TABLES
-- WHERE TABLE_SCHEMA = 'olist_analytics'
--   AND TABLE_NAME = 'olist_products_stage';


-- =====================================================
-- 6.6 CREATE A BACKUP OF THE ORIGINAL STAGING TABLE
-- Purpose: Preserve the initial imported data before
--          testing a corrected import.
-- Historical statements: Already executed.
-- =====================================================

-- CREATE TABLE olist_products_stage_backup AS
-- SELECT *
-- FROM olist_products_stage;

-- SELECT
--     COUNT(*) AS backup_rows,
--     COUNT(DISTINCT product_id) AS distinct_product_ids
-- FROM olist_products_stage_backup;

-- SELECT
--     'Original staging table' AS table_name,
--     COUNT(*) AS total_rows,
--     COUNT(DISTINCT product_id) AS distinct_product_ids
-- FROM olist_products_stage
-- UNION ALL
-- SELECT
--     'Staging backup',
--     COUNT(*),
--     COUNT(DISTINCT product_id)
-- FROM olist_products_stage_backup;

-- SHOW TABLES LIKE 'olist_products_stage_backup';


-- =====================================================
-- 6.7 CREATE A TEST TABLE
-- Purpose: Test corrected CSV import behavior without
--          changing the original staging table.
-- Historical statement: Already executed.
-- =====================================================

-- CREATE TABLE olist_products_stage_test
-- LIKE olist_products_stage;


-- =====================================================
-- 6.8 CORRECTED CSV IMPORT USING NULLIF()
-- Purpose: Convert empty CSV fields into SQL NULL values.
--
-- @variables temporarily receive CSV text.
-- NULLIF(value, '') converts an empty string to NULL.
-- The destination columns then receive the converted values.
--
-- Historical statement: Already executed.
-- Do not reload the existing test table.
-- =====================================================

-- LOAD DATA LOCAL INFILE
-- 'C:/Users/riodo/OneDrive/Desktop/Olist_Flagship_Project/Raw Data/olist_products_dataset.csv/olist_products_dataset.csv'
-- INTO TABLE olist_products_stage_test
-- CHARACTER SET utf8mb4
-- FIELDS TERMINATED BY ','
-- OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (
--     @product_id,
--     @product_category_name,
--     @product_name_lenght,
--     @product_description_lenght,
--     @product_photos_qty,
--     @product_weight_g,
--     @product_length_cm,
--     @product_height_cm,
--     @product_width_cm
-- )
-- SET
--     product_id = NULLIF(@product_id, ''),
--     product_category_name =
--         NULLIF(@product_category_name, ''),
--     product_name_lenght =
--         NULLIF(@product_name_lenght, ''),
--     product_description_lenght =
--         NULLIF(@product_description_lenght, ''),
--     product_photos_qty =
--         NULLIF(@product_photos_qty, ''),
--     product_weight_g = NULLIF(@product_weight_g, ''),
--     product_length_cm = NULLIF(@product_length_cm, ''),
--     product_height_cm = NULLIF(@product_height_cm, ''),
--     product_width_cm = NULLIF(@product_width_cm, '');


-- =====================================================
-- 6.9 VALIDATE THE CORRECTED TEST IMPORT
-- Purpose: Confirm row counts and examine missing values.
-- Historical queries: Preserved for reference.
-- =====================================================

-- SELECT
--     COUNT(*) AS total_rows,
--     COUNT(DISTINCT product_id) AS distinct_product_ids,
--     SUM(product_id IS NULL OR TRIM(product_id) = '')
--         AS missing_product_ids
-- FROM olist_products_stage_test;

-- SELECT
--     COUNT(*) AS products_with_all_three_nulls
-- FROM olist_products_stage_test
-- WHERE product_name_lenght IS NULL
--   AND product_description_lenght IS NULL
--   AND product_photos_qty IS NULL;

-- SELECT
--     SUM(product_name_lenght = 0) AS name_length_zeros,
--     SUM(product_description_lenght = 0)
--         AS description_length_zeros,
--     SUM(product_photos_qty = 0) AS photos_qty_zeros,
--     SUM(product_weight_g = 0) AS weight_zeros,
--     SUM(product_length_cm = 0) AS length_zeros,
--     SUM(product_height_cm = 0) AS height_zeros,
--     SUM(product_width_cm = 0) AS width_zeros,
--     SUM(product_name_lenght IS NULL) AS name_length_nulls,
--     SUM(product_description_lenght IS NULL)
--         AS description_length_nulls,
--     SUM(product_photos_qty IS NULL) AS photos_qty_nulls,
--     SUM(product_weight_g IS NULL) AS weight_nulls,
--     SUM(product_length_cm IS NULL) AS length_nulls,
--     SUM(product_height_cm IS NULL) AS height_nulls,
--     SUM(product_width_cm IS NULL) AS width_nulls
-- FROM olist_products_stage_test;

-- SELECT
--     product_id,
--     product_category_name,
--     product_weight_g,
--     product_length_cm,
--     product_height_cm,
--     product_width_cm
-- FROM olist_products_stage_test
-- WHERE product_weight_g = 0
--    OR product_weight_g IS NULL;

-- SELECT
--     COUNT(*) AS total_rows,
--     COUNT(DISTINCT product_id) AS distinct_product_ids,
--     SUM(product_id IS NULL OR TRIM(product_id) = '')
--         AS missing_product_ids,
--     SUM(product_weight_g IS NULL) AS missing_weights,
--     SUM(product_length_cm IS NULL) AS missing_lengths,
--     SUM(product_height_cm IS NULL) AS missing_heights,
--     SUM(product_width_cm IS NULL) AS missing_widths
-- FROM olist_products_stage_test;

-- SHOW CREATE TABLE olist_products_stage;
-- SHOW CREATE TABLE olist_products_stage_test;


-- =====================================================
-- 6.10 HISTORICAL REPLACEMENT ATTEMPTS
-- Purpose: Test replacing the original staging contents
--          with data from the corrected test import.
--
-- IMPORTANT:
-- Several DELETE/INSERT/UPDATE attempts occurred.
-- Some were followed by ROLLBACK; one replacement sequence
-- was followed by COMMIT.
-- Do not rerun these historical mutations.
-- =====================================================

-- Historical transaction pattern; DO NOT EXECUTE:
--
-- START TRANSACTION;
--
-- DELETE FROM olist_products_stage;
--
-- INSERT INTO olist_products_stage (
--     product_id,
--     product_category_name,
--     product_name_lenght,
--     product_description_lenght,
--     product_photos_qty,
--     product_weight_g,
--     product_length_cm,
--     product_height_cm,
--     product_width_cm
-- )
-- SELECT
--     product_id,
--     product_category_name,
--     product_name_lenght,
--     product_description_lenght,
--     product_photos_qty,
--     product_weight_g,
--     product_length_cm,
--     product_height_cm,
--     product_width_cm
-- FROM olist_products_stage_test;
--
-- Validate the row counts and NULL counts before deciding
-- whether a transaction should COMMIT or ROLLBACK.
--
-- The original history includes both COMMIT and ROLLBACK
-- attempts. They are intentionally not executable here.


-- =====================================================
-- 6.11 HISTORICAL TROUBLESHOOTING
-- Purpose: Investigate transactions, triggers, and
--          differences between staging and test data.
-- These are diagnostic queries preserved from the workflow.
-- =====================================================

-- SELECT
--     DATABASE() AS current_database,
--     @@session.autocommit AS autocommit_setting,
--     @@session.in_transaction AS transaction_active;

-- SELECT
--     VERSION() AS mysql_version,
--     DATABASE() AS current_database,
--     @@session.autocommit AS autocommit_setting;

-- SELECT
--     THREAD_ID,
--     EVENT_NAME,
--     STATE
-- FROM performance_schema.events_transactions_current
-- WHERE THREAD_ID = (
--     SELECT THREAD_ID
--     FROM performance_schema.threads
--     WHERE PROCESSLIST_ID = CONNECTION_ID()
-- );

-- SHOW TRIGGERS
-- WHERE `Table` = 'olist_products_stage';

-- SHOW TRIGGERS FROM olist_analytics;

-- SELECT
--     product_id,
--     product_name_lenght,
--     product_description_lenght,
--     product_photos_qty
-- FROM olist_products_stage_test
-- WHERE product_id = 'a41e356c76fab66334f36de622ecbd3a';

-- SELECT
--     'Staging' AS source_table,
--     product_id,
--     product_name_lenght,
--     product_description_lenght,
--     product_photos_qty
-- FROM olist_products_stage
-- WHERE product_id = 'a41e356c76fab66334f36de622ecbd3a'
-- UNION ALL
-- SELECT
--     'Validated test',
--     product_id,
--     product_name_lenght,
--     product_description_lenght,
--     product_photos_qty
-- FROM olist_products_stage_test
-- WHERE product_id = 'a41e356c76fab66334f36de622ecbd3a';


-- =====================================================
-- 6.12 CREATE AND VALIDATE THE REBUILD TABLE
-- Purpose: Build a separate copy from the corrected test
--          table before replacing the staging table.
-- Historical statements: Already executed.
-- =====================================================

-- CREATE TABLE olist_products_stage_rebuild
-- LIKE olist_products_stage_test;

-- INSERT INTO olist_products_stage_rebuild
-- SELECT *
-- FROM olist_products_stage_test;

-- SELECT
--     COUNT(*) AS total_rows,
--     COUNT(DISTINCT product_id) AS distinct_ids,
--     SUM(product_id IS NULL) AS missing_product_ids,
--     SUM(product_name_lenght IS NULL) AS missing_name_lengths,
--     SUM(product_description_lenght IS NULL)
--         AS missing_description_lengths,
--     SUM(product_photos_qty IS NULL)
--         AS missing_photo_quantities,
--     SUM(product_weight_g IS NULL) AS missing_weights,
--     SUM(product_length_cm IS NULL) AS missing_lengths,
--     SUM(product_height_cm IS NULL) AS missing_heights,
--     SUM(product_width_cm IS NULL) AS missing_widths
-- FROM olist_products_stage_rebuild;

-- SELECT COUNT(*) AS mismatched_rows
-- FROM olist_products_stage_rebuild r
-- JOIN olist_products_stage_test t
--     ON r.product_id = t.product_id
-- WHERE NOT (
--     r.product_category_name <=> t.product_category_name
--     AND r.product_name_lenght <=> t.product_name_lenght
--     AND r.product_description_lenght
--         <=> t.product_description_lenght
--     AND r.product_photos_qty <=> t.product_photos_qty
--     AND r.product_weight_g <=> t.product_weight_g
--     AND r.product_length_cm <=> t.product_length_cm
--     AND r.product_height_cm <=> t.product_height_cm
--     AND r.product_width_cm <=> t.product_width_cm
-- );


-- =====================================================
-- 6.13 REPLACE STAGING TABLE USING THE VALIDATED REBUILD
-- Purpose: Rename the old table for preservation and
--          promote the rebuilt table to the staging name.
--
-- Historical statement: Already executed.
-- Do not rerun: table names may now conflict.
-- =====================================================

-- SHOW TABLES LIKE 'olist_products_stage_old';

-- RENAME TABLE
--     olist_products_stage TO olist_products_stage_old,
--     olist_products_stage_rebuild TO olist_products_stage;


-- =====================================================
-- 6.14 FINAL PRODUCTS STAGING VALIDATION
-- Purpose: Check the current staging table after rebuilding.
-- Safe to run: YES. These queries are read-only.
-- =====================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids,
    SUM(product_id IS NULL OR TRIM(product_id) = '')
        AS missing_product_ids
FROM olist_products_stage;

SELECT
    SUM(product_category_name IS NULL)
        AS missing_categories,
    SUM(product_name_lenght IS NULL)
        AS missing_name_lengths,
    SUM(product_description_lenght IS NULL)
        AS missing_description_lengths,
    SUM(product_photos_qty IS NULL)
        AS missing_photo_quantities,
    SUM(product_weight_g IS NULL) AS missing_weights,
    SUM(product_length_cm IS NULL) AS missing_lengths,
    SUM(product_height_cm IS NULL) AS missing_heights,
    SUM(product_width_cm IS NULL) AS missing_widths,
    SUM(product_weight_g = 0) AS zero_weights
FROM olist_products_stage;


-- =====================================================
-- 6.15 PRODUCTION PRODUCTS TABLE VALIDATION
-- Purpose: Check production table row count and uniqueness.
-- Safe to run: YES. This query is read-only.
-- =====================================================

SELECT
    COUNT(*) AS total_product_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids,
    SUM(product_id IS NULL OR TRIM(product_id) = '')
        AS missing_product_ids
FROM olist_products;


-- =====================================================
-- 6.16 PRODUCT-TO-ORDER-ITEM RELATIONSHIP VALIDATION
-- Purpose: Check product ID coverage between the two tables.
-- Safe to run: YES. These queries are read-only.
-- =====================================================

-- Find order-item product IDs absent from the product table.
SELECT COUNT(*) AS unmatched_order_item_products
FROM olist_order_items_dataset oi
LEFT JOIN olist_products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Find products not referenced by any order item.
SELECT COUNT(*) AS products_without_order_items
FROM olist_products p
LEFT JOIN olist_order_items_dataset oi
    ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL;


-- =====================================================
-- END OF SECTION 6: PRODUCTS TABLE IMPORT AND CLEANUP
-- =====================================================



-- =====================================================
-- Phase 1 | Table 7 — Sellers
-- Section 7: Standardize Column Data Types
-- Purpose: Apply appropriate data types to olist_sellers
-- Target Table: olist_sellers
-- Source Table: olist_sellers_dataset (unchanged)
-- =====================================================

ALTER TABLE olist_sellers_dataset
    MODIFY COLUMN seller_id VARCHAR(50),
    MODIFY COLUMN seller_zip_code_prefix VARCHAR(5),
    MODIFY COLUMN seller_city VARCHAR(100),
    MODIFY COLUMN seller_state CHAR(2);

-- Verify the updated column definitions
DESCRIBE olist_sellers_dataset;

-- RESULT:
-- Data types updated successfully in olist_sellers_dataset.
-- seller_id: VARCHAR(50)
-- seller_zip_code_prefix: VARCHAR(5)
-- seller_city: VARCHAR(100)
-- seller_state: CHAR(2)
-- Verification: DESCRIBE olist_sellers_dataset confirmed
-- the updated column definitions.


-- 1. Verify total row count
SELECT COUNT(*) AS total_seller_rows
FROM olist_sellers_dataset;

-- 2. Verify seller ID uniqueness
SELECT
    COUNT(*) AS total_rows,
    COUNT(seller_id) AS non_null_seller_ids,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids
FROM olist_sellers_dataset;



-- =====================================================
-- Phase 1 | Table 7 — Sellers
-- Step: Add Primary Key
-- Purpose: Enforce unique identification of each seller
-- Table: olist_sellers_dataset
-- =====================================================

ALTER TABLE olist_sellers_dataset
    MODIFY COLUMN seller_id VARCHAR(50) NOT NULL,
    ADD PRIMARY KEY (seller_id);

-- Verify the primary key
SHOW KEYS
FROM olist_sellers_dataset
WHERE Key_name = 'PRIMARY';


-- RESULT:
-- Primary key added successfully to olist_sellers_dataset.
-- Primary key column: seller_id
-- Index type: BTREE
-- Total records: 3,095
-- Validation: No NULL, blank, or duplicate seller IDs.
-- Status: PASS
-- =====================================================



-- =====================================================
-- SECTION 8: PRODUCT CATEGORY NAME TRANSLATION
-- =====================================================

-- Step 1: Rename the imported column to remove UTF-8 BOM characters

ALTER TABLE product_category_name_translation
RENAME COLUMN `ï»¿product_category_name`
TO product_category_name;

-- Step 2: Verify the updated column names

DESCRIBE product_category_name_translation;


-- =====================================================
-- SECTION 9: OLIST GEOLOCATION DATASET
-- =====================================================
-- Purpose: Recreate the geolocation table before importing
-- the complete source CSV using LOAD DATA LOCAL INFILE.

CREATE TABLE olist_geolocation_dataset (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat             TEXT,
    geolocation_lng             TEXT,
    geolocation_city            TEXT,
    geolocation_state           TEXT
);

DESCRIBE olist_geolocation_dataset;

-- Step 3: Import the geolocation CSV using LOAD DATA LOCAL INFILE

LOAD DATA LOCAL INFILE
'C:/Users/riodo/OneDrive/Desktop/Olist_Flagship_Project/Raw Data/olist_geolocation_dataset.csv/olist_geolocation_dataset.csv'
INTO TABLE olist_geolocation_dataset
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
);


-- Section 9: Olist Geolocation Dataset
-- Check 4: Verify the final imported row count

SELECT COUNT(*) AS total_rows
FROM olist_geolocation_dataset;

-- Check 5: Verify the imported column structure

DESCRIBE olist_geolocation_dataset;

-- Check 6: Inspect sample records

SELECT *
FROM olist_geolocation_dataset
LIMIT 10;

