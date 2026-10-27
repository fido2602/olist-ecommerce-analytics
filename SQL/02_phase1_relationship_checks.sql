-- =====================================================
-- Phase 1 | Relationship Check 1
-- Payments -> Orders
-- Purpose: Find payment rows with no matching order
-- Expected result: 0 unmatched payment rows
-- =====================================================

SELECT
    COUNT(*) AS unmatched_payment_rows
FROM olist_order_payments_dataset AS p
LEFT JOIN olist_orders_dataset AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- =====================================================
-- Phase 1 | Relationship Check 2
-- Payments -> Orders
-- Purpose: Confirm the join preserves all payment rows
-- Expected result: Both counts equal 103,886
-- =====================================================

SELECT
    (SELECT COUNT(*)
     FROM olist_order_payments_dataset) AS payment_rows,

    (SELECT COUNT(*)
     FROM olist_order_payments_dataset AS p
     INNER JOIN olist_orders_dataset AS o
         ON p.order_id = o.order_id) AS matched_join_rows;
         
         -- =====================================================
-- Phase 1 | Relationship Check 3
-- Orders -> Customers
-- Purpose: Find orders without a matching customer
-- Expected result: 0 unmatched orders
-- =====================================================

SELECT
    COUNT(*) AS orders_without_matching_customer
FROM olist_orders_dataset AS o
LEFT JOIN olist_customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- =====================================================
-- Phase 1 | Relationship Check 4
-- Orders -> Customers
-- Purpose: Confirm the join preserves all order rows
-- Expected result: Both counts equal 99,441
-- =====================================================

SELECT
    (SELECT COUNT(*)
     FROM olist_orders_dataset) AS orders_count,

    (SELECT COUNT(*)
     FROM olist_orders_dataset AS o
     INNER JOIN olist_customers AS c
         ON o.customer_id = c.customer_id) AS matched_join_rows;
         
         -- =====================================================
-- Phase 1 | Relationship Check 5
-- Orders -> Order Items
-- Purpose: Find orders without matching item records
-- Expected result: 775 orders without items
-- =====================================================

SELECT
    COUNT(*) AS orders_without_items
FROM olist_orders_dataset AS o
LEFT JOIN olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;


-- =====================================================
-- Phase 1 | Relationship Check 6
-- Orders -> Order Items
-- Purpose: Count orders without items by order status
-- =====================================================

SELECT
    o.order_status,
    COUNT(*) AS orders_without_items
FROM olist_orders_dataset AS o
LEFT JOIN olist_order_items_dataset AS oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_items DESC;


-- =====================================================
-- Phase 1 | Relationship Check 7
-- Order Items -> Orders
-- Purpose: Find item rows without a matching order
-- Expected result: 0 unmatched item rows
-- =====================================================

SELECT
    COUNT(*) AS unmatched_item_rows
FROM olist_order_items_dataset AS oi
LEFT JOIN olist_orders_dataset AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- =====================================================
-- Phase 1 | Relationship Check 8
-- Orders -> Order Items
-- Purpose: Summarize item counts per order
-- =====================================================

SELECT
    COUNT(*) AS orders_with_items,
    MIN(item_count) AS minimum_items_per_order,
    MAX(item_count) AS maximum_items_per_order,
    ROUND(AVG(item_count), 2) AS average_items_per_order
FROM (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM olist_order_items_dataset
    GROUP BY order_id
) AS order_item_counts;


-- =====================================================
-- Phase 1 | Relationship Check 9
-- Order Items
-- Purpose: Reconcile grouped item counts with total rows
-- Expected result: Both counts equal 112,650
-- =====================================================

SELECT
    (SELECT COUNT(*)
     FROM olist_order_items_dataset) AS total_item_rows,

    (SELECT SUM(item_count)
     FROM (
         SELECT
             order_id,
             COUNT(*) AS item_count
         FROM olist_order_items_dataset
         GROUP BY order_id
     ) AS order_item_counts) AS summed_item_counts;
     
     
     -- =====================================================
-- Phase 1 | Relationship Check 10
-- Order Reviews
-- Purpose: Verify that review order IDs match existing
-- orders in the Orders dataset
-- Expected result: 0 rows without a matching order
-- =====================================================
SELECT
    COUNT(*) AS total_review_rows,
    COUNT(DISTINCT r.order_id) AS distinct_review_orders,
    SUM(o.order_id IS NULL) AS rows_without_matching_order
FROM olist_order_reviews_stage AS r
LEFT JOIN olist_orders_dataset AS o
    ON r.order_id = o.order_id;
    
    -- =====================================================
-- Phase 1 | Relationship Check 11
-- Order Reviews
-- Purpose: Count orders associated with multiple
-- review records
-- Expected result: Review multiplicity documented
-- =====================================================

SELECT
    review_count,
    COUNT(*) AS order_count
FROM (
    SELECT
        order_id,
        COUNT(*) AS review_count
    FROM olist_order_reviews_stage
    GROUP BY order_id
) AS order_review_counts
GROUP BY review_count
ORDER BY review_count;

-- =====================================================
-- Phase 1 | Relationship Check 12
-- Order Reviews
-- Purpose: Inspect orders associated with three
-- review records
-- Expected result: Records returned for investigation
-- =====================================================

SELECT
    order_id,
    review_id,
    review_score,
    review_comment_title,
    review_creation_date,
    review_answer_timestamp
FROM olist_order_reviews_stage
WHERE order_id IN (
    SELECT order_id
    FROM olist_order_reviews_stage
    GROUP BY order_id
    HAVING COUNT(*) = 3
)
ORDER BY order_id, review_creation_date;

-- =====================================================
-- Phase 1 | Relationship Check 13
-- Order Reviews
-- Purpose: Identify order-and-score combinations
-- occurring more than once
-- Expected result: Duplicate combinations quantified
-- =====================================================

SELECT
    order_id,
    review_score,
    COUNT(*) AS matching_records
FROM olist_order_reviews_stage
GROUP BY
    order_id,
    review_score
HAVING COUNT(*) > 1
ORDER BY matching_records DESC, order_id;

-- =====================================================
-- Phase 1 | Relationship Check 13
-- Order Reviews
-- Purpose: Summarize repeated order-and-score
-- combinations by number of matching records
-- Expected result: Frequency distribution returned
-- =====================================================

SELECT
    matching_records,
    COUNT(*) AS order_score_combinations
FROM (
    SELECT
        order_id,
        review_score,
        COUNT(*) AS matching_records
    FROM olist_order_reviews_stage
    GROUP BY order_id, review_score
    HAVING COUNT(*) > 1
) AS repeated_combinations
GROUP BY matching_records
ORDER BY matching_records;

-- =====================================================
-- Phase 1 | Relationship Check 14
-- Order Reviews
-- Purpose: Check whether repeated order-and-score
-- combinations contain distinct review IDs
-- Expected result: Identifier pattern quantified
-- =====================================================

SELECT
    order_id,
    review_score,
    COUNT(*) AS matching_records,
    COUNT(DISTINCT review_id) AS distinct_review_ids
FROM olist_order_reviews_stage
GROUP BY
    order_id,
    review_score
HAVING COUNT(*) > 1
ORDER BY matching_records DESC, order_id;

-- Actual result:
-- The displayed repeated order-and-score combinations
-- have distinct review IDs.
-- Status: No records deleted; repeated combinations
-- documented for further analysis if needed.



-- =====================================================
-- Phase 1 | Relationship Check 15
-- Order Reviews
-- Purpose: Summarize repeated order-and-score
-- combinations by review ID uniqueness
-- Expected result: Counts reconcile to Check 13
-- =====================================================

SELECT
    COUNT(*) AS repeated_combinations,
    SUM(
        matching_records = distinct_review_ids
    ) AS combinations_with_distinct_review_ids,
    SUM(
        matching_records > distinct_review_ids
    ) AS combinations_with_repeated_review_ids
FROM (
    SELECT
        order_id,
        review_score,
        COUNT(*) AS matching_records,
        COUNT(DISTINCT review_id) AS distinct_review_ids
    FROM olist_order_reviews_stage
    GROUP BY order_id, review_score
    HAVING COUNT(*) > 1
) AS repeated_combinations;
    
    

-- Actual result:
-- 347 repeated order-and-score combinations identified.
-- All 347 combinations contain distinct review IDs.
-- 0 combinations contain repeated review IDs.
-- Status: PASS
-- Decision: No records deleted.

-- =====================================================
-- Phase 1 | Order Reviews Relationship Checks Summary
-- Purpose: Record the validation results for the
-- Order Reviews dataset
-- =====================================================

-- Check 10: Review-to-order matching
-- 99,224 review rows checked.
-- 98,673 distinct review orders.
-- 0 rows without a matching order.
-- Status: PASS

-- Check 11: Reviews per order
-- 98,126 orders have 1 review record.
-- 543 orders have 2 review records.
-- 4 orders have 3 review records.
-- Total: 98,673 distinct orders and 99,224 review rows.
-- Status: Documented

-- Check 12: Orders with 3 review records
-- 4 orders inspected.
-- Records have distinct review IDs and timestamps.
-- No records deleted.
-- Status: Documented

-- Check 13: Repeated order-and-score combinations
-- 347 repeated combinations identified.
-- Status: Investigated

-- Check 14: Review ID uniqueness in repeated combinations
-- Check 15 summary: 347 combinations have distinct
-- review IDs; 0 have repeated review IDs.
-- Status: PASS

-- Overall decision:
-- All review rows match existing orders.
-- Multiple review records are preserved.
-- No records were deleted based solely on repetition.
-- Repeated review IDs across different orders remain
-- a documented source-data anomaly.




-- =====================================================
-- Phase 1 | Relationship Check 16
-- Order Items -> Products
-- Purpose: Find order-item rows whose product ID does
--          not exist in the production products table.
-- Relationship:
--          olist_order_items_dataset.product_id
--          -> olist_products.product_id
-- Expected result: 0 unmatched item rows
-- =====================================================

-- WHY:
-- Order items reference products through product_id.
-- A LEFT JOIN keeps every order-item row, even when the
-- corresponding product cannot be found.
-- A NULL product ID on the joined products side identifies
-- an unmatched reference.
-- This query is read-only and does not delete any records.

SELECT
    COUNT(*) AS unmatched_product_reference_rows
FROM olist_order_items_dataset AS oi
LEFT JOIN olist_products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- RESULT:
-- 0 unmatched product references.
-- PASS: Every order-item product_id exists in olist_products.

-- =====================================================
-- Phase 1 | Relationship Check 17
-- Products -> Order Items
-- Purpose: Identify products that have no order-item
--          records referencing them.
-- Expected result: A count of unreferenced products.
-- =====================================================

-- WHY:
-- Start with every product, then LEFT JOIN order items.
-- Products with no matching order item will have
-- NULL in oi.product_id.
-- This is an investigation, not an error by itself:
-- some products may never have been purchased.

SELECT
    COUNT(*) AS products_never_ordered
FROM olist_products AS p
LEFT JOIN olist_order_items_dataset AS oi
    ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL;

-- RESULT:
-- 0 products without order-item references.
-- All products in olist_products appear in olist_order_items_dataset.
-- NOTE: This confirms a reference exists, not that every product
-- was purchased in a completed or delivered order.


-- =====================================================
-- Phase 1 | Relationship Check 18
-- Product ID reconciliation
-- Purpose: Compare total and distinct product IDs
--          across products and order items.
-- =====================================================

-- WHY:
-- Products should have unique product IDs in the
-- production table. Order items can repeat product IDs
-- because the same product can be ordered many times.
-- We compare total rows and distinct IDs to understand
-- the relationship's cardinality.

SELECT
    (SELECT COUNT(*)
     FROM olist_products) AS total_product_rows,

    (SELECT COUNT(DISTINCT product_id)
     FROM olist_products) AS distinct_product_ids,

    (SELECT COUNT(*)
     FROM olist_order_items_dataset) AS total_order_item_rows,

    (SELECT COUNT(DISTINCT product_id)
     FROM olist_order_items_dataset) AS distinct_products_in_order_items;


-- RESULT:
-- 32,951 product rows and 32,951 distinct product IDs.
-- 112,650 order-item rows reference 32,951 distinct products.
-- PASS: Product IDs are unique in olist_products.
-- PASS: Every product in the catalog is referenced by order items.
-- NOTE: These counts confirm ID coverage, not order delivery status.


-- =====================================================
-- Phase 1 | Relationship Check 19
-- Check whether a product category translation table exists
-- Purpose: Identify imported tables that may relate to
--          product_category_name.
-- =====================================================

-- WHY:
-- We must verify the actual table name before testing
-- a relationship. This query only reads schema metadata.

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND TABLE_NAME LIKE '%translation%'
ORDER BY TABLE_NAME;


-- UPDATED RESULT — Relationship Check 19
-- The product category translation table was subsequently imported
-- as product_category_name_translation.
-- Its relationship with olist_products is evaluated in Checks 25–27.
-- Status: Translation table exists and relationship checks are documented.



-- =====================================================
-- Relationship Check 20: Identify Product-Related Tables
-- Purpose: List all imported tables in this schema.
-- =====================================================

-- WHY:
-- We have verified the product-to-order-item relationship.
-- This query lists actual tables so we can identify any
-- additional table that contains product information.
-- It does not change any data.

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'olist_analytics'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;



-- =====================================================
-- Phase 1 | Relationship Check 21
-- Order Item Product ID Completeness
-- Purpose: Check for missing product IDs in order items.
-- =====================================================

-- WHY:
-- A NULL or blank product_id cannot reliably identify
-- a product or participate in a normal equality join.
-- We count both NULL and blank values separately.
-- This query is read-only.

SELECT
    COUNT(*) AS total_order_item_rows,

    SUM(
        CASE
            WHEN product_id IS NULL THEN 1
            ELSE 0
        END
    ) AS null_product_ids,

    SUM(
        CASE
            WHEN product_id IS NOT NULL
             AND TRIM(product_id) = ''
            THEN 1
            ELSE 0
        END
    ) AS blank_product_ids

FROM olist_order_items_dataset;

-- RESULT:
-- 112,650 total order-item rows.
-- 0 NULL product IDs.
-- 0 blank product IDs.
-- PASS: Every order-item row has a populated product_id.

-- =====================================================
-- PRODUCT RELATIONSHIP CHECKS: SUMMARY
-- =====================================================
-- Checks completed:
-- 16. Order items -> Products: 0 unmatched references.
-- 17. Products -> Order items: 0 unreferenced products.
-- 18. Product ID count reconciliation: 32,951 products;
--     112,650 order-item rows; 32,951 distinct products
--     referenced by order items.
-- 19. Category translation: No matching table imported.
-- 20. Table inventory reviewed.
-- 21. Order-item product ID completeness: 0 NULL and
--     0 blank product IDs.
--
-- CONCLUSION:
-- The product-to-order-item relationship passes the
-- checks performed against the current schema.
-- No records were modified or deleted by these checks.
-- =====================================================



-- =====================================================
-- Phase 1 | Relationship Check 22
-- Order Item Seller ID Completeness
-- Purpose: Check for missing seller IDs in order items.
-- =====================================================

-- WHY:
-- A NULL or blank seller_id cannot reliably identify
-- a seller or participate in a normal equality join.
-- We count NULL and blank values separately.
-- This query is read-only.

SELECT
    COUNT(*) AS total_order_item_rows,

    SUM(
        CASE
            WHEN seller_id IS NULL THEN 1
            ELSE 0
        END
    ) AS null_seller_ids,

    SUM(
        CASE
            WHEN seller_id IS NOT NULL
             AND TRIM(seller_id) = ''
            THEN 1
            ELSE 0
        END
    ) AS blank_seller_ids

FROM olist_order_items_dataset;

-- RESULT:
-- Record the actual results after execution.
-- Expected: 112,650 total rows, with no NULL or blank
-- seller IDs if the source data passes completeness checks.

-- =====================================================
-- Phase 1 | Relationship Check 23
-- Order Items -> Sellers: Unmatched References
-- Purpose: Find order items whose seller_id does not
--          exist in the imported sellers table.
-- =====================================================

-- WHY:
-- Every seller referenced by an order item should exist
-- in the sellers dataset. Unmatched IDs may indicate
-- missing seller records or inconsistent identifiers.
-- This query is read-only.

SELECT
    COUNT(*) AS unmatched_order_item_rows,
    COUNT(DISTINCT oi.seller_id) AS unmatched_seller_ids
FROM olist_order_items_dataset oi
LEFT JOIN olist_sellers_dataset s
    ON TRIM(oi.seller_id) = TRIM(s.seller_id)
WHERE s.seller_id IS NULL;

-- RESULT:
-- Record the actual results after execution.
-- Previously verified distinct-seller relationship:
-- 3,095 distinct sellers referenced by order items,
-- 0 unmatched seller IDs.
-- Reconcile row-level unmatched count with this result.

-- =====================================================
-- Phase 1 | Relationship Check 24
-- Sellers -> Order Items: Unreferenced Sellers
-- Purpose: Identify sellers not referenced by any
--          order-item record.
-- =====================================================

-- WHY:
-- Sellers without order items may be legitimate, but
-- identifying them helps assess relationship coverage.
-- This query is read-only.

SELECT
    COUNT(*) AS unreferenced_seller_count
FROM olist_sellers_dataset s
LEFT JOIN olist_order_items_dataset oi
    ON TRIM(s.seller_id) = TRIM(oi.seller_id)
WHERE oi.seller_id IS NULL;

-- RESULT:
-- Previously verified: 0 sellers without order items.
-- All imported sellers are referenced by order items.

-- =====================================================
-- SELLER RELATIONSHIP CHECKS: SUMMARY
-- =====================================================
-- Checks completed:
-- 22. Order item seller_id completeness.
-- 23. Order items -> Sellers: unmatched references.
-- 24. Sellers -> Order items: unreferenced sellers.
--
-- Previously verified relationship results:
-- 3,095 distinct sellers referenced by order items.
-- 0 unmatched distinct seller IDs.
-- 0 sellers without order items.
--
-- Update Check 22 and Check 23 row-level results after
-- executing the queries above.
--
-- CONCLUSION:
-- The seller-to-order-item relationship has complete
-- distinct-ID coverage based on the previous checks.
-- No records were modified or deleted by these checks.
-- =====================================================


-- Check 25: Relationship Check – Product Category Name Translation
-- Purpose: Identify product categories in `olist_products` that do not have
-- a matching Portuguese category name in `product_category_name_translation`.
-- This check validates category-name coverage between the products table
-- and the product category translation table.

SELECT
    p.product_category_name,
    COUNT(*) AS product_count
FROM olist_products AS p
LEFT JOIN product_category_name_translation AS t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND TRIM(p.product_category_name) <> ''
  AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;

-- Result: 2 product categories have no matching English translation.
-- portateis_cozinha_e_preparadores_de_alimentos: 10 products
-- pc_gamer: 3 products
-- Total affected products: 13
-- Status: Translation coverage gaps identified; no data modified.

-- Check 26: Relationship Check – Product Category Name Translation
-- Purpose: Identify Portuguese product categories in
-- `product_category_name_translation` that are not referenced
-- by any product in `olist_products`.
-- This check identifies translation records that are not currently
-- used by the product table. These records are not necessarily errors.

SELECT
    t.product_category_name,
    t.product_category_name_english
FROM product_category_name_translation AS t
LEFT JOIN olist_products AS p
    ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NULL
ORDER BY t.product_category_name;

-- Result: 0 rows returned.
-- All translated product categories are referenced by at least one
-- product in `olist_products`.
-- Status: No unused translation records identified.

-- Check 27: Relationship Check – Product Category Name Translation
-- Purpose: Identify Portuguese product categories mapped to more than
-- one distinct English category name.
-- Expected relationship: One Portuguese category maps to one English name.

SELECT
    product_category_name,
    COUNT(DISTINCT product_category_name_english) AS english_name_count
FROM product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(DISTINCT product_category_name_english) > 1;

-- Result: 0 rows returned.
-- No Portuguese product category is mapped to multiple distinct
-- English category names.
-- Status: No conflicting category translations identified.

-- Result: 0 rows returned.
-- No Portuguese product category is mapped to multiple distinct
-- English category names.
-- Status: No conflicting category translations identified.

-- Check 28: Check customer postal-code prefix coverage in geolocation data

SELECT
    COUNT(DISTINCT c.customer_zip_code_prefix) AS distinct_customer_prefixes,

    COUNT(DISTINCT CASE
        WHEN g.geolocation_zip_code_prefix IS NOT NULL
        THEN c.customer_zip_code_prefix
    END) AS matched_customer_prefixes,

    COUNT(DISTINCT CASE
        WHEN g.geolocation_zip_code_prefix IS NULL
        THEN c.customer_zip_code_prefix
    END) AS unmatched_customer_prefixes

FROM olist_customers c
LEFT JOIN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM olist_geolocation_dataset
) g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;
    
    -- Result:
-- Distinct customer postal-code prefixes: 14,994
-- Matched prefixes: 14,837
-- Unmatched prefixes: 157
-- Match rate: 98.95%
-- Unmatched rate: 1.05%
--
-- Interpretation:
-- Most distinct customer postal-code prefixes have a matching
-- prefix in the geolocation dataset.
-- 157 customer prefixes have no matching geolocation prefix.
-- This check measures distinct prefix coverage, not customer-row coverage.
-- No data has been modified.
-- Status: Customer-geolocation prefix coverage assessed.

-- Check 29: List customer postal-code prefixes missing from geolocation data

SELECT
    c.customer_zip_code_prefix,
    COUNT(*) AS customer_records
FROM olist_customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM olist_geolocation_dataset g
    WHERE g.geolocation_zip_code_prefix =
          c.customer_zip_code_prefix
)
GROUP BY c.customer_zip_code_prefix
ORDER BY customer_records DESC,
         c.customer_zip_code_prefix;
         
         -- Result:
-- 157 distinct customer postal-code prefixes have no matching
-- prefix in olist_geolocation_dataset.
-- The query lists each unmatched prefix and its customer-record count.
--
-- Interpretation:
-- Missing geolocation matches may reflect incomplete geographic coverage.
-- An unmatched prefix does not, by itself, prove that customer data is invalid.
-- Postal-code prefixes must remain text to preserve leading zeros.
-- No data has been modified.
-- Status: Unmatched customer prefixes identified for investigation.

-- Check 30: Count customer records with unmatched geolocation prefixes

SELECT
    COUNT(*) AS total_customer_records,

    SUM(CASE
        WHEN g.geolocation_zip_code_prefix IS NULL
        THEN 1 ELSE 0
    END) AS customers_without_geolocation_match,

    SUM(CASE
        WHEN g.geolocation_zip_code_prefix IS NOT NULL
        THEN 1 ELSE 0
    END) AS customers_with_geolocation_match

FROM olist_customers c
LEFT JOIN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM olist_geolocation_dataset
) g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;
    
    -- Result:
-- Total customer records: 99,441
-- Customers with a geolocation match: 99,163
-- Customers without a geolocation match: 278
-- Match rate: 99.72%
-- Unmatched rate: 0.28%
--
-- Interpretation:
-- 278 customer records have postal-code prefixes that do not match
-- any prefix in olist_geolocation_dataset.
-- 99.72% of customer records have a matching geolocation prefix.
-- This measures prefix availability, not the accuracy of coordinates.
-- No data has been modified.
-- Status: Customer-level geolocation coverage assessed.

-- Check 31: Check seller postal-code prefix coverage in geolocation data

SELECT
    COUNT(DISTINCT s.seller_zip_code_prefix) AS distinct_seller_prefixes,

    COUNT(DISTINCT CASE
        WHEN g.geolocation_zip_code_prefix IS NOT NULL
        THEN s.seller_zip_code_prefix
    END) AS matched_seller_prefixes,

    COUNT(DISTINCT CASE
        WHEN g.geolocation_zip_code_prefix IS NULL
        THEN s.seller_zip_code_prefix
    END) AS unmatched_seller_prefixes

FROM olist_sellers_dataset s
LEFT JOIN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM olist_geolocation_dataset
) g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix;
    
    -- Result:
-- Distinct seller postal-code prefixes: 2,246
-- Matched prefixes: 2,239
-- Unmatched prefixes: 7
-- Match rate: 99.69%
-- Unmatched rate: 0.31%
--
-- Interpretation:
-- Most distinct seller postal-code prefixes have a matching
-- prefix in olist_geolocation_dataset.
-- Seven seller prefixes have no matching geolocation prefix.
-- This measures distinct prefix coverage, not individual seller coverage.
-- No data has been modified.
-- Status: Seller-geolocation prefix coverage assessed.


-- Check 32: List seller postal-code prefixes missing from geolocation data

SELECT
    s.seller_zip_code_prefix,
    COUNT(*) AS seller_records
FROM olist_sellers_dataset s
WHERE NOT EXISTS (
    SELECT 1
    FROM olist_geolocation_dataset g
    WHERE g.geolocation_zip_code_prefix =
          s.seller_zip_code_prefix
)
GROUP BY s.seller_zip_code_prefix
ORDER BY seller_records DESC,
         s.seller_zip_code_prefix;
         
         -- Result:
-- Seven unmatched seller postal-code prefixes identified:
-- 02285, 07412, 37708, 71551, 72580, 82040, 91901.
-- Each unmatched prefix is associated with one seller record.
--
-- Interpretation:
-- Seven seller records use prefixes absent from the geolocation dataset.
-- Missing geolocation matches do not automatically indicate invalid sellers.
-- Postal-code prefixes remain text to preserve leading zeros.
-- No data has been modified.
-- Status: Unmatched seller prefixes identified for investigation.

-- Check 33: Count seller records with unmatched geolocation prefixes

SELECT
    COUNT(*) AS total_seller_records,

    SUM(CASE
        WHEN g.geolocation_zip_code_prefix IS NULL
        THEN 1 ELSE 0
    END) AS sellers_without_geolocation_match,

    SUM(CASE
        WHEN g.geolocation_zip_code_prefix IS NOT NULL
        THEN 1 ELSE 0
    END) AS sellers_with_geolocation_match

FROM olist_sellers_dataset s
LEFT JOIN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM olist_geolocation_dataset
) g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix;
    
    -- Result:
-- Total seller records: 3,095
-- Sellers with a geolocation match: 3,088
-- Sellers without a geolocation match: 7
-- Match rate: 99.77%
-- Unmatched rate: 0.23%
--
-- Interpretation:
-- Seven seller records have postal-code prefixes that do not match
-- any prefix in olist_geolocation_dataset.
-- 99.77% of seller records have a matching geolocation prefix.
-- This measures prefix availability, not coordinate accuracy.
-- No data has been modified.
-- Status: Seller-level geolocation coverage assessed.

