USE olist_analytics;

-- Phase 2, Step 1: Inspect current table structures
SHOW CREATE TABLE olist_customers;
SHOW CREATE TABLE olist_orders_dataset;
SHOW CREATE TABLE olist_order_items_dataset;
SHOW CREATE TABLE olist_order_payments_dataset;
SHOW CREATE TABLE olist_order_reviews_stage;
SHOW CREATE TABLE olist_products;
SHOW CREATE TABLE olist_sellers_dataset;
SHOW CREATE TABLE product_category_name_translation;
SHOW CREATE TABLE olist_geolocation_dataset;



USE olist_analytics;

-- Phase 2, Step 2A:
-- Check whether candidate primary-key columns are unique.

SELECT
    'olist_customers.customer_id' AS candidate_key,
    COUNT(*) AS total_rows,
    COUNT(customer_id) AS non_null_values,
    COUNT(DISTINCT customer_id) AS distinct_values
FROM olist_customers

UNION ALL

SELECT
    'olist_customers.customer_unique_id',
    COUNT(*),
    COUNT(customer_unique_id),
    COUNT(DISTINCT customer_unique_id)
FROM olist_customers

UNION ALL

SELECT
    'olist_products.product_id',
    COUNT(*),
    COUNT(product_id),
    COUNT(DISTINCT product_id)
FROM olist_products

UNION ALL

SELECT
    'olist_sellers_dataset.seller_id',
    COUNT(*),
    COUNT(seller_id),
    COUNT(DISTINCT seller_id)
FROM olist_sellers_dataset;


/*
Phase 2 — Step 2A: Candidate Primary-Key Validation

Results:
1. olist_customers.customer_id:
   99,441 rows, 99,441 non-NULL values,
   99,441 distinct values.
   Finding: Valid primary-key candidate.

2. olist_customers.customer_unique_id:
   99,441 rows, 96,096 distinct values.
   Finding: Not unique; unsuitable as the primary key
   for olist_customers.

3. olist_products.product_id:
   32,951 rows, 32,951 non-NULL values,
   32,951 distinct values.
   Finding: Valid primary-key candidate.

4. olist_sellers_dataset.seller_id:
   3,095 rows, 3,095 non-NULL values,
   3,095 distinct values.
   Finding: Valid primary-key candidate.
   A primary key already exists.

No schema changes were made during these checks.
*/


-- Phase 2, Step 2B:
-- Check whether (order_id, order_item_id) is unique.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id, order_item_id) AS distinct_key_pairs,
    SUM(
        CASE
            WHEN order_id IS NULL THEN 1
            ELSE 0
        END
    ) AS null_order_ids
FROM olist_order_items_dataset;

-- Find duplicate key pairs, if any.
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM olist_order_items_dataset
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;


/*
Phase 2 — Step 2B: Order-Item Composite Key Validation

Table: olist_order_items_dataset

Results:
- Total rows: 112,650
- Distinct (order_id, order_item_id) pairs: 112,650
- NULL order_id values: 0
- Duplicate key pairs: 0

Finding:
The combination of order_id and order_item_id
is a valid candidate composite primary key.

No schema changes were made during these checks.
*/


-- Phase 2, Step 2C:
-- Validate the candidate primary key in the orders table.

SELECT
    COUNT(*) AS total_rows,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(DISTINCT order_id) AS distinct_order_ids
FROM olist_orders_dataset;

-- Identify duplicate order IDs, if any.
SELECT
    order_id,
    COUNT(*) AS occurrences
FROM olist_orders_dataset
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;



/*
Phase 2 — Step 2C: Orders Primary-Key Validation

Table: olist_orders_dataset

Results:
- Total rows: 99,441
- Non-NULL order_id values: 99,441
- Distinct order_id values: 99,441
- Duplicate order IDs: 0

Finding:
order_id is a valid candidate primary key.

No schema changes were made during these checks.
*/



-- Payment table: inspect candidate key columns
SELECT
    COUNT(*) AS total_rows,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    COUNT(payment_sequential) AS non_null_payment_sequential,
    COUNT(DISTINCT payment_sequential) AS distinct_payment_sequential
FROM olist_order_payments_dataset;

-- Review table: inspect candidate key columns
SELECT
    COUNT(*) AS total_rows,
    COUNT(review_id) AS non_null_review_ids,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(DISTINCT order_id) AS distinct_order_ids
FROM olist_order_reviews_stage;


/*
Phase 2 — Step 2D: Payment and Review Key Inspection

A. Table: olist_order_payments_dataset

Results:
- Total rows: 103,886
- Non-NULL order_id values: 103,886
- Distinct order_id values: 99,440
- Non-NULL payment_sequential values: 103,886
- Distinct payment_sequential values: 29

Interpretation:
- No missing order IDs or payment sequence values were found.
- Multiple payment records can belong to the same order.
- payment_sequential repeats across orders.
- Neither order_id nor payment_sequential alone
  uniquely identifies a payment record.

Next step:
Test the composite key (order_id, payment_sequential)
in Step 2E.


B. Table: olist_order_reviews_stage

Results:
- Total rows: 99,224
- Non-NULL review_id values: 99,224
- Distinct review_id values: 98,410
- Non-NULL order_id values: 99,224
- Distinct order_id values: 98,673

Interpretation:
- No missing review IDs or order IDs were found.
- review_id is not unique in the imported data.
- Some orders have multiple review records.
- Neither review_id nor order_id alone uniquely
  identifies every row.

Next step:
Investigate repeated review IDs and test a composite
key in Step 2F.

No schema changes were made during these checks.
*/


-- Check uniqueness of (order_id, payment_sequential)
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id, payment_sequential) AS distinct_key_pairs
FROM olist_order_payments_dataset;

-- Find duplicate payment key pairs
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS occurrences
FROM olist_order_payments_dataset
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;


/*
Phase 2 — Step 2E: Payment Composite Key Validation

Table: olist_order_payments_dataset

Results:
- Total rows: 103,886
- Distinct (order_id, payment_sequential) pairs: 103,886
- Duplicate key pairs: 0

Finding:
The combination of order_id and payment_sequential
is a valid candidate composite primary key.

No schema changes were made during these checks.
*/


-- Find review IDs that appear more than once
SELECT
    review_id,
    COUNT(*) AS occurrences,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM olist_order_reviews_stage
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;

-- Test whether (review_id, order_id) is unique
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id, order_id) AS distinct_key_pairs
FROM olist_order_reviews_stage;

-- Find repeated review/order pairs
SELECT
    review_id,
    order_id,
    COUNT(*) AS occurrences
FROM olist_order_reviews_stage
GROUP BY review_id, order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;



/*
Phase 2 — Step 2E: Payment Composite Key Validation

Table: olist_order_payments_dataset

Results:
- Total rows: 103,886
- Distinct (order_id, payment_sequential) pairs: 103,886
- Duplicate key pairs: 0

Finding:
The combination of order_id and payment_sequential
is a valid candidate composite primary key.

No schema changes were made during these checks.
*/



-- Phase 2, Step 2G: Validate category translation keys

SELECT
    COUNT(*) AS total_rows,
    COUNT(product_category_name) AS non_null_category_names,
    COUNT(DISTINCT product_category_name) AS distinct_category_names,
    COUNT(product_category_name_english) AS non_null_english_names,
    COUNT(DISTINCT product_category_name_english) AS distinct_english_names
FROM product_category_name_translation;



/*
Phase 2 — Step 2G: Category Translation Key Validation

Table: product_category_name_translation

Results:
- Total rows: 71
- Non-NULL Portuguese category names: 71
- Distinct Portuguese category names: 71
- Non-NULL English category names: 71
- Distinct English category names: 71

Finding:
Both category-name columns are complete and unique
in the current imported data.

Recommended primary-key candidate:
product_category_name

Rationale:
The Portuguese category name is the source category
identifier used by the Olist products table.

No schema changes were made during these checks.
*/



-- Phase 2, Step 2H: Inspect geolocation key candidates

SELECT
    COUNT(*) AS total_rows,
    COUNT(geolocation_zip_code_prefix) AS non_null_zip_prefixes,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes,
    COUNT(geolocation_lat) AS non_null_latitudes,
    COUNT(geolocation_lng) AS non_null_longitudes
FROM olist_geolocation_dataset;



/*
Phase 2 — Step 2H: Geolocation Key Inspection

Table: olist_geolocation_dataset

Results:
- Total rows: 1,000,163
- Non-NULL postal prefixes: 1,000,163
- Distinct postal prefixes: 19,015
- Non-NULL latitudes: 1,000,163
- Non-NULL longitudes: 1,000,163

Finding:
geolocation_zip_code_prefix is not unique and cannot
serve as the primary key by itself.

Multiple records may share the same postal prefix.
No primary key will be assigned until a suitable
record identifier or defensible composite key is
established.

No schema changes were made during these checks.
*/



-- Phase 2, Step 2I: Validate product-category references

SELECT
    COUNT(*) AS total_products,
    SUM(
        CASE
            WHEN p.product_category_name IS NULL
              OR TRIM(p.product_category_name) = ''
            THEN 1 ELSE 0
        END
    ) AS missing_product_categories,
    SUM(
        CASE
            WHEN p.product_category_name IS NOT NULL
             AND TRIM(p.product_category_name) <> ''
             AND t.product_category_name IS NULL
            THEN 1 ELSE 0
        END
    ) AS categories_without_translation
FROM olist_products p
LEFT JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name;
    
    
-- Check the actual product-table row count
SELECT
    COUNT(*) AS product_rows,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM olist_products;

-- Check whether translation category names are unique
SELECT
    product_category_name,
    COUNT(*) AS occurrences
FROM product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- Phase 2, Step 2I: Compare normal and exact category joins

SELECT
    COUNT(*) AS product_rows,
    COUNT(DISTINCT p.product_id) AS distinct_products,
    COUNT(DISTINCT CASE
        WHEN t.product_category_name IS NOT NULL
        THEN p.product_id
    END) AS products_with_translation
FROM olist_products p
LEFT JOIN product_category_name_translation t
    ON BINARY p.product_category_name =
       BINARY t.product_category_name;
       
       -- Phase 2, Step 2I: Classify product-category translation gaps

SELECT
    CASE
        WHEN p.product_category_name IS NULL
            THEN 'NULL category'
        WHEN TRIM(p.product_category_name) = ''
            THEN 'Blank category'
        WHEN EXISTS (
            SELECT 1
            FROM product_category_name_translation t
            WHERE t.product_category_name =
                  p.product_category_name
        )
            THEN 'Matched using normal comparison only'
        ELSE 'No translation match'
    END AS category_match_status,
    COUNT(*) AS product_count
FROM olist_products p
GROUP BY category_match_status
ORDER BY product_count DESC;

/*
Step 2I — Product-category reference validation

Verified results:
- Total products: 32,951
- Distinct products: 32,951
- Products with NULL categories: 610
- Products with no translation match: 13
- Products matching under normal comparison but not exact BINARY comparison: 32,328

Interpretation:
All 32,951 products are accounted for. The 610 NULL categories and
13 unmatched category values require separate treatment during data
cleaning. The 32,328 comparison difference requires further inspection
before standardizing category names.

No source tables were modified.
*/

-- Phase 2, Step 2J: Identify categories without translation matches

SELECT
    p.product_category_name,
    COUNT(*) AS product_count
FROM olist_products p
WHERE p.product_category_name IS NOT NULL
  AND TRIM(p.product_category_name) <> ''
  AND NOT EXISTS (
      SELECT 1
      FROM product_category_name_translation t
      WHERE t.product_category_name =
            p.product_category_name
  )
GROUP BY p.product_category_name
ORDER BY product_count DESC;

/*
Step 2J — Identify unmatched product categories

Verified results:
- portateis_cozinha_e_preparadores_de_alimentos: 10 products
- pc_gamer: 3 products
- Total products in unmatched categories: 13

Interpretation:
Both category values exist in olist_products but have no matching
Portuguese category key in product_category_name_translation.
The source category values will be preserved. No translations will
be invented, and no products will be deleted.

No source tables were modified.
*/


-- Phase 2, Step 2K: Inspect product categories and translation keys

SELECT DISTINCT
    p.product_category_name AS product_category,
    t.product_category_name AS translation_category,
    HEX(p.product_category_name) AS product_category_hex,
    HEX(t.product_category_name) AS translation_category_hex
FROM olist_products p
JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE BINARY p.product_category_name <>
      BINARY t.product_category_name
LIMIT 20;

-- Phase 2, Step 2K: Compare normal and binary category matches

SELECT
    COUNT(*) AS normal_join_rows,
    COUNT(DISTINCT p.product_id) AS normal_matched_products
FROM olist_products p
JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name;
    
    -- Compare exact binary category matches

SELECT
    COUNT(*) AS binary_join_rows,
    COUNT(DISTINCT p.product_id) AS binary_matched_products
FROM olist_products p
JOIN product_category_name_translation t
    ON BINARY p.product_category_name =
       BINARY t.product_category_name;
       
       -- Phase 2, Step 2L: Inspect all translation category keys

SELECT
    product_category_name,
    product_category_name_english,
    HEX(product_category_name) AS category_key_hex
FROM product_category_name_translation
ORDER BY product_category_name;


/*
Step 2L — Product-category translation audit

Verified findings:
- Product records: 32,951
- Distinct product IDs: 32,951
- Translation table records: 71
- Products matching a translation entry: 32,328
- Products with NULL categories: 610
- Products in unmatched categories: 13

The 13 unmatched products belong to:
- portateis_cozinha_e_preparadores_de_alimentos: 10
- pc_gamer: 3

Normal and BINARY joins both returned 32,328 matched products.
No evidence of comparison-related category mismatches was found.

Decision:
Preserve the original product categories. Handle NULL categories
and the 13 unmatched category values explicitly during the cleaning
phase. Do not invent translations or delete product records.

No source tables were modified.
*/

USE olist_analytics;

-- Phase 2, Mission 1:
-- Inspect column definitions and existing primary-key constraints.

SELECT
    c.TABLE_NAME,
    c.ORDINAL_POSITION,
    c.COLUMN_NAME,
    c.COLUMN_TYPE,
    c.IS_NULLABLE,
    c.COLUMN_KEY,
    c.EXTRA
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'olist_analytics'
  AND c.TABLE_NAME IN (
      'olist_customers',
      'olist_orders_dataset',
      'olist_products',
      'olist_sellers_dataset',
      'olist_order_items_dataset',
      'olist_order_payments_dataset',
      'olist_order_reviews_stage'
  )
ORDER BY
    c.TABLE_NAME,
    c.ORDINAL_POSITION;
    
    
    -- Phase 2, Mission 2
-- Check candidate primary-key columns before applying constraints.

SELECT
    'olist_customers' AS table_name,
    'customer_id' AS column_name,
    COUNT(*) AS total_rows,
    SUM(customer_id IS NULL) AS null_rows,
    SUM(
        customer_id IS NOT NULL
        AND TRIM(customer_id) = ''
    ) AS blank_rows
FROM olist_customers

UNION ALL

SELECT
    'olist_orders_dataset',
    'order_id',
    COUNT(*),
    SUM(order_id IS NULL),
    SUM(order_id IS NOT NULL AND TRIM(order_id) = '')
FROM olist_orders_dataset

UNION ALL

SELECT
    'olist_products',
    'product_id',
    COUNT(*),
    SUM(product_id IS NULL),
    SUM(product_id IS NOT NULL AND TRIM(product_id) = '')
FROM olist_products

UNION ALL

SELECT
    'olist_order_items_dataset',
    'order_id + order_item_id',
    COUNT(*),
    SUM(order_id IS NULL OR order_item_id IS NULL),
    SUM(
        order_id IS NOT NULL
        AND TRIM(order_id) = ''
    )
FROM olist_order_items_dataset

UNION ALL

SELECT
    'olist_order_payments_dataset',
    'order_id + payment_sequential',
    COUNT(*),
    SUM(order_id IS NULL OR payment_sequential IS NULL),
    SUM(
        order_id IS NOT NULL
        AND TRIM(order_id) = ''
    )
FROM olist_order_payments_dataset

UNION ALL

SELECT
    'olist_order_reviews_stage',
    'review_id + order_id',
    COUNT(*),
    SUM(review_id IS NULL OR order_id IS NULL),
    SUM(
        (review_id IS NOT NULL AND TRIM(review_id) = '')
        OR
        (order_id IS NOT NULL AND TRIM(order_id) = '')
    )
FROM olist_order_reviews_stage;

-- Phase 2, Mission 3
-- Inspect definitions of proposed foreign-key relationships.

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    CHARACTER_SET_NAME,
    COLLATION_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND (
       (TABLE_NAME = 'olist_orders_dataset'
        AND COLUMN_NAME IN ('order_id', 'customer_id'))

    OR (TABLE_NAME = 'olist_customers'
        AND COLUMN_NAME = 'customer_id')

    OR (TABLE_NAME = 'olist_order_items_dataset'
        AND COLUMN_NAME IN ('order_id', 'product_id', 'seller_id'))

    OR (TABLE_NAME = 'olist_products'
        AND COLUMN_NAME = 'product_id')

    OR (TABLE_NAME = 'olist_sellers_dataset'
        AND COLUMN_NAME = 'seller_id')

    OR (TABLE_NAME = 'olist_order_payments_dataset'
        AND COLUMN_NAME IN ('order_id', 'payment_sequential'))

    OR (TABLE_NAME = 'olist_order_reviews_stage'
        AND COLUMN_NAME IN ('review_id', 'order_id'))
  )
ORDER BY
    COLUMN_NAME,
    TABLE_NAME;
    
    
    -- Phase 2, Mission 4A
-- Check whether the proposed modeled table already exists.

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND TABLE_NAME = 'customers_model';
  
  -- Phase 2, Mission 4B
-- Create the cleaned customer dimension.
-- This does not modify or replace the original olist_customers table.

CREATE TABLE customers_model (
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(5),
    customer_city VARCHAR(100),
    customer_state CHAR(2),

    CONSTRAINT pk_customers_model
        PRIMARY KEY (customer_id)
);

-- Phase 2, Mission 4C
-- Copy the validated source customer records into the modeled table.

INSERT INTO customers_model (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM olist_customers;


-- Phase 2, Mission 4D
-- Both counts should equal 99441.

SELECT
    (SELECT COUNT(*)
     FROM olist_customers) AS source_rows,

    (SELECT COUNT(*)
     FROM customers_model) AS modeled_rows,

    (SELECT COUNT(DISTINCT customer_id)
     FROM customers_model) AS distinct_customer_ids;
     
     -- Phase 2, Mission 4E
-- Verify customer row counts, primary key, and source-to-model differences.

SELECT
    (SELECT COUNT(*) FROM olist_customers) AS source_rows,
    (SELECT COUNT(*) FROM customers_model) AS modeled_rows,
    (SELECT COUNT(DISTINCT customer_id)
     FROM customers_model) AS distinct_customer_ids,
    (SELECT COUNT(*)
     FROM customers_model
     WHERE customer_id IS NULL) AS null_customer_ids;
     
     SHOW KEYS FROM customers_model
WHERE Key_name = 'PRIMARY';





USE olist_analytics;

-- ============================================================
-- PHASE 2: DATA MODELING
-- MISSION 5: CREATE THE ORDERS MODEL
-- Purpose:
-- 1. Preserve the original imported orders table.
-- 2. Create a modeled orders table with appropriate constraints.
-- 3. Link every order to a valid customer.
-- ============================================================


-- STEP 1: Check whether orders_model already exists.
-- Why: Prevent accidental table-creation errors or overwriting
-- an existing modeled table.

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND TABLE_NAME = 'orders_model';


-- STEP 2: Create orders_model.
-- Run this only if Step 1 returns zero rows.
--
-- order_id is the primary key because each order must be
-- uniquely identifiable.
--
-- customer_id references customers_model.customer_id.
-- VARCHAR(50) matches the referenced customer key's datatype.
--
-- Delivery timestamps are nullable because some orders may
-- not have reached those delivery milestones yet.
--
-- The source table olist_orders_dataset is not modified.

CREATE TABLE orders_model (
    order_id VARCHAR(100) NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(100),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,

    CONSTRAINT pk_orders_model
        PRIMARY KEY (order_id),

    CONSTRAINT fk_orders_model_customers
        FOREIGN KEY (customer_id)
        REFERENCES customers_model (customer_id)
);


-- STEP 3: Copy source orders into the modeled table.
-- Run only after creating a new, empty orders_model table.
--
-- The explicit column list makes the mapping clear and avoids
-- relying on the physical order of columns in either table.
--
-- The foreign key validates that each customer_id exists in
-- customers_model. Invalid references will cause the insert
-- to fail rather than silently create orphan orders.

INSERT INTO orders_model (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM olist_orders_dataset;


-- STEP 4: Validate the modeled order count and primary key.
-- Expected, based on the verified source:
-- 99,441 modeled orders
-- 99,441 distinct order IDs
-- 0 NULL customer IDs

SELECT
    COUNT(*) AS modeled_orders,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    SUM(customer_id IS NULL) AS null_customer_ids
FROM orders_model;


-- STEP 5: Check for orders whose customer does not exist.
-- Expected: zero rows.
-- This independently checks relationship integrity.

SELECT
    o.order_id,
    o.customer_id
FROM orders_model o
LEFT JOIN customers_model c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- STEP 6: Inspect the primary and foreign key definitions.
-- Why: Confirm that MySQL created the intended constraints.

SHOW CREATE TABLE orders_model;

  
  -- ============================================================
-- PHASE 2: DATA MODELING
-- MISSION 6: CREATE THE PRODUCTS MODEL
-- Purpose: Build a product dimension for analytical reporting.
-- ============================================================

-- STEP 1: Check whether products_model already exists.
-- Why: Avoid accidentally recreating or overwriting a table.

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND TABLE_NAME = 'products_model';
  
  -- STEP 2: Create products_model.
-- product_id is the primary key because it uniquely identifies
-- each product in the validated source data.
-- Nullable attributes are preserved instead of inventing values.

CREATE TABLE products_model (
    product_id VARCHAR(50) NOT NULL,
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,

    CONSTRAINT pk_products_model
        PRIMARY KEY (product_id)
);

-- STEP 3: Copy source product records.
-- Explicit column mapping makes the transformation auditable.
-- The source table remains unchanged.

INSERT INTO products_model (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM olist_products;

-- STEP 4: Reconcile source and modeled product counts.
-- Expected: 32,951 source rows, 32,951 modeled rows,
-- and 32,951 distinct product IDs.

SELECT
    (SELECT COUNT(*)
     FROM olist_products) AS source_rows,

    (SELECT COUNT(*)
     FROM products_model) AS modeled_rows,

    (SELECT COUNT(DISTINCT product_id)
     FROM products_model) AS distinct_product_ids;


-- STEP 5: Confirm that NULL product IDs do not exist.
-- Expected: zero NULL product IDs.

SELECT
    COUNT(*) AS total_products,
    SUM(product_id IS NULL) AS null_product_ids
FROM products_model;


-- STEP 6: Confirm the primary-key definition.

SHOW KEYS FROM products_model
WHERE Key_name = 'PRIMARY';



-- PHASE 2: DATA MODELING
-- MISSION 7: CREATE THE ORDER ITEMS MODEL

-- Check first to avoid recreating an existing table.
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND TABLE_NAME = 'order_items_model';


-- Create the order-item fact table.
-- The composite primary key identifies each item within an order.
-- Foreign keys ensure that orders, products, and sellers exist.
-- The original source table remains unchanged.

CREATE TABLE order_items_model (
    order_id VARCHAR(100) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date DATETIME,
    price DECIMAL(10,2) NOT NULL,
    freight_value DECIMAL(10,2) NOT NULL,

    CONSTRAINT pk_order_items_model
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_model_orders
        FOREIGN KEY (order_id)
        REFERENCES orders_model (order_id),

    CONSTRAINT fk_order_items_model_products
        FOREIGN KEY (product_id)
        REFERENCES products_model (product_id),

    CONSTRAINT fk_order_items_model_sellers
        FOREIGN KEY (seller_id)
        REFERENCES olist_sellers_dataset (seller_id)
);


-- Copy validated order-item records into the modeled fact table.
-- Explicit casts align product_id and seller_id with their
-- referenced model columns; they do not change the source data.

INSERT INTO order_items_model (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    order_id,
    order_item_id,
    CAST(product_id AS CHAR(50)),
    CAST(seller_id AS CHAR(50)),
    shipping_limit_date,
    price,
    freight_value
FROM olist_order_items_dataset;

-- Compare source and modeled row counts.
-- Expected: 112,650 rows in each table.

SELECT
    (SELECT COUNT(*)
     FROM olist_order_items_dataset) AS source_rows,

    (SELECT COUNT(*)
     FROM order_items_model) AS modeled_rows;


-- Verify composite-key uniqueness.
-- Expected: total rows = distinct order/item pairs = 112,650.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(order_id, '#', order_item_id))
        AS distinct_order_item_pairs
FROM order_items_model;


-- Check the foreign-key relationships.
-- Expected: zero rows for each query.

SELECT oi.order_id
FROM order_items_model oi
LEFT JOIN orders_model o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT oi.product_id
FROM order_items_model oi
LEFT JOIN products_model p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT oi.seller_id
FROM order_items_model oi
LEFT JOIN olist_sellers_dataset s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Confirm that every source row was copied into the modeled table
SELECT
    (SELECT COUNT(*) FROM olist_order_items_dataset) AS source_rows,
    (SELECT COUNT(*) FROM order_items_model) AS modeled_rows;
    
    -- Each order-item combination should appear only once
SELECT COUNT(*) AS duplicate_order_item_pairs
FROM (
    SELECT order_id, order_item_id
    FROM order_items_model
    GROUP BY order_id, order_item_id
    HAVING COUNT(*) > 1
) AS duplicates;

-- Every order item must reference an order in orders_model
SELECT COUNT(*) AS unmatched_orders
FROM order_items_model oi
LEFT JOIN orders_model o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Every order item must reference a product in products_model
SELECT COUNT(*) AS unmatched_products
FROM order_items_model oi
LEFT JOIN products_model p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Every order item must reference an existing seller
SELECT COUNT(*) AS unmatched_sellers
FROM order_items_model oi
LEFT JOIN olist_sellers_dataset s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;




-- Check whether the payment model has already been created
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND TABLE_NAME = 'payments_model';


-- Create the modeled payment table
CREATE TABLE payments_model (
    order_id VARCHAR(100) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(12,2),

    -- One record per payment sequence within an order
    CONSTRAINT pk_payments_model
        PRIMARY KEY (order_id, payment_sequential),

    -- Link each payment to its corresponding order
    CONSTRAINT fk_payments_model_orders
        FOREIGN KEY (order_id)
        REFERENCES orders_model (order_id)
);

-- Check how many payment records are currently stored
SELECT COUNT(*) AS current_rows
FROM payments_model;



-- Populate payments_model from the original source table
INSERT INTO olist_analytics.payments_model (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM olist_analytics.olist_order_payments_dataset;


-- Check source and modeled payment record counts
SELECT
    (SELECT COUNT(*)
     FROM olist_analytics.olist_order_payments_dataset) AS source_rows,
    (SELECT COUNT(*)
     FROM olist_analytics.payments_model) AS modeled_rows;
     
     -- Check that every order-payment sequence is unique
SELECT COUNT(*) AS duplicate_payment_keys
FROM (
    SELECT order_id, payment_sequential
    FROM olist_analytics.payments_model
    GROUP BY order_id, payment_sequential
    HAVING COUNT(*) > 1
) AS duplicates;

-- Check that every payment references an existing modeled order
SELECT COUNT(*) AS unmatched_orders
FROM olist_analytics.payments_model AS p
LEFT JOIN olist_analytics.orders_model AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Compare total payment value in the source and modeled tables
SELECT
    'Source' AS data_location,
    COUNT(*) AS payment_records,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM olist_analytics.olist_order_payments_dataset

UNION ALL

SELECT
    'Model' AS data_location,
    COUNT(*) AS payment_records,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM olist_analytics.payments_model;

-- Analyze payment methods, record counts, and monetary totals
SELECT
    payment_type,
    COUNT(*) AS payment_records,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(
        100.0 * SUM(payment_value) /
        NULLIF(SUM(SUM(payment_value)) OVER (), 0),
        2
    ) AS percentage_of_payment_value
FROM olist_analytics.payments_model
GROUP BY payment_type
ORDER BY total_payment_value DESC;


-- =====================================================
-- BUSINESS FINDINGS: PAYMENT METHOD ANALYSIS
-- =====================================================
-- 1. Credit cards account for 78.34% of total payment value.
-- 2. Boleto accounts for 17.92% of total payment value.
-- 3. Vouchers account for 2.37% of total payment value.
-- 4. Debit cards account for 1.36% of total payment value.
-- 5. Three not_defined records have zero payment value.
-- 6. Source and modeled totals reconcile to $16,008,872.12.
--
-- Business interpretation:
-- Credit cards are the dominant payment method by value.
-- These results describe payment value, not profit or
-- customer preference. Further analysis is needed before
-- recommending changes to payment options.
-- =====================================================




-- ============================================================
-- OLIST E-COMMERCE ANALYTICS
-- PHASE 2: DATA MODELING
-- STEP 6: REVIEWS_MODEL
-- Source: olist_order_reviews_stage
-- Target: reviews_model
-- Purpose: Model review scores, comments, and timestamps
-- ============================================================

USE olist_analytics;


-- ------------------------------------------------------------
-- STEP 6.1: INSPECT SOURCE
-- ------------------------------------------------------------

DESCRIBE olist_order_reviews_stage;

SELECT COUNT(*) AS source_review_rows
FROM olist_order_reviews_stage;


-- ------------------------------------------------------------
-- STEP 6.2: CHECK SOURCE DATA QUALITY
-- ------------------------------------------------------------

-- Check required identifiers, score completeness, and score range
SELECT
    COUNT(*) AS total_rows,
    SUM(review_id IS NULL OR TRIM(review_id) = '')
        AS missing_review_ids,
    SUM(order_id IS NULL OR TRIM(order_id) = '')
        AS missing_order_ids,
    SUM(review_score IS NULL)
        AS missing_review_scores,
    SUM(
        review_score IS NOT NULL
        AND review_score NOT BETWEEN 1 AND 5
    ) AS invalid_review_scores
FROM olist_order_reviews_stage;


-- Check candidate composite key
-- Expected duplicate combinations: 0
SELECT COUNT(*) AS duplicate_review_keys
FROM (
    SELECT review_id, order_id
    FROM olist_order_reviews_stage
    GROUP BY review_id, order_id
    HAVING COUNT(*) > 1
) AS duplicate_keys;


-- Check references to modeled orders
-- Expected unmatched orders: 0
SELECT COUNT(*) AS unmatched_orders
FROM olist_order_reviews_stage AS r
LEFT JOIN orders_model AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


-- Inspect source timestamp values before conversion
SELECT
    review_creation_date,
    review_answer_timestamp
FROM olist_order_reviews_stage
WHERE review_creation_date IS NOT NULL
   OR review_answer_timestamp IS NOT NULL
LIMIT 20;


-- ------------------------------------------------------------
-- STEP 6.3: CREATE REVIEWS_MODEL
-- ------------------------------------------------------------
-- Run this CREATE TABLE statement only if reviews_model
-- does not already exist.
-- Composite primary key preserves reviews linked to orders.

CREATE TABLE reviews_model (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(100) NOT NULL,
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,

    CONSTRAINT pk_reviews_model
        PRIMARY KEY (review_id, order_id),

    CONSTRAINT fk_reviews_model_orders
        FOREIGN KEY (order_id)
        REFERENCES orders_model (order_id)
);


-- ------------------------------------------------------------
-- STEP 6.4: POPULATE REVIEWS_MODEL
-- ------------------------------------------------------------
-- Execute this INSERT only once after creating an empty table.
-- Assumes source timestamps use YYYY-MM-DD HH:MM:SS format.
-- Verify the actual format before using STR_TO_DATE.

INSERT INTO reviews_model (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    STR_TO_DATE(review_creation_date, '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(review_answer_timestamp, '%Y-%m-%d %H:%i:%s')
FROM olist_order_reviews_stage;


-- ------------------------------------------------------------
-- STEP 6.5: VALIDATE REVIEWS_MODEL
-- ------------------------------------------------------------

-- Check source and modeled row counts
SELECT
    (SELECT COUNT(*)
     FROM olist_order_reviews_stage) AS source_rows,
    (SELECT COUNT(*)
     FROM reviews_model) AS modeled_rows;


-- Check duplicate composite keys
SELECT COUNT(*) AS duplicate_review_keys
FROM (
    SELECT review_id, order_id
    FROM reviews_model
    GROUP BY review_id, order_id
    HAVING COUNT(*) > 1
) AS duplicate_keys;


-- Check unmatched order references
SELECT COUNT(*) AS unmatched_orders
FROM reviews_model AS r
LEFT JOIN orders_model AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


-- Check review score distribution
SELECT
    review_score,
    COUNT(*) AS review_count
FROM reviews_model
GROUP BY review_score
ORDER BY review_score;


-- Check missing modeled values
SELECT
    SUM(review_id IS NULL OR review_id = '') AS missing_review_ids,
    SUM(order_id IS NULL OR order_id = '') AS missing_order_ids,
    SUM(review_score IS NULL) AS missing_review_scores,
    SUM(review_creation_date IS NULL) AS missing_creation_dates,
    SUM(review_answer_timestamp IS NULL) AS missing_answer_timestamps
FROM reviews_model;





-- ------------------------------------------------------------
-- STEP 6.6: BUSINESS ANALYSIS
-- ------------------------------------------------------------

-- Review count and average score
SELECT
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS average_review_score,
    SUM(review_score = 5) AS five_star_reviews,
    SUM(review_score = 1) AS one_star_reviews
FROM reviews_model;


-- Save your work in modelling.sql after reviewing results.
-- Do not rerun CREATE TABLE or INSERT blindly.




-- =====================================================
-- MODEL: SELLERS
-- Purpose: Inspect and validate the source data
-- Source: olist_sellers_dataset
-- Target: sellers_model
-- =====================================================

-- 1. Inspect source columns and data types
DESCRIBE olist_sellers_dataset;

-- 2. Check row count, unique seller IDs, and missing IDs
SELECT
    COUNT(*) AS source_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids,
    SUM(
        seller_id IS NULL
        OR TRIM(seller_id) = ''
    ) AS missing_seller_ids
FROM olist_sellers_dataset;

-- 3. Inspect sample records
SELECT *
FROM olist_sellers_dataset
LIMIT 10;

-- 4. Check for duplicate seller IDs
SELECT
    seller_id,
    COUNT(*) AS occurrences
FROM olist_sellers_dataset
GROUP BY seller_id
HAVING COUNT(*) > 1
LIMIT 20;


-- =====================================================
-- MODEL: SELLERS
-- Purpose: Create a structured seller dimension table
-- Source: olist_sellers_dataset
-- Target: sellers_model
-- =====================================================

-- 1. Create the modeled seller table
CREATE TABLE sellers_model (
    seller_id VARCHAR(50) NOT NULL,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state CHAR(2),

    CONSTRAINT pk_sellers_model
        PRIMARY KEY (seller_id)
);

-- 2. Load source data into the modeled table
INSERT INTO sellers_model (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM olist_sellers_dataset;


-- 1. Compare source and modeled row counts
SELECT
    (SELECT COUNT(*) FROM olist_sellers_dataset) AS source_rows,
    (SELECT COUNT(*) FROM sellers_model) AS modeled_rows;

-- 2. Check missing seller IDs
SELECT COUNT(*) AS missing_seller_ids
FROM sellers_model
WHERE seller_id IS NULL
   OR TRIM(seller_id) = '';

-- 3. Check duplicate seller IDs
SELECT seller_id, COUNT(*) AS occurrences
FROM sellers_model
GROUP BY seller_id
HAVING COUNT(*) > 1;

-- 4. Inspect the modeled data
SELECT *
FROM sellers_model
LIMIT 10;

-- 5. Check seller counts by state
SELECT
    seller_state,
    COUNT(*) AS seller_count
FROM sellers_model
GROUP BY seller_state
ORDER BY seller_count DESC;



-- =====================================================
-- FINAL VALIDATION: SELLERS MODEL
-- =====================================================

-- 1. Compare source and modeled row counts
SELECT
    (SELECT COUNT(*) FROM olist_sellers_dataset) AS source_rows,
    (SELECT COUNT(*) FROM sellers_model) AS modeled_rows;

-- 2. Confirm seller IDs are unique
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS distinct_seller_ids
FROM sellers_model;

-- 3. Confirm all modeled seller IDs match the source
SELECT COUNT(*) AS unmatched_sellers
FROM sellers_model m
LEFT JOIN olist_sellers_dataset s
    ON m.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- 4. Confirm the modeled schema
SHOW CREATE TABLE sellers_model;





-- =====================================================
-- MODEL: PRODUCT CATEGORY TRANSLATIONS
-- Purpose: Inspect source data before modeling
-- Source: product_category_name_translation
-- Target: product_category_translation_model
-- =====================================================

-- 1. Inspect source columns and data types
DESCRIBE product_category_name_translation;

-- 2. Check row count, distinct categories, and missing values
SELECT
    COUNT(*) AS source_rows,
    COUNT(DISTINCT product_category_name) AS distinct_portuguese_categories,
    COUNT(DISTINCT product_category_name_english) AS distinct_english_categories,
    SUM(
        product_category_name IS NULL
        OR TRIM(product_category_name) = ''
    ) AS missing_portuguese_categories,
    SUM(
        product_category_name_english IS NULL
        OR TRIM(product_category_name_english) = ''
    ) AS missing_english_categories
FROM product_category_name_translation;

-- 3. Check duplicate Portuguese category names
SELECT
    product_category_name,
    COUNT(*) AS occurrences
FROM product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- 4. Preview the source records
SELECT *
FROM product_category_name_translation
LIMIT 10;



-- =====================================================
-- MODEL: PRODUCT CATEGORY TRANSLATIONS
-- Purpose: Store Portuguese-to-English category mappings
-- Source: product_category_name_translation
-- Target: product_category_translation_model
-- =====================================================

-- 1. Create the modeled table
CREATE TABLE product_category_translation_model (
    product_category_name VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100) NOT NULL,

    CONSTRAINT pk_product_category_translation_model
        PRIMARY KEY (product_category_name)
);

-- 2. Load the source data
INSERT INTO product_category_translation_model (
    product_category_name,
    product_category_name_english
)
SELECT
    product_category_name,
    product_category_name_english
FROM product_category_name_translation;


-- 1. Compare source and modeled row counts
SELECT
    (SELECT COUNT(*)
     FROM product_category_name_translation) AS source_rows,
    (SELECT COUNT(*)
     FROM product_category_translation_model) AS modeled_rows;

-- 2. Check for duplicate Portuguese category keys
SELECT
    product_category_name,
    COUNT(*) AS occurrences
FROM product_category_translation_model
GROUP BY product_category_name
HAVING COUNT(*) > 1;

-- 3. Check for missing category names
SELECT
    SUM(
        product_category_name IS NULL
        OR TRIM(product_category_name) = ''
    ) AS missing_portuguese_categories,
    SUM(
        product_category_name_english IS NULL
        OR TRIM(product_category_name_english) = ''
    ) AS missing_english_categories
FROM product_category_translation_model;

-- 4. Find source mappings missing from the model
SELECT COUNT(*) AS missing_source_mappings
FROM product_category_name_translation s
LEFT JOIN product_category_translation_model m
    ON s.product_category_name = m.product_category_name
WHERE m.product_category_name IS NULL;

-- 5. Preview the modeled translations
SELECT *
FROM product_category_translation_model
ORDER BY product_category_name
LIMIT 15;



-- =====================================================
-- FINAL VALIDATION: PRODUCT CATEGORY TRANSLATIONS
-- =====================================================

-- 1. Compare total and distinct category counts
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS distinct_portuguese_categories,
    COUNT(DISTINCT product_category_name_english) AS distinct_english_categories
FROM product_category_translation_model;

-- 2. Confirm the primary key and table structure
SHOW CREATE TABLE product_category_translation_model;

-- 3. Compare English mappings between source and model
SELECT COUNT(*) AS mismatched_translations
FROM product_category_name_translation s
JOIN product_category_translation_model m
    ON s.product_category_name = m.product_category_name
WHERE NOT (
    s.product_category_name_english
    <=> m.product_category_name_english
);




-- =====================================================
-- MODEL: GEOLOCATION
-- Purpose: Assess source data before modeling
-- Source: olist_geolocation_dataset
-- =====================================================

-- 1. Inspect the source structure
DESCRIBE olist_geolocation_dataset;

-- 2. Check row count and missing location fields
SELECT
    COUNT(*) AS source_rows,
    SUM(geolocation_zip_code_prefix IS NULL) AS missing_zip_prefix,
    SUM(geolocation_lat IS NULL) AS missing_latitude,
    SUM(geolocation_lng IS NULL) AS missing_longitude,
    SUM(geolocation_city IS NULL) AS missing_city,
    SUM(geolocation_state IS NULL) AS missing_state
FROM olist_geolocation_dataset;

-- 3. Assess unique postal prefixes
SELECT
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes
FROM olist_geolocation_dataset;

-- 4. Inspect sample records
SELECT *
FROM olist_geolocation_dataset
LIMIT 10;


-- =====================================================
-- GEOLOCATION: PROFILE POSTAL-CODE PREFIXES
-- Purpose: Assess multiple locations per postal prefix
-- =====================================================

-- 1. Count rows and unique coordinate pairs per prefix
SELECT
    geolocation_zip_code_prefix,
    COUNT(*) AS source_rows,
    COUNT(
        DISTINCT CONCAT(
            geolocation_lat, '|', geolocation_lng
        )
    ) AS distinct_coordinate_pairs,
    COUNT(DISTINCT geolocation_city) AS distinct_cities,
    COUNT(DISTINCT geolocation_state) AS distinct_states
FROM olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix
ORDER BY source_rows DESC
LIMIT 20;

-- 2. Check whether state labels conflict within a prefix
SELECT
    geolocation_zip_code_prefix,
    COUNT(DISTINCT geolocation_state) AS distinct_states
FROM olist_geolocation_dataset
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(DISTINCT geolocation_state) > 1
LIMIT 20;


-- =====================================================
-- MODEL: GEOLOCATION LOOKUP
-- Purpose: Create one record per postal-code prefix
-- Source: olist_geolocation_dataset
-- Target: geolocation_model
-- =====================================================

CREATE TABLE geolocation_model (
    geolocation_zip_code_prefix VARCHAR(10) NOT NULL,
    geolocation_lat DECIMAL(10,7),
    geolocation_lng DECIMAL(10,7),
    geolocation_city VARCHAR(100),
    geolocation_state CHAR(2),

    CONSTRAINT pk_geolocation_model
        PRIMARY KEY (geolocation_zip_code_prefix)
);

-- Aggregate raw coordinate records into one row per prefix.
-- AVG produces a representative coordinate; MAX selects a
-- representative label, not necessarily the most frequent label.
INSERT INTO geolocation_model (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    geolocation_zip_code_prefix,
    AVG(geolocation_lat),
    AVG(geolocation_lng),
    MAX(geolocation_city),
    MAX(geolocation_state)
FROM olist_geolocation_dataset
WHERE geolocation_zip_code_prefix IS NOT NULL
  AND TRIM(geolocation_zip_code_prefix) <> ''
GROUP BY geolocation_zip_code_prefix;



-- Check whether the failed insert left any rows
SELECT COUNT(*) AS current_model_rows
FROM geolocation_model;

-- Inspect the postal prefixes currently stored
SELECT
    geolocation_zip_code_prefix,
    COUNT(*) AS occurrences
FROM geolocation_model
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1
LIMIT 20;

-- Check how many source rows and distinct prefixes exist
SELECT
    COUNT(*) AS source_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_prefixes,
    COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix)
        AS rows_beyond_distinct_prefixes
FROM olist_geolocation_dataset;

-- Check whether any rows remain in the target table
SELECT COUNT(*) AS current_model_rows
FROM geolocation_model;

-- Inspect the source column types
DESCRIBE olist_geolocation_dataset;




-- =====================================================
-- VALIDATION: GEOLOCATION MODEL
-- Purpose: Verify existing modeled records
-- =====================================================

-- 1. Compare source and modeled postal-prefix counts
SELECT
    (
        SELECT COUNT(DISTINCT geolocation_zip_code_prefix)
        FROM olist_geolocation_dataset
        WHERE geolocation_zip_code_prefix IS NOT NULL
          AND TRIM(geolocation_zip_code_prefix) <> ''
    ) AS source_prefixes,
    (
        SELECT COUNT(*)
        FROM geolocation_model
    ) AS modeled_prefixes;

-- 2. Check for duplicate prefixes in the model
SELECT
    geolocation_zip_code_prefix,
    COUNT(*) AS occurrences
FROM geolocation_model
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(*) > 1;

-- 3. Check missing coordinates
SELECT
    COUNT(*) AS total_rows,
    SUM(geolocation_lat IS NULL) AS missing_latitudes,
    SUM(geolocation_lng IS NULL) AS missing_longitudes
FROM geolocation_model;

-- 4. Inspect the modeled coordinates and labels
SELECT *
FROM geolocation_model
ORDER BY geolocation_zip_code_prefix
LIMIT 10;




-- =====================================================
-- GEOLOCATION: VERIFY COORDINATE AGGREGATION
-- =====================================================

SELECT
    COUNT(*) AS prefixes_checked,
    SUM(
        ABS(
            m.geolocation_lat -
            s.avg_lat
        ) > 0.000001
    ) AS latitude_mismatches,
    SUM(
        ABS(
            m.geolocation_lng -
            s.avg_lng
        ) > 0.000001
    ) AS longitude_mismatches
FROM geolocation_model m
JOIN (
    SELECT
        geolocation_zip_code_prefix,
        AVG(CAST(NULLIF(TRIM(geolocation_lat), '') AS DECIMAL(12,8))) AS avg_lat,
        AVG(CAST(NULLIF(TRIM(geolocation_lng), '') AS DECIMAL(12,8))) AS avg_lng
    FROM olist_geolocation_dataset
    WHERE geolocation_zip_code_prefix IS NOT NULL
      AND TRIM(geolocation_zip_code_prefix) <> ''
    GROUP BY geolocation_zip_code_prefix
) s
    ON m.geolocation_zip_code_prefix =
       s.geolocation_zip_code_prefix;



-- =====================================================
-- FINAL MODELING AUDIT — PHASE 1
-- Purpose: Validate order-item relationships
-- Tables: order_items_model, orders_model,
--         products_model, sellers_model
-- =====================================================

-- 1. Compare source and modeled order-item row counts
SELECT
    (SELECT COUNT(*)
     FROM olist_order_items_dataset) AS source_rows,
    (SELECT COUNT(*)
     FROM order_items_model) AS modeled_rows;

-- 2. Check order-item key uniqueness
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CONCAT(
        order_id, '|', order_item_id
    )) AS distinct_order_item_keys
FROM order_items_model;

-- 3. Check order references
SELECT COUNT(*) AS unmatched_orders
FROM order_items_model oi
LEFT JOIN orders_model o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 4. Check product references
SELECT COUNT(*) AS unmatched_products
FROM order_items_model oi
LEFT JOIN products_model p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 5. Check seller references
SELECT COUNT(*) AS unmatched_sellers
FROM order_items_model oi
LEFT JOIN sellers_model s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;



-- =====================================================
-- FINAL MODELING AUDIT — PHASE 2
-- Purpose: Validate customer, payment, and review links
-- =====================================================

-- 1. Check that every order links to a valid customer
SELECT COUNT(*) AS unmatched_order_customers
FROM orders_model o
LEFT JOIN customers_model c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- 2. Check that every payment links to a valid order
SELECT COUNT(*) AS unmatched_payment_orders
FROM payments_model p
LEFT JOIN orders_model o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 3. Check that every review links to a valid order
SELECT COUNT(*) AS unmatched_review_orders
FROM reviews_model r
LEFT JOIN orders_model o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 4. Compare payment source and model row counts
SELECT
    (SELECT COUNT(*) FROM olist_order_payments_dataset)
        AS source_payment_rows,
    (SELECT COUNT(*) FROM payments_model)
        AS modeled_payment_rows;

-- 5. Compare review source and model row counts
SELECT
    (SELECT COUNT(*) FROM olist_order_reviews_stage)
        AS source_review_rows,
    (SELECT COUNT(*) FROM reviews_model)
        AS modeled_review_rows;



-- =====================================================
-- OLIST E-COMMERCE ANALYTICS
-- FINAL MODELING SUMMARY
-- Database: olist_analytics
-- Purpose: Document modeled tables and final audit status
-- =====================================================

-- MODELED TABLES
-- 1. customers_model
-- 2. orders_model
-- 3. products_model
-- 4. order_items_model
-- 5. payments_model
-- 6. reviews_model
-- 7. sellers_model
-- 8. product_category_translation_model
-- 9. geolocation_model

-- MODELING DESIGN
-- - Primary keys identify modeled records.
-- - Foreign keys connect orders, customers, and related entities.
-- - order_items_model connects orders, products, and sellers.
-- - payments_model uses a composite key:
--   (order_id, payment_sequential).
-- - reviews_model uses a composite key:
--   (review_id, order_id).
-- - geolocation_model contains one row per postal-code prefix.
-- - product_category_translation_model maps Portuguese
--   category names to English labels.

-- DATA QUALITY NOTES
-- - Original source tables are preserved.
-- - Product category values without source translations
--   should remain unchanged rather than be guessed.
-- - Geolocation coordinates are aggregated by postal prefix.
--   They are approximate and are not exact addresses.
-- - Geolocation city/state labels use MAX() in the current
--   model and may not represent the most frequent label.
-- - Source and modeled row counts should be checked before
--   any future reload or rebuild.

-- FINAL AUDIT
-- Phase 1: Order-item relationships — queries executed.
-- Phase 2: Customer, payment, and review relationships —
-- queries executed.
-- Confirm the actual outputs before declaring all checks passed.

-- END OF MODELING PHASE


