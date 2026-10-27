
-- =====================================================
-- PHASE 3: BUSINESS ANALYSIS
-- SECTION 3.1: MONTHLY ORDER PERFORMANCE
-- Business question:
-- How do order volume and order status trend over time?
-- Grain: One row per order month
-- =====================================================

SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
        AS order_month,
    COUNT(*) AS total_orders,
    SUM(order_status = 'delivered') AS delivered_orders,
    SUM(order_status = 'canceled') AS canceled_orders,
    ROUND(
        100.0 * SUM(order_status = 'delivered')
        / COUNT(*),
        2
    ) AS delivered_order_percentage
FROM orders_model
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;



-- =====================================================
-- PHASE 3.1: MISSION 2
-- MONTH-OVER-MONTH ORDER GROWTH
-- Business question:
-- Is order volume increasing or decreasing over time?
-- Grain: One row per order month
-- =====================================================

WITH monthly_orders AS (
    SELECT
        DATE_FORMAT(
            order_purchase_timestamp, '%Y-%m'
        ) AS order_month,
        COUNT(*) AS total_orders
    FROM orders_model
    WHERE order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_FORMAT(
        order_purchase_timestamp, '%Y-%m'
    )
),

orders_with_previous_month AS (
    SELECT
        order_month,
        total_orders,
        LAG(total_orders) OVER (
            ORDER BY order_month
        ) AS previous_month_orders
    FROM monthly_orders
)

SELECT
    order_month,
    total_orders,
    previous_month_orders,

    total_orders - previous_month_orders
        AS order_change,

    ROUND(
        100.0 * (total_orders - previous_month_orders)
        / NULLIF(previous_month_orders, 0),
        2
    ) AS mom_growth_percentage

FROM orders_with_previous_month
ORDER BY order_month;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3: BUSINESS ANALYSIS
-- SECTION 3.1: REVENUE AND ORDER TRENDS
-- MISSION 3A: MONTHLY PAYMENT VALUE AND AOV
--
-- Business question:
-- How does recorded payment value per order change
-- over time?
--
-- Grain: One row per order month
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM payments_model
    GROUP BY order_id
),

monthly_performance AS (
    SELECT
        DATE_FORMAT(
            o.order_purchase_timestamp, '%Y-%m'
        ) AS order_month,

        COUNT(*) AS eligible_orders,

        SUM(p.order_payment_value)
            AS total_recorded_payment_value,

        AVG(p.order_payment_value)
            AS average_payment_value_per_order

    FROM orders_model AS o

    INNER JOIN payments_per_order AS p
        ON o.order_id = p.order_id

    WHERE o.order_purchase_timestamp IS NOT NULL
      AND o.order_status <> 'canceled'

    GROUP BY DATE_FORMAT(
        o.order_purchase_timestamp, '%Y-%m'
    )
)

SELECT
    order_month,
    eligible_orders,

    ROUND(
        total_recorded_payment_value, 2
    ) AS total_recorded_payment_value,

    ROUND(
        average_payment_value_per_order, 2
    ) AS average_payment_value_per_order

FROM monthly_performance
ORDER BY order_month;



-- =====================================================
-- MISSION 3B: PAYMENT COVERAGE VALIDATION
-- Business question:
-- How many eligible orders have payment records?
-- =====================================================

SELECT
    o.order_status,
    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN p.order_id IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS orders_with_payments,

    SUM(
        CASE
            WHEN p.order_id IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_without_payments

FROM orders_model AS o

LEFT JOIN (
    SELECT DISTINCT order_id
    FROM payments_model
) AS p
    ON o.order_id = p.order_id

WHERE o.order_purchase_timestamp IS NOT NULL

GROUP BY o.order_status
ORDER BY total_orders DESC;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3C
-- PAYMENT VS. ORDER-ITEM VALUE RECONCILIATION
--
-- Business question:
-- Do payment totals reconcile with product and freight
-- values recorded in order items?
--
-- Grain: One row per order
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM payments_model
    GROUP BY order_id
),

items_per_order AS (
    SELECT
        order_id,
        SUM(price) AS product_total,
        SUM(freight_value) AS freight_total,
        SUM(price + freight_value) AS item_and_freight_total
    FROM order_items_model
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.order_status,

    ROUND(p.payment_total, 2) AS payment_total,
    ROUND(i.product_total, 2) AS product_total,
    ROUND(i.freight_total, 2) AS freight_total,
    ROUND(i.item_and_freight_total, 2)
        AS item_and_freight_total,

    ROUND(
        p.payment_total - i.item_and_freight_total, 2
    ) AS payment_difference

FROM orders_model AS o

INNER JOIN payments_per_order AS p
    ON o.order_id = p.order_id

INNER JOIN items_per_order AS i
    ON o.order_id = i.order_id

WHERE o.order_purchase_timestamp IS NOT NULL

ORDER BY ABS(
    p.payment_total - i.item_and_freight_total
) DESC

LIMIT 50;




-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3D
-- OVERALL PAYMENT RECONCILIATION SUMMARY
--
-- Business question:
-- How consistently do payment totals reconcile with
-- product prices plus freight charges?
--
-- Grain: One row per order in the summary
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM payments_model
    GROUP BY order_id
),

items_per_order AS (
    SELECT
        order_id,
        SUM(price) AS product_total,
        SUM(freight_value) AS freight_total,
        SUM(price + freight_value) AS item_and_freight_total
    FROM order_items_model
    GROUP BY order_id
),

order_reconciliation AS (
    SELECT
        o.order_id,
        o.order_status,
        p.payment_total,
        i.item_and_freight_total,
        p.payment_total - i.item_and_freight_total
            AS payment_difference
    FROM orders_model AS o
    INNER JOIN payments_per_order AS p
        ON o.order_id = p.order_id
    INNER JOIN items_per_order AS i
        ON o.order_id = i.order_id
    WHERE o.order_purchase_timestamp IS NOT NULL
)

SELECT
    COUNT(*) AS total_orders_compared,

    SUM(
        CASE
            WHEN ABS(payment_difference) < 0.01 THEN 1
            ELSE 0
        END
    ) AS reconciled_orders,

    SUM(
        CASE
            WHEN ABS(payment_difference) >= 0.01 THEN 1
            ELSE 0
        END
    ) AS orders_with_differences,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN ABS(payment_difference) < 0.01 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS reconciliation_rate_pct,

    ROUND(SUM(payment_total), 2)
        AS total_recorded_payments,

    ROUND(SUM(item_and_freight_total), 2)
        AS total_items_plus_freight,

    ROUND(SUM(payment_difference), 2)
        AS net_payment_difference,

    ROUND(SUM(ABS(payment_difference)), 2)
        AS total_absolute_difference

FROM order_reconciliation;




-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3E
-- RECONCILIATION BY ORDER STATUS
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM payments_model
    GROUP BY order_id
),

items_per_order AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_total
    FROM order_items_model
    GROUP BY order_id
),

order_reconciliation AS (
    SELECT
        o.order_id,
        o.order_status,
        p.payment_total,
        i.item_total,
        p.payment_total - i.item_total AS payment_difference
    FROM orders_model AS o
    INNER JOIN payments_per_order AS p
        ON o.order_id = p.order_id
    INNER JOIN items_per_order AS i
        ON o.order_id = i.order_id
    WHERE o.order_purchase_timestamp IS NOT NULL
)

SELECT
    order_status,
    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN ABS(payment_difference) < 0.01 THEN 1
            ELSE 0
        END
    ) AS reconciled_orders,

    SUM(
        CASE
            WHEN ABS(payment_difference) >= 0.01 THEN 1
            ELSE 0
        END
    ) AS orders_with_differences,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN ABS(payment_difference) >= 0.01 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS discrepancy_rate_pct,

    ROUND(SUM(payment_difference), 2)
        AS net_difference,

    ROUND(SUM(ABS(payment_difference)), 2)
        AS total_absolute_difference

FROM order_reconciliation
GROUP BY order_status
ORDER BY total_absolute_difference DESC;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3F
-- DELIVERED-ORDER DISCREPANCY INVESTIGATION
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        COUNT(*) AS payment_records,
        GROUP_CONCAT(
            DISTINCT payment_type
            ORDER BY payment_type
            SEPARATOR ', '
        ) AS payment_types
    FROM payments_model
    GROUP BY order_id
),

items_per_order AS (
    SELECT
        order_id,
        SUM(price) AS product_total,
        SUM(freight_value) AS freight_total,
        SUM(price + freight_value) AS item_total,
        COUNT(*) AS item_count
    FROM order_items_model
    GROUP BY order_id
)

SELECT
    o.order_id,
    p.payment_types,
    p.payment_records,
    i.item_count,

    ROUND(p.payment_total, 2) AS payment_total,
    ROUND(i.product_total, 2) AS product_total,
    ROUND(i.freight_total, 2) AS freight_total,

    ROUND(
        p.payment_total - i.item_total, 2
    ) AS payment_difference

FROM orders_model AS o

INNER JOIN payments_per_order AS p
    ON o.order_id = p.order_id

INNER JOIN items_per_order AS i
    ON o.order_id = i.order_id

WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND ABS(p.payment_total - i.item_total) >= 0.01

ORDER BY ABS(p.payment_total - i.item_total) DESC

LIMIT 25;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3G
-- PAYMENT TYPE VS. RECONCILIATION
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        GROUP_CONCAT(
            DISTINCT payment_type
            ORDER BY payment_type
            SEPARATOR ', '
        ) AS payment_types
    FROM payments_model
    GROUP BY order_id
),

items_per_order AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_total
    FROM order_items_model
    GROUP BY order_id
),

delivered_orders AS (
    SELECT
        o.order_id,
        p.payment_types,
        p.payment_total,
        i.item_total,
        p.payment_total - i.item_total AS payment_difference
    FROM orders_model AS o
    INNER JOIN payments_per_order AS p
        ON o.order_id = p.order_id
    INNER JOIN items_per_order AS i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
)

SELECT
    payment_types,
    COUNT(*) AS total_orders,

    SUM(
        CASE
            WHEN ABS(payment_difference) >= 0.01 THEN 1
            ELSE 0
        END
    ) AS orders_with_differences,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN ABS(payment_difference) >= 0.01 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS discrepancy_rate_pct,

    ROUND(AVG(ABS(payment_difference)), 2)
        AS average_absolute_difference,

    ROUND(SUM(ABS(payment_difference)), 2)
        AS total_absolute_difference

FROM delivered_orders
GROUP BY payment_types
ORDER BY total_absolute_difference DESC;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3H
-- DISCREPANCY SEVERITY BY PAYMENT TYPE
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        GROUP_CONCAT(
            DISTINCT payment_type
            ORDER BY payment_type
            SEPARATOR ', '
        ) AS payment_types
    FROM payments_model
    GROUP BY order_id
),

items_per_order AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_total
    FROM order_items_model
    GROUP BY order_id
),

order_differences AS (
    SELECT
        p.payment_types,
        p.payment_total - i.item_total AS payment_difference
    FROM orders_model AS o
    INNER JOIN payments_per_order AS p
        ON o.order_id = p.order_id
    INNER JOIN items_per_order AS i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
)

SELECT
    payment_types,

    COUNT(*) AS discrepant_orders,

    SUM(
        CASE WHEN payment_difference > 0
             THEN 1 ELSE 0 END
    ) AS payment_exceeds_item_total,

    SUM(
        CASE WHEN payment_difference < 0
             THEN 1 ELSE 0 END
    ) AS payment_below_item_total,

    ROUND(AVG(ABS(payment_difference)), 2)
        AS avg_difference_per_discrepant_order,

    ROUND(MAX(ABS(payment_difference)), 2)
        AS largest_absolute_difference

FROM order_differences
WHERE ABS(payment_difference) >= 0.01
GROUP BY payment_types
ORDER BY avg_difference_per_discrepant_order DESC;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3I
-- DISCREPANCY MAGNITUDE ANALYSIS
-- =====================================================

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM payments_model
    GROUP BY order_id
),

items_per_order AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_total
    FROM order_items_model
    GROUP BY order_id
),

order_differences AS (
    SELECT
        p.payment_total - i.item_total AS payment_difference
    FROM orders_model AS o
    INNER JOIN payments_per_order AS p
        ON o.order_id = p.order_id
    INNER JOIN items_per_order AS i
        ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
)

SELECT
    CASE
        WHEN ABS(payment_difference) < 1
            THEN 'Under R$1'
        WHEN ABS(payment_difference) < 10
            THEN 'R$1 to under R$10'
        WHEN ABS(payment_difference) < 50
            THEN 'R$10 to under R$50'
        ELSE 'R$50 or more'
    END AS discrepancy_band,

    COUNT(*) AS discrepant_orders,

    ROUND(SUM(ABS(payment_difference)), 2)
        AS total_absolute_difference,

    ROUND(AVG(ABS(payment_difference)), 2)
        AS average_absolute_difference,

    ROUND(MAX(ABS(payment_difference)), 2)
        AS largest_absolute_difference

FROM order_differences
WHERE ABS(payment_difference) >= 0.01
GROUP BY discrepancy_band
ORDER BY
    CASE discrepancy_band
        WHEN 'Under R$1' THEN 1
        WHEN 'R$1 to under R$10' THEN 2
        WHEN 'R$10 to under R$50' THEN 3
        WHEN 'R$50 or more' THEN 4
    END;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3J
-- DELIVERY PERFORMANCE ANALYSIS
-- =====================================================

WITH delivery_metrics AS (
    SELECT
        order_id,
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date,

        DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) AS days_vs_estimate

    FROM orders_model

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    COUNT(*) AS delivered_orders_evaluated,

    SUM(
        CASE
            WHEN days_vs_estimate <= 0 THEN 1
            ELSE 0
        END
    ) AS delivered_on_or_before_estimate,

    SUM(
        CASE
            WHEN days_vs_estimate > 0 THEN 1
            ELSE 0
        END
    ) AS delivered_after_estimate,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN days_vs_estimate <= 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_delivery_pct,

    ROUND(AVG(days_vs_estimate), 2)
        AS average_days_vs_estimate,

    MAX(days_vs_estimate)
        AS maximum_days_late

FROM delivery_metrics;




-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3K
-- MONTHLY DELIVERY PERFORMANCE
-- =====================================================

WITH delivery_metrics AS (
    SELECT
        DATE_FORMAT(
            order_purchase_timestamp,
            '%Y-%m'
        ) AS purchase_month,

        DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) AS days_vs_estimate

    FROM orders_model

    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    purchase_month,
    COUNT(*) AS delivered_orders,

    SUM(
        CASE
            WHEN days_vs_estimate <= 0 THEN 1
            ELSE 0
        END
    ) AS on_time_or_early_orders,

    SUM(
        CASE
            WHEN days_vs_estimate > 0 THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN days_vs_estimate > 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate_pct,

    ROUND(AVG(days_vs_estimate), 2)
        AS average_days_vs_estimate

FROM delivery_metrics
GROUP BY purchase_month
ORDER BY purchase_month;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3L
-- LATE-DELIVERY SEVERITY BY PURCHASE MONTH
-- =====================================================

WITH late_deliveries AS (
    SELECT
        DATE_FORMAT(
            order_purchase_timestamp,
            '%Y-%m'
        ) AS purchase_month,

        DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) AS days_late

    FROM orders_model

    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    purchase_month,

    COUNT(*) AS late_orders,

    ROUND(AVG(days_late), 2)
        AS average_days_late,

    MAX(days_late)
        AS maximum_days_late,

    SUM(
        CASE
            WHEN days_late BETWEEN 1 AND 7 THEN 1
            ELSE 0
        END
    ) AS late_1_to_7_days,

    SUM(
        CASE
            WHEN days_late BETWEEN 8 AND 30 THEN 1
            ELSE 0
        END
    ) AS late_8_to_30_days,

    SUM(
        CASE
            WHEN days_late > 30 THEN 1
            ELSE 0
        END
    ) AS late_over_30_days

FROM late_deliveries

WHERE days_late > 0

GROUP BY purchase_month
ORDER BY purchase_month;



-- =====================================================
-- OLIST FLAGSHIP PROJECT
-- PHASE 3.1: MISSION 3M
-- ORDER SIZE VS. DELIVERY PERFORMANCE
-- =====================================================

WITH items_per_order AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items_model
    GROUP BY order_id
),

delivery_metrics AS (
    SELECT
        o.order_id,
        i.item_count,

        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate

    FROM orders_model AS o

    INNER JOIN items_per_order AS i
        ON o.order_id = i.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    CASE
        WHEN item_count = 1 THEN '1 item'
        WHEN item_count BETWEEN 2 AND 3 THEN '2-3 items'
        WHEN item_count BETWEEN 4 AND 5 THEN '4-5 items'
        ELSE '6+ items'
    END AS order_size,

    COUNT(*) AS delivered_orders,

    SUM(
        CASE
            WHEN days_vs_estimate > 0 THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN days_vs_estimate > 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate_pct,

    ROUND(AVG(days_vs_estimate), 2)
        AS average_days_vs_estimate

FROM delivery_metrics

GROUP BY
    CASE
        WHEN item_count = 1 THEN '1 item'
        WHEN item_count BETWEEN 2 AND 3 THEN '2-3 items'
        WHEN item_count BETWEEN 4 AND 5 THEN '4-5 items'
        ELSE '6+ items'
    END

ORDER BY
    CASE order_size
        WHEN '1 item' THEN 1
        WHEN '2-3 items' THEN 2
        WHEN '4-5 items' THEN 3
        ELSE 4
    END;


-- ============================================================
-- Mission 3N: Delivery Performance by Customer State
-- Objective: Identify geographic differences in delivery delays.
-- Method: Calculate late-delivery rate and average days
--          versus estimated delivery date for delivered orders.
-- Filter: Include only states with at least 100 evaluated orders.
-- Note: Results show associations, not the causes of delays.
-- ============================================================

SELECT
    c.customer_state,

    -- Total delivered orders with both dates available
    COUNT(*) AS delivered_orders,

    -- Count orders delivered after the estimated delivery date
    SUM(
        CASE
            WHEN DATEDIFF(
                o.order_delivered_customer_date,
                o.order_estimated_delivery_date
            ) > 0
            THEN 1 ELSE 0
        END
    ) AS late_orders,

    -- Percentage of evaluated deliveries that arrived late
    ROUND(
        100.0 * SUM(
            CASE
                WHEN DATEDIFF(
                    o.order_delivered_customer_date,
                    o.order_estimated_delivery_date
                ) > 0
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_delivery_rate_pct,

    -- Negative = early on average; positive = late on average
    ROUND(
        AVG(
            DATEDIFF(
                o.order_delivered_customer_date,
                o.order_estimated_delivery_date
            )
        ),
        2
    ) AS average_days_vs_estimate

FROM orders_model AS o

-- Connect each order to the state of its customer
INNER JOIN customers_model AS c
    ON o.customer_id = c.customer_id

-- Evaluate completed deliveries with both dates available
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

-- Aggregate delivery metrics by customer state
GROUP BY c.customer_state

-- Exclude states with fewer than 100 evaluated deliveries
HAVING COUNT(*) >= 100

-- Rank states from highest to lowest late-delivery rate
ORDER BY late_delivery_rate_pct DESC;

-- ============================================================
-- Mission 3O: Delivery Performance by Seller State
-- Objective: Examine whether late-delivery rates vary by
--            the state in which sellers are located.
-- Grain: One delivered order per seller state.
-- Method: Include orders associated with exactly one
--         distinct seller state.
-- Limitation: Multi-state-seller orders are excluded.
-- Note: Association does not establish causation.
-- ============================================================

WITH order_seller_states AS (
    -- Identify the distinct seller states associated with
    -- each order, avoiding duplicate item rows per state.
    SELECT DISTINCT
        oi.order_id,
        s.seller_state
    FROM order_items_model AS oi
    INNER JOIN sellers_model AS s
        ON oi.seller_id = s.seller_id
    WHERE s.seller_state IS NOT NULL
),

single_state_orders AS (
    -- Keep only orders associated with one distinct state.
    SELECT
        order_id,
        MIN(seller_state) AS seller_state
    FROM order_seller_states
    GROUP BY order_id
    HAVING COUNT(*) = 1
),

delivery_metrics AS (
    -- Calculate delivery performance for eligible orders.
    SELECT
        o.order_id,
        sso.seller_state,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate
    FROM orders_model AS o
    INNER JOIN single_state_orders AS sso
        ON o.order_id = sso.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_state,

    -- Number of evaluated delivered orders
    COUNT(*) AS delivered_orders,

    -- Number delivered after the estimated date
    SUM(
        CASE
            WHEN days_vs_estimate > 0 THEN 1
            ELSE 0
        END
    ) AS late_orders,

    -- Late-delivery rate as a percentage
    ROUND(
        100.0 * SUM(
            CASE
                WHEN days_vs_estimate > 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_delivery_rate_pct,

    -- Negative = early on average; positive = late on average
    ROUND(
        AVG(days_vs_estimate),
        2
    ) AS average_days_vs_estimate

FROM delivery_metrics

-- Exclude states with fewer than 100 evaluated deliveries
GROUP BY seller_state
HAVING COUNT(*) >= 100

-- Rank seller states by highest late-delivery rate
ORDER BY late_delivery_rate_pct DESC;


-- ============================================================
-- Mission 3P: Late-Delivery Severity by Seller State
-- Objective: Compare the severity of delays among late orders.
-- Grain: One eligible delivered order per seller state.
-- Method: Include only orders delivered after the estimate.
-- Measures: Late-order count, average delay, maximum delay,
--           and delay-duration bands.
-- Limitation: Multi-state-seller orders are excluded.
-- ============================================================

WITH order_seller_states AS (
    -- Identify distinct seller states associated with each order.
    SELECT DISTINCT
        oi.order_id,
        s.seller_state
    FROM order_items_model AS oi
    INNER JOIN sellers_model AS s
        ON oi.seller_id = s.seller_id
    WHERE s.seller_state IS NOT NULL
),

single_state_orders AS (
    -- Retain orders associated with exactly one seller state.
    SELECT
        order_id,
        MIN(seller_state) AS seller_state
    FROM order_seller_states
    GROUP BY order_id
    HAVING COUNT(*) = 1
),

late_deliveries AS (
    -- Calculate days late for completed deliveries only.
    SELECT
        o.order_id,
        sso.seller_state,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_late
    FROM orders_model AS o
    INNER JOIN single_state_orders AS sso
        ON o.order_id = sso.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND DATEDIFF(
          o.order_delivered_customer_date,
          o.order_estimated_delivery_date
      ) > 0
)

SELECT
    seller_state,

    -- Total number of late orders
    COUNT(*) AS late_orders,

    -- Average delay, considering late orders only
    ROUND(AVG(days_late), 2) AS average_days_late,

    -- Longest observed delay in days
    MAX(days_late) AS maximum_days_late,

    -- Late by 1 to 7 days
    SUM(
        CASE
            WHEN days_late BETWEEN 1 AND 7 THEN 1
            ELSE 0
        END
    ) AS late_1_to_7_days,

    -- Late by 8 to 30 days
    SUM(
        CASE
            WHEN days_late BETWEEN 8 AND 30 THEN 1
            ELSE 0
        END
    ) AS late_8_to_30_days,

    -- Late by more than 30 days
    SUM(
        CASE
            WHEN days_late > 30 THEN 1
            ELSE 0
        END
    ) AS late_over_30_days

FROM late_deliveries
GROUP BY seller_state

-- Require at least 100 late orders for this severity comparison.
-- This is a stricter sample threshold than Mission 3O.
HAVING COUNT(*) >= 100

ORDER BY average_days_late DESC;

-- ============================================================
-- Mission 3Q: Seller-State Analysis Coverage
-- Objective: Measure how many delivered orders are included
--            or excluded from the seller-state analysis.
-- Method: Separate orders with exactly one seller state from
--         orders with multiple states or no usable seller state.
-- Note: Coverage counts are based on eligible delivered orders
--       with both delivery dates available.
-- ============================================================

-- ============================================================
-- Mission 3Q: Seller-State Analysis Coverage
-- Objective: Measure the coverage of the seller-state analysis.
-- ============================================================

WITH order_seller_states AS (
    SELECT DISTINCT
        oi.order_id,
        s.seller_state
    FROM order_items_model AS oi
    INNER JOIN sellers_model AS s
        ON oi.seller_id = s.seller_id
    WHERE s.seller_state IS NOT NULL
),

seller_state_counts AS (
    SELECT
        order_id,
        COUNT(*) AS seller_state_count
    FROM order_seller_states
    GROUP BY order_id
),

eligible_delivered_orders AS (
    SELECT
        o.order_id,
        COALESCE(ssc.seller_state_count, 0) AS seller_state_count
    FROM orders_model AS o
    LEFT JOIN seller_state_counts AS ssc
        ON o.order_id = ssc.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    COUNT(*) AS total_eligible_delivered_orders,

    SUM(
        CASE
            WHEN seller_state_count = 1 THEN 1
            ELSE 0
        END
    ) AS single_seller_state_orders,

    SUM(
        CASE
            WHEN seller_state_count > 1 THEN 1
            ELSE 0
        END
    ) AS multiple_seller_state_orders,

    SUM(
        CASE
            WHEN seller_state_count = 0 THEN 1
            ELSE 0
        END
    ) AS no_usable_seller_state_orders,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN seller_state_count = 1 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS single_state_coverage_pct

FROM eligible_delivered_orders;

-- ============================================================
-- Mission 3R: Late-Order Volume by Seller State
-- Objective: Identify seller states contributing the most
--            late deliveries by absolute order count.
-- Method: Count each eligible delivered order once and
--         include orders associated with one seller state.
-- ============================================================

WITH order_seller_states AS (
    -- Identify distinct seller states associated with each order.
    SELECT DISTINCT
        oi.order_id,
        s.seller_state
    FROM order_items_model AS oi
    INNER JOIN sellers_model AS s
        ON oi.seller_id = s.seller_id
    WHERE s.seller_state IS NOT NULL
),

single_state_orders AS (
    -- Retain orders associated with exactly one seller state.
    SELECT
        order_id,
        MIN(seller_state) AS seller_state
    FROM order_seller_states
    GROUP BY order_id
    HAVING COUNT(*) = 1
),

delivery_metrics AS (
    -- Calculate delivery variance for eligible orders.
    SELECT
        o.order_id,
        sso.seller_state,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate
    FROM orders_model AS o
    INNER JOIN single_state_orders AS sso
        ON o.order_id = sso.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_state,

    -- Total eligible delivered orders
    COUNT(*) AS delivered_orders,

    -- Total late deliveries
    SUM(
        CASE
            WHEN days_vs_estimate > 0 THEN 1
            ELSE 0
        END
    ) AS late_orders,

    -- Late-delivery rate
    ROUND(
        100.0 * SUM(
            CASE
                WHEN days_vs_estimate > 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS late_delivery_rate_pct

FROM delivery_metrics
GROUP BY seller_state

-- Retain states with at least 100 evaluated deliveries
HAVING COUNT(*) >= 100

-- Rank by the greatest number of late orders
ORDER BY late_orders DESC;


-- ============================================================
-- Mission 3S: Combined Seller-State Delivery Risk
-- Objective: Compare late-delivery frequency, volume, and
--            severe-delay counts across seller states.
-- Severe delay: More than 30 days past the estimated date.
-- Scope: Delivered orders with both dates available and
--        exactly one distinct seller state.
-- ============================================================

WITH order_seller_states AS (
    -- Identify distinct seller states associated with each order.
    SELECT DISTINCT
        oi.order_id,
        s.seller_state
    FROM order_items_model AS oi
    INNER JOIN sellers_model AS s
        ON oi.seller_id = s.seller_id
    WHERE s.seller_state IS NOT NULL
),

single_state_orders AS (
    -- Keep orders with exactly one distinct seller state.
    SELECT
        order_id,
        MIN(seller_state) AS seller_state
    FROM order_seller_states
    GROUP BY order_id
    HAVING COUNT(*) = 1
),

delivery_metrics AS (
    -- Calculate the delivery difference for each eligible order.
    SELECT
        o.order_id,
        sso.seller_state,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate
    FROM orders_model AS o
    INNER JOIN single_state_orders AS sso
        ON o.order_id = sso.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    seller_state,

    COUNT(*) AS delivered_orders,

    SUM(
        CASE WHEN days_vs_estimate > 0 THEN 1 ELSE 0 END
    ) AS late_orders,

    ROUND(
        100.0 * SUM(
            CASE WHEN days_vs_estimate > 0 THEN 1 ELSE 0 END
        ) / COUNT(*),
        2
    ) AS late_delivery_rate_pct,

    SUM(
        CASE WHEN days_vs_estimate > 30 THEN 1 ELSE 0 END
    ) AS late_over_30_days,

    ROUND(
        100.0 * SUM(
            CASE WHEN days_vs_estimate > 30 THEN 1 ELSE 0 END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS severe_delay_rate_pct

FROM delivery_metrics
GROUP BY seller_state
HAVING COUNT(*) >= 100

-- Prioritize states by absolute late-order volume.
ORDER BY late_orders DESC;

-- ============================================================
-- Mission 3T: One-Time vs Repeat Customers
-- Objective: Measure the proportion of customers who place
--            multiple orders.
-- Customer grain: customer_unique_id.
-- Order grain: distinct order_id.
-- Note: This measures repeat purchasing in the available
--       dataset, not retention within a fixed time window.
-- ============================================================

WITH customer_order_counts AS (
    -- Count distinct orders for each unique customer.
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    WHERE c.customer_unique_id IS NOT NULL
    GROUP BY c.customer_unique_id
)

SELECT
    -- Number of unique customers represented in the analysis
    COUNT(*) AS total_unique_customers,

    -- Customers with exactly one recorded order
    SUM(
        CASE
            WHEN total_orders = 1 THEN 1
            ELSE 0
        END
    ) AS one_time_customers,

    -- Customers with two or more recorded orders
    SUM(
        CASE
            WHEN total_orders >= 2 THEN 1
            ELSE 0
        END
    ) AS repeat_customers,

    -- Percentage of customers who made repeat purchases
    ROUND(
        100.0 * SUM(
            CASE
                WHEN total_orders >= 2 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_rate_pct,

    -- Average number of recorded orders per unique customer
    ROUND(AVG(total_orders), 2) AS average_orders_per_customer

FROM customer_order_counts;

-- ============================================================
-- Mission 3U: Customer Order-Frequency Distribution
-- Objective: Understand how frequently customers purchase.
-- Customer grain: customer_unique_id.
-- Method: Group customers by their distinct order counts.
-- ============================================================

WITH customer_order_counts AS (
    -- Count distinct orders for each unique customer.
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    WHERE c.customer_unique_id IS NOT NULL
    GROUP BY c.customer_unique_id
)

SELECT
    -- Group customers by number of recorded orders.
    CASE
        WHEN total_orders = 1 THEN '1 order'
        WHEN total_orders = 2 THEN '2 orders'
        WHEN total_orders = 3 THEN '3 orders'
        ELSE '4+ orders'
    END AS order_frequency_group,

    COUNT(*) AS customer_count,

    -- Share of all customers in the analysis
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct

FROM customer_order_counts

GROUP BY
    CASE
        WHEN total_orders = 1 THEN '1 order'
        WHEN total_orders = 2 THEN '2 orders'
        WHEN total_orders = 3 THEN '3 orders'
        ELSE '4+ orders'
    END

ORDER BY
    CASE order_frequency_group
        WHEN '1 order' THEN 1
        WHEN '2 orders' THEN 2
        WHEN '3 orders' THEN 3
        ELSE 4
    END;
    
    
    -- ============================================================
-- Mission 3V: Recorded Payment Value by Customer Frequency
-- Objective: Compare payment contribution across customers
--            with different numbers of recorded orders.
-- Customer grain: customer_unique_id.
-- Order grain: distinct order_id.
-- Revenue proxy: Recorded payment_value summed per order.
-- Limitation: Payment value is not profit or customer lifetime
--             value; the dataset has a finite observation period.
-- ============================================================

WITH order_payment_totals AS (
    -- Aggregate payment records to one total per order.
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM payments_model
    GROUP BY order_id
),

customer_order_values AS (
    -- Associate each customer's distinct orders with payments.
    SELECT
        c.customer_unique_id,
        o.order_id,
        opt.order_payment_value
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    INNER JOIN order_payment_totals AS opt
        ON o.order_id = opt.order_id
    WHERE c.customer_unique_id IS NOT NULL
),

customer_totals AS (
    -- Calculate recorded order count and payment value per customer.
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(order_payment_value) AS total_payment_value
    FROM customer_order_values
    GROUP BY customer_unique_id
),

customer_groups AS (
    -- Group customers by their observed purchase frequency.
    SELECT
        customer_unique_id,
        total_orders,
        total_payment_value,
        CASE
            WHEN total_orders = 1 THEN '1 order'
            WHEN total_orders = 2 THEN '2 orders'
            WHEN total_orders = 3 THEN '3 orders'
            ELSE '4+ orders'
        END AS order_frequency_group
    FROM customer_totals
)

SELECT
    order_frequency_group,

    -- Number of customers in each frequency group
    COUNT(*) AS customer_count,

    -- Total recorded payment value for the group
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,

    -- Average recorded payment value per customer
    ROUND(AVG(total_payment_value), 2) AS avg_payment_value_per_customer,

    -- Average recorded order count per customer
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer

FROM customer_groups

GROUP BY order_frequency_group

ORDER BY
    CASE order_frequency_group
        WHEN '1 order' THEN 1
        WHEN '2 orders' THEN 2
        WHEN '3 orders' THEN 3
        ELSE 4
    END;
    
    
    -- ============================================================
-- Mission 3W: Average Payment Value per Order by Customer Group
-- Objective: Separate cumulative customer spending from
--            average recorded payment value per order.
-- Customer grain: customer_unique_id.
-- Order grain: distinct order_id.
-- Revenue proxy: Recorded payments aggregated per order.
-- ============================================================

WITH order_payment_totals AS (
    -- Create one payment total for each order.
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM payments_model
    GROUP BY order_id
),

customer_order_values AS (
    -- Keep only orders linked to customers and recorded payments.
    SELECT
        c.customer_unique_id,
        o.order_id,
        opt.order_payment_value
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    INNER JOIN order_payment_totals AS opt
        ON o.order_id = opt.order_id
    WHERE c.customer_unique_id IS NOT NULL
),

customer_totals AS (
    -- Summarize each customer's order count and total payments.
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(order_payment_value) AS total_payment_value
    FROM customer_order_values
    GROUP BY customer_unique_id
),

customer_groups AS (
    -- Assign customers to frequency groups.
    SELECT
        customer_unique_id,
        total_orders,
        total_payment_value,
        CASE
            WHEN total_orders = 1 THEN '1 order'
            WHEN total_orders = 2 THEN '2 orders'
            WHEN total_orders = 3 THEN '3 orders'
            ELSE '4+ orders'
        END AS order_frequency_group
    FROM customer_totals
)

SELECT
    order_frequency_group,
    COUNT(*) AS customer_count,
    SUM(total_orders) AS total_orders,
    ROUND(SUM(total_payment_value), 2) AS total_payment_value,

    -- Cumulative customer value divided by customers
    ROUND(AVG(total_payment_value), 2)
        AS avg_payment_value_per_customer,

    -- Total recorded payments divided by recorded orders
    ROUND(
        SUM(total_payment_value) / NULLIF(SUM(total_orders), 0),
        2
    ) AS avg_payment_value_per_order

FROM customer_groups

GROUP BY order_frequency_group

ORDER BY
    CASE order_frequency_group
        WHEN '1 order' THEN 1
        WHEN '2 orders' THEN 2
        WHEN '3 orders' THEN 3
        ELSE 4
    END;
    
    -- ============================================================
-- Mission 3X: One-Time vs. Repeat Customer Contribution
-- Objective: Measure the customer and payment-value shares
--            of one-time and repeat purchasers.
-- Customer grain: customer_unique_id.
-- Order grain: distinct order_id.
-- Payment values are aggregated per order before joining.
-- Limitation: Recorded payment value is not profit or CLV.
-- ============================================================


WITH order_payment_totals AS (
    -- One payment total per order.
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM payments_model
    GROUP BY order_id
),

customer_order_values AS (
    -- Link each customer's orders to their recorded payments.
    SELECT
        c.customer_unique_id,
        o.order_id,
        opt.order_payment_value
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    INNER JOIN order_payment_totals AS opt
        ON o.order_id = opt.order_id
    WHERE c.customer_unique_id IS NOT NULL
),

customer_totals AS (
    -- Calculate order count and total payments per customer.
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(order_payment_value) AS total_payment_value
    FROM customer_order_values
    GROUP BY customer_unique_id
),

customer_segments AS (
    -- Separate one-time customers from repeat customers.
    SELECT
        customer_unique_id,
        total_orders,
        total_payment_value,
        CASE
            WHEN total_orders = 1 THEN 'One-time'
            ELSE 'Repeat'
        END AS customer_segment
    FROM customer_totals
),

segment_summary AS (
    SELECT
        customer_segment,
        COUNT(*) AS customer_count,
        SUM(total_payment_value) AS total_payment_value,
        AVG(total_payment_value) AS avg_payment_per_customer
    FROM customer_segments
    GROUP BY customer_segment
)

SELECT
    customer_segment,
    customer_count,

    ROUND(
        100.0 * customer_count / SUM(customer_count) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(total_payment_value, 2) AS total_payment_value,

    ROUND(
        100.0 * total_payment_value
        / SUM(total_payment_value) OVER (),
        2
    ) AS payment_value_share_pct,

    ROUND(avg_payment_per_customer, 2)
        AS avg_payment_per_customer

FROM segment_summary

ORDER BY
    CASE customer_segment
        WHEN 'One-time' THEN 1
        ELSE 2
    END;
    
    
    -- ============================================================
-- Mission 3Y: Customer Payment-Coverage Validation
-- Objective: Identify customers with recorded orders but
--            no matching payment records.
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    WHERE c.customer_unique_id IS NOT NULL
),

customer_payment_coverage AS (
    SELECT
        co.customer_unique_id,
        co.order_id,
        CASE
            WHEN p.order_id IS NULL THEN 0
            ELSE 1
        END AS has_payment_record
    FROM customer_orders AS co
    LEFT JOIN (
        SELECT DISTINCT order_id
        FROM payments_model
    ) AS p
        ON co.order_id = p.order_id
)

SELECT
    COUNT(DISTINCT customer_unique_id) AS customers_with_orders,

    COUNT(DISTINCT CASE
        WHEN has_payment_record = 1
        THEN customer_unique_id
    END) AS customers_with_payment_records,

    COUNT(DISTINCT CASE
        WHEN has_payment_record = 0
        THEN customer_unique_id
    END) AS customers_with_unpaid_or_missing_payment_records,

    SUM(CASE
        WHEN has_payment_record = 0 THEN 1
        ELSE 0
    END) AS orders_without_payment_records

FROM customer_payment_coverage;


-- ============================================================
-- Mission 3Z: Inspect Orders Without Payment Records
-- Objective: Examine the order status and available dates
--            for orders that lack a matching payment record.
-- Method: LEFT JOIN orders to distinct payment order IDs.
-- ============================================================

SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date

FROM orders_model AS o

INNER JOIN customers_model AS c
    ON o.customer_id = c.customer_id

LEFT JOIN (
    SELECT DISTINCT order_id
    FROM payments_model
) AS p
    ON o.order_id = p.order_id

WHERE p.order_id IS NULL

ORDER BY o.order_purchase_timestamp;


-- ============================================================
-- Mission 3AA: Raw-to-Model Payment Exception Check
-- Objective: Determine whether the missing payment record
--            exists in the raw payment table.
-- Method: Compare raw and modeled payment records for the
--         identified order.
-- ============================================================

SELECT
    'raw_payments' AS source_table,
    COUNT(*) AS matching_payment_rows,
    ROUND(COALESCE(SUM(payment_value), 0), 2)
        AS total_payment_value
FROM olist_order_payments_dataset
WHERE order_id = 'bfbd0f9bdef84302105ad712db648a6c'

UNION ALL

SELECT
    'payments_model' AS source_table,
    COUNT(*) AS matching_payment_rows,
    ROUND(COALESCE(SUM(payment_value), 0), 2)
        AS total_payment_value
FROM payments_model
WHERE order_id = 'bfbd0f9bdef84302105ad712db648a6c';


-- ============================================================
-- Mission 3AB: Review Score Quality Check
-- Objective: Validate review-score completeness, score range,
--            and review-table grain before business analysis.
-- ============================================================

SELECT
    COUNT(*) AS total_review_records,

    COUNT(DISTINCT order_id) AS distinct_orders_reviewed,

    COUNT(DISTINCT review_id) AS distinct_review_ids,

    SUM(
        CASE WHEN review_score IS NULL THEN 1 ELSE 0 END
    ) AS null_review_scores,

    SUM(
        CASE
            WHEN review_score IS NOT NULL
             AND (review_score < 1 OR review_score > 5)
            THEN 1
            ELSE 0
        END
    ) AS scores_outside_1_to_5,

    SUM(
        CASE WHEN review_score = 1 THEN 1 ELSE 0 END
    ) AS score_1_records,

    SUM(
        CASE WHEN review_score = 2 THEN 1 ELSE 0 END
    ) AS score_2_records,

    SUM(
        CASE WHEN review_score = 3 THEN 1 ELSE 0 END
    ) AS score_3_records,

    SUM(
        CASE WHEN review_score = 4 THEN 1 ELSE 0 END
    ) AS score_4_records,

    SUM(
        CASE WHEN review_score = 5 THEN 1 ELSE 0 END
    ) AS score_5_records

FROM reviews_model;

-- ============================================================
-- Mission 3AB: Review Multiplicity by Order
-- Objective: Determine how many orders have multiple reviews.
-- Purpose: Prevent review records from unintentionally
--          multiplying rows in the delivery-performance join.
-- ============================================================

WITH reviews_per_order AS (
    SELECT
        order_id,
        COUNT(*) AS review_count
    FROM reviews_model
    GROUP BY order_id
)

SELECT
    CASE
        WHEN review_count = 1 THEN '1 review'
        WHEN review_count = 2 THEN '2 reviews'
        ELSE '3+ reviews'
    END AS review_frequency_group,

    COUNT(*) AS order_count

FROM reviews_per_order

GROUP BY
    CASE
        WHEN review_count = 1 THEN '1 review'
        WHEN review_count = 2 THEN '2 reviews'
        ELSE '3+ reviews'
    END

ORDER BY
    CASE review_frequency_group
        WHEN '1 review' THEN 1
        WHEN '2 reviews' THEN 2
        ELSE 3
    END;
    
    
    -- ============================================================
-- Mission 3AB: Review Scores vs. Delivery Performance
-- Objective: Compare customer review scores for late versus
--            on-time/early deliveries.
-- Grain: One row per order.
-- Review method: Average scores when an order has multiple
--                review records.
-- Delivery method: Compare actual customer delivery date with
--                  the estimated delivery date.
-- Limitation: Association does not establish causation.
-- ============================================================

WITH order_review_scores AS (
    -- Reduce reviews to one record per order.
    SELECT
        order_id,
        COUNT(*) AS review_record_count,
        AVG(review_score) AS avg_review_score,
        SUM(
            CASE
                WHEN review_score IN (1, 2) THEN 1
                ELSE 0
            END
        ) AS low_score_review_count,
        COUNT(review_score) AS valid_score_count
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
    GROUP BY order_id
),

order_delivery_reviews AS (
    -- Join one delivery record to one review summary per order.
    SELECT
        o.order_id,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate,
        r.review_record_count,
        r.avg_review_score,
        r.low_score_review_count,
        r.valid_score_count,
        CASE
            WHEN o.order_delivered_customer_date
                 > o.order_estimated_delivery_date
            THEN 'Late'
            ELSE 'On time or early'
        END AS delivery_group
    FROM orders_model AS o
    INNER JOIN order_review_scores AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    delivery_group,

    COUNT(*) AS order_count,

    ROUND(AVG(avg_review_score), 2)
        AS avg_review_score_per_order,

    SUM(review_record_count) AS review_records,

    SUM(low_score_review_count) AS low_score_reviews,

    ROUND(
        100.0 * SUM(low_score_review_count)
        / NULLIF(SUM(valid_score_count), 0),
        2
    ) AS low_score_review_pct,

    ROUND(AVG(days_vs_estimate), 2)
        AS avg_days_vs_estimate

FROM order_delivery_reviews

GROUP BY delivery_group

ORDER BY
    CASE delivery_group
        WHEN 'On time or early' THEN 1
        ELSE 2
    END;
    
-- ============================================================
-- Mission 3AC: Delivery Delay Severity vs. Review Scores
-- Objective: Compare customer review scores across delay bands.
-- Grain: One row per delivered order with a valid review.
-- Review method: Average review score per order.
-- Low-score order: Average order review score <= 2.
-- Delay bands: On time/early, 1-7, 8-30, and >30 days late.
-- Limitation: Observational association, not causation.
-- ============================================================

WITH order_review_scores AS (
    -- Aggregate multiple review records to one score per order.
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
    GROUP BY order_id
),

order_delivery_experience AS (
    -- Calculate delivery variance and attach one review score.
    SELECT
        o.order_id,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate,
        r.avg_review_score
    FROM orders_model AS o
    INNER JOIN order_review_scores AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),

delay_groups AS (
    -- Assign each order to a delivery-timing band.
    SELECT
        order_id,
        days_vs_estimate,
        avg_review_score,
        CASE
            WHEN days_vs_estimate <= 0
                THEN 'On time or early'
            WHEN days_vs_estimate BETWEEN 1 AND 7
                THEN '1-7 days late'
            WHEN days_vs_estimate BETWEEN 8 AND 30
                THEN '8-30 days late'
            ELSE '>30 days late'
        END AS delay_band
    FROM order_delivery_experience
)

SELECT
    delay_band,
    COUNT(*) AS order_count,

    ROUND(AVG(avg_review_score), 2)
        AS avg_review_score_per_order,

    SUM(
        CASE
            WHEN avg_review_score <= 2 THEN 1
            ELSE 0
        END
    ) AS low_score_orders,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN avg_review_score <= 2 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS low_score_order_pct,

    ROUND(AVG(days_vs_estimate), 2)
        AS avg_days_vs_estimate

FROM delay_groups

GROUP BY delay_band

ORDER BY
    CASE delay_band
        WHEN 'On time or early' THEN 1
        WHEN '1-7 days late' THEN 2
        WHEN '8-30 days late' THEN 3
        ELSE 4
    END;
    
    
    -- ============================================================
-- Mission 3AD: Validate Same-Day Delivery Classification
-- Objective: Identify orders counted as late by timestamp
--            comparison but having zero calendar days of delay.
-- ============================================================

SELECT
    COUNT(*) AS same_day_later_orders,
    ROUND(
        AVG(r.avg_review_score),
        2
    ) AS avg_review_score_per_order,
    SUM(
        CASE
            WHEN r.avg_review_score <= 2 THEN 1
            ELSE 0
        END
    ) AS low_score_orders
FROM orders_model AS o
INNER JOIN (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
    GROUP BY order_id
) AS r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_delivered_customer_date
      > o.order_estimated_delivery_date
  AND DATEDIFF(
      o.order_delivered_customer_date,
      o.order_estimated_delivery_date
  ) = 0;
  
  
  
  -- ============================================================
-- Mission 3AE: Review-Score Distribution by Delay Band
-- Objective: Compare order-level review-score distributions
--            across delivery-delay categories.
-- Grain: One row per delivered order with a valid review.
-- Review method: Average review score per order.
-- Delay method: Calendar-day difference using DATEDIFF().
-- Limitation: Findings are associations, not causal effects.
-- ============================================================

WITH order_review_scores AS (
    -- Aggregate multiple review records to one score per order.
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
    GROUP BY order_id
),

order_delivery_experience AS (
    -- Join each order's review summary to its delivery dates.
    SELECT
        o.order_id,

        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate,

        r.avg_review_score

    FROM orders_model AS o

    INNER JOIN order_review_scores AS r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),

classified_orders AS (
    -- Create consistent calendar-day delivery groups.
    SELECT
        order_id,
        avg_review_score,

        CASE
            WHEN days_vs_estimate <= 0
                THEN 'On time or early'
            WHEN days_vs_estimate BETWEEN 1 AND 7
                THEN '1-7 days late'
            WHEN days_vs_estimate BETWEEN 8 AND 30
                THEN '8-30 days late'
            ELSE '>30 days late'
        END AS delay_band

    FROM order_delivery_experience
)

SELECT
    delay_band,
    COUNT(*) AS order_count,

    SUM(
        CASE WHEN avg_review_score <= 1.5
             THEN 1 ELSE 0 END
    ) AS low_score_1_orders,

    SUM(
        CASE WHEN avg_review_score > 1.5
                   AND avg_review_score <= 2.5
             THEN 1 ELSE 0 END
    ) AS low_score_2_orders,

    SUM(
        CASE WHEN avg_review_score > 2.5
                   AND avg_review_score <= 3.5
             THEN 1 ELSE 0 END
    ) AS mid_score_orders,

    SUM(
        CASE WHEN avg_review_score > 3.5
                   AND avg_review_score <= 4.5
             THEN 1 ELSE 0 END
    ) AS high_score_orders,

    SUM(
        CASE WHEN avg_review_score > 4.5
             THEN 1 ELSE 0 END
    ) AS top_score_orders,

    ROUND(AVG(avg_review_score), 2)
        AS avg_review_score_per_order

FROM classified_orders

GROUP BY delay_band

ORDER BY
    CASE delay_band
        WHEN 'On time or early' THEN 1
        WHEN '1-7 days late' THEN 2
        WHEN '8-30 days late' THEN 3
        ELSE 4
    END;
    
    
    /*
BUSINESS FINDINGS — MISSION 3AE

1. Orders delivered on time or early averaged 4.29/5.
   62.20% had an order-level average score above 4.5.

2. Orders delayed 1-7 calendar days averaged 2.72/5.
   41.31% had an order-level average score of 1.5 or lower.

3. Orders delayed 8-30 days averaged 1.65/5.
   70.64% had an order-level average score of 1.5 or lower.

4. Orders delayed more than 30 days averaged 2.06/5.
   This group contained 329 orders, so interpret its pattern
   cautiously.

BUSINESS IMPLICATION:
Delivery delays are strongly associated with less favorable
order-level review scores. Further investigation should examine
potential contributing factors before recommending interventions.

LIMITATIONS:
- Multiple review records per order are averaged.
- Score bands classify average order scores, not individual
  review records.
- The analysis is observational and does not establish causation.
*/




-- ============================================================
-- Mission 3AF: Written Review Comments vs. Delivery Delays
-- Objective: Compare written-review presence across delay bands.
-- Grain: One row per delivered order.
-- Method: Aggregate review records to the order level first.
-- Limitation: Comment presence does not prove the comment
--            concerns delivery or that delay caused the comment.
-- ============================================================

WITH order_review_comments AS (
    SELECT
        order_id,
        MAX(
            CASE
                WHEN NULLIF(
                    TRIM(review_comment_message), ''
                ) IS NOT NULL
                  OR NULLIF(
                    TRIM(review_comment_title), ''
                ) IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS has_written_comment
    FROM reviews_model
    GROUP BY order_id
),

order_delivery AS (
    SELECT
        o.order_id,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate,
        COALESCE(r.has_written_comment, 0) AS has_written_comment
    FROM orders_model AS o
    LEFT JOIN order_review_comments AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),

classified_orders AS (
    SELECT
        order_id,
        has_written_comment,
        CASE
            WHEN days_vs_estimate <= 0
                THEN 'On time or early'
            WHEN days_vs_estimate BETWEEN 1 AND 7
                THEN '1-7 days late'
            WHEN days_vs_estimate BETWEEN 8 AND 30
                THEN '8-30 days late'
            ELSE '>30 days late'
        END AS delay_band
    FROM order_delivery
)

SELECT
    delay_band,
    COUNT(*) AS total_orders,
    SUM(has_written_comment) AS orders_with_written_comments,
    SUM(1 - has_written_comment) AS orders_without_written_comments,
    ROUND(
        100.0 * SUM(has_written_comment) / COUNT(*),
        2
    ) AS written_comment_rate_pct
FROM classified_orders
GROUP BY delay_band
ORDER BY
    CASE delay_band
        WHEN 'On time or early' THEN 1
        WHEN '1-7 days late' THEN 2
        WHEN '8-30 days late' THEN 3
        ELSE 4
    END;


/*
BUSINESS FINDINGS — MISSION 3AF

1. Written-comment rates increased across the delivery-delay
   groups, from 40.93% for on-time/early orders to 64.44%
   for orders delayed 8-30 days.

2. Orders delayed more than 30 days had a 65.51% comment rate.
   This group contained 345 orders.

3. The comment rate was 24.58 percentage points higher for
   orders delayed more than 30 days than for on-time/early orders.

BUSINESS IMPLICATION:
Written review comments may provide a useful source for
investigating customer experiences associated with delivery delays.

LIMITATIONS:
- Comment presence does not indicate positive or negative sentiment.
- Comments may discuss issues unrelated to delivery.
- The analysis establishes association, not causation.
*/


SELECT
    VERSION() AS mysql_version,
    REGEXP_SUBSTR(
        'delivery was very late',
        '[[:alpha:]]+',
        1,
        1
    ) AS regex_test;
    
    
    
-- ============================================================
-- Mission 3AG: Common Words in Written Review Comments
-- Objective: Identify frequently occurring words in reviews.
-- Grain: One extracted word occurrence.
-- Method: Tokenize comment text, normalize to lowercase,
--         remove common stop words, and count occurrences.
-- Limitation: Word frequency alone does not establish sentiment.
-- ============================================================

WITH RECURSIVE
comment_text AS (
    SELECT
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS full_text
    FROM reviews_model
    WHERE NULLIF(
        TRIM(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ),
        ''
    ) IS NOT NULL
),

tokens AS (
    SELECT
        REGEXP_SUBSTR(full_text, '[[:alpha:]]+', 1, 1) AS word,
        1 AS word_position,
        full_text
    FROM comment_text
    WHERE REGEXP_SUBSTR(full_text, '[[:alpha:]]+', 1, 1) IS NOT NULL

    UNION ALL

    SELECT
        REGEXP_SUBSTR(
            full_text,
            '[[:alpha:]]+',
            1,
            word_position + 1
        ) AS word,
        word_position + 1,
        full_text
    FROM tokens
    WHERE REGEXP_SUBSTR(
        full_text,
        '[[:alpha:]]+',
        1,
        word_position + 1
    ) IS NOT NULL
),

stop_words AS (
    SELECT 'the' AS word UNION ALL
    SELECT 'and' UNION ALL
    SELECT 'for' UNION ALL
    SELECT 'was' UNION ALL
    SELECT 'is' UNION ALL
    SELECT 'it' UNION ALL
    SELECT 'to' UNION ALL
    SELECT 'a' UNION ALL
    SELECT 'of' UNION ALL
    SELECT 'in' UNION ALL
    SELECT 'this' UNION ALL
    SELECT 'that' UNION ALL
    SELECT 'with' UNION ALL
    SELECT 'my' UNION ALL
    SELECT 'on' UNION ALL
    SELECT 'not' UNION ALL
    SELECT 'very' UNION ALL
    SELECT 'i' UNION ALL
    SELECT 'you' UNION ALL
    SELECT 'me' UNION ALL
    SELECT 'but' UNION ALL
    SELECT 'as' UNION ALL
    SELECT 'at' UNION ALL
    SELECT 'be' UNION ALL
    SELECT 'are' UNION ALL
    SELECT 'were' UNION ALL
    SELECT 'have' UNION ALL
    SELECT 'had' UNION ALL
    SELECT 'has' UNION ALL
    SELECT 'so' UNION ALL
    SELECT 'from' UNION ALL
    SELECT 'they' UNION ALL
    SELECT 'them' UNION ALL
    SELECT 'our' UNION ALL
    SELECT 'we' UNION ALL
    SELECT 'he' UNION ALL
    SELECT 'she' UNION ALL
    SELECT 'their' UNION ALL
    SELECT 'was' UNION ALL
    SELECT 'were' UNION ALL
    SELECT 'do' UNION ALL
    SELECT 'did' UNION ALL
    SELECT 'or' UNION ALL
    SELECT 'if' UNION ALL
    SELECT 'all' UNION ALL
    SELECT 'an' UNION ALL
    SELECT 'by' UNION ALL
    SELECT 'no' UNION ALL
    SELECT 'out' UNION ALL
    SELECT 'just' UNION ALL
    SELECT 'very'
)

SELECT
    t.word,
    COUNT(*) AS word_occurrences
FROM tokens AS t
LEFT JOIN stop_words AS s
    ON t.word = s.word
WHERE s.word IS NULL
  AND CHAR_LENGTH(t.word) >= 3
GROUP BY t.word
ORDER BY word_occurrences DESC, t.word
LIMIT 30;



-- ============================================================
-- Mission 3AH: Delivery-Related Language by Review Score
-- Objective: Compare delivery-term mentions in low- and
--            high-score written reviews.
-- Grain: One review record.
-- Method: Search title and message for predefined Portuguese
--         delivery-related terms.
-- Limitation: Keyword matches are not full sentiment analysis.
-- ============================================================

SELECT
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score >= 4 THEN 'High score (4-5)'
        ELSE 'Middle score (3)'
    END AS review_group,

    COUNT(*) AS review_records,

    SUM(
        CASE
            WHEN LOWER(
                CONCAT(
                    COALESCE(review_comment_title, ''),
                    ' ',
                    COALESCE(review_comment_message, '')
                )
            ) REGEXP
            'entrega|entregue|entregador|atras|atraso|prazo|chegou|transport|frete'
            THEN 1
            ELSE 0
        END
    ) AS reviews_mentioning_delivery,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN LOWER(
                    CONCAT(
                        COALESCE(review_comment_title, ''),
                        ' ',
                        COALESCE(review_comment_message, '')
                    )
                ) REGEXP
                'entrega|entregue|entregador|atras|atraso|prazo|chegou|transport|frete'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS delivery_term_mention_rate_pct

FROM reviews_model
WHERE review_score BETWEEN 1 AND 5
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  )
GROUP BY
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score >= 4 THEN 'High score (4-5)'
        ELSE 'Middle score (3)'
    END
ORDER BY
    CASE review_group
        WHEN 'Low score (1-2)' THEN 1
        WHEN 'Middle score (3)' THEN 2
        ELSE 3
    END;

/*
BUSINESS FINDINGS — MISSION 3AH

1. Delivery-related terms appeared in 40.28% of written
   reviews with scores 1-2.

2. The mention rate was 36.96% for score-3 reviews and
   44.17% for score-4-5 reviews.

3. The high-score group exceeded the low-score group by
   3.89 percentage points.

BUSINESS IMPLICATION:
Delivery is a recurring topic in customer feedback, but its
presence alone does not identify dissatisfaction. Further
analysis should distinguish positive and negative contexts.

LIMITATIONS:
- Keyword matching is not sentiment analysis.
- The predefined Portuguese keyword list may omit relevant
  expressions or include irrelevant matches.
- Analysis includes only reviews with written comments.
- Results show association, not causation.
*/


-- ============================================================
-- Mission 3AI: Inspect Delivery-Related Review Examples
-- Objective: Validate keyword-based interpretations against
--            actual customer comments.
-- Grain: One review record.
-- Method: Sample comments containing delivery-related terms.
-- Limitation: A small sample is exploratory, not representative.
-- ============================================================

SELECT
    review_score,
    review_comment_title,
    LEFT(review_comment_message, 300) AS comment_excerpt
FROM reviews_model
WHERE review_score BETWEEN 1 AND 5
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  )
  AND LOWER(
      CONCAT(
          COALESCE(review_comment_title, ''),
          ' ',
          COALESCE(review_comment_message, '')
      )
  ) REGEXP
      'entrega|entregue|entregador|atras|atraso|prazo|chegou|transport|frete'
ORDER BY
    CASE
        WHEN review_score <= 2 THEN 1
        WHEN review_score >= 4 THEN 2
        ELSE 3
    END,
    review_score,
    review_id
LIMIT 30;



-- ============================================================
-- Mission 3AJ: Customer Issue Themes by Review Score
-- Objective: Compare common issue themes across rating groups.
-- Grain: One review record.
-- Method: Transparent keyword-based classification.
-- Important: Categories can overlap within a review.
-- Limitation: Keyword matches are not validated sentiment labels.
-- ============================================================

WITH review_text AS (
    SELECT
        review_id,
        order_id,
        review_score,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        *,
        CASE
            WHEN review_score <= 2 THEN 'Low score (1-2)'
            WHEN review_score = 3 THEN 'Middle score (3)'
            ELSE 'High score (4-5)'
        END AS review_group,

        comment_text REGEXP
            'entrega|entregue|atras|atraso|prazo|chegou|transport|frete|correios'
            AS delivery_mentioned,

        comment_text REGEXP
            'defeito|quebrad|danificad|qualidade|funciona|funcionou|estragad|nao liga|não liga'
            AS product_issue_mentioned,

        comment_text REGEXP
            'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|faltou|falta.*produto|item.*faltando|pedido incompleto'
            AS missing_item_mentioned,

        comment_text REGEXP
            'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
            AS service_issue_mentioned

    FROM review_text
)

SELECT
    review_group,
    COUNT(*) AS written_review_records,

    SUM(delivery_mentioned) AS delivery_mentions,
    ROUND(
        100.0 * SUM(delivery_mentioned) / COUNT(*),
        2
    ) AS delivery_mention_pct,

    SUM(product_issue_mentioned) AS product_issue_mentions,
    ROUND(
        100.0 * SUM(product_issue_mentioned) / COUNT(*),
        2
    ) AS product_issue_pct,

    SUM(missing_item_mentioned) AS missing_item_mentions,
    ROUND(
        100.0 * SUM(missing_item_mentioned) / COUNT(*),
        2
    ) AS missing_item_pct,

    SUM(service_issue_mentioned) AS service_issue_mentions,
    ROUND(
        100.0 * SUM(service_issue_mentioned) / COUNT(*),
        2
    ) AS service_issue_pct

FROM classified_reviews
GROUP BY review_group
ORDER BY
    CASE review_group
        WHEN 'Low score (1-2)' THEN 1
        WHEN 'Middle score (3)' THEN 2
        ELSE 3
    END;



/*
BUSINESS FINDINGS — MISSION 3AJ

1. Missing-item/nonreceipt keywords appeared in 25.16% of
   low-score written reviews, compared with 0.82% of high-score
   written reviews.

2. Service/communication keywords appeared in 8.50% of low-score
   reviews and 3.05% of high-score reviews.

3. Delivery-related terms appeared frequently in both groups:
   41.20% of low-score reviews and 44.41% of high-score reviews.

4. Product-issue keyword rates were relatively similar:
   10.26% for low scores and 9.27% for high scores.

BUSINESS IMPLICATION:
Investigate missing-item/nonreceipt experiences and customer
support responsiveness as potential improvement opportunities.

LIMITATIONS:
- Categories can overlap within one review.
- Keyword matching is not verified issue classification.
- Delivery mentions may be positive, neutral, or negative.
- Results are associations and do not establish causation.
*/



-- ============================================================
-- Mission 3AK: Validate Missing-Item Keyword Matches
-- Objective: Inspect actual comments behind the strongest
--            observed rating-group difference.
-- Grain: One review record.
-- Method: Review a sample of low-score keyword matches.
-- Limitation: A sample cannot establish classification accuracy.
-- ============================================================

SELECT
    review_score,
    review_id,
    order_id,
    review_comment_title,
    LEFT(review_comment_message, 400) AS comment_excerpt
FROM reviews_model
WHERE review_score BETWEEN 1 AND 2
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  )
  AND LOWER(
      CONCAT(
          COALESCE(review_comment_title, ''),
          ' ',
          COALESCE(review_comment_message, '')
      )
  ) REGEXP
      'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|faltou|falta.*produto|item.*faltando|pedido incompleto'
ORDER BY review_score, review_id
LIMIT 25;


-- ============================================================
-- Mission 3AL: Nonreceipt vs. Incomplete-Order Complaints
-- Objective: Separate distinct fulfillment problem signals.
-- Grain: One written review record.
-- Method: Portuguese keyword rules; categories can overlap.
-- Limitation: These are candidate classifications, not
--             independently verified complaint labels.
-- ============================================================

WITH review_text AS (
    SELECT
        review_id,
        order_id,
        review_score,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        *,
        CASE
            WHEN review_score <= 2 THEN 'Low score (1-2)'
            WHEN review_score = 3 THEN 'Middle score (3)'
            ELSE 'High score (4-5)'
        END AS review_group,

        -- Category 1: Customer reports not receiving a product/order.
        comment_text REGEXP
          'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
          AS nonreceipt_flag,

        -- Category 2: Customer reports a missing item or incomplete order.
        -- Expanded using phrases observed during manual review validation.
        comment_text REGEXP
          'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
          AS incomplete_order_flag,

        -- Category 3: Customer-service or communication problems.
        comment_text REGEXP
          'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
          AS service_issue_flag

    FROM review_text
)

SELECT
    review_group,
    COUNT(*) AS written_review_records,

    SUM(nonreceipt_flag) AS nonreceipt_matches,
    ROUND(
        100.0 * SUM(nonreceipt_flag) / COUNT(*),
        2
    ) AS nonreceipt_pct,

    SUM(incomplete_order_flag) AS incomplete_order_matches,
    ROUND(
        100.0 * SUM(incomplete_order_flag) / COUNT(*),
        2
    ) AS incomplete_order_pct,

    SUM(service_issue_flag) AS service_issue_matches,
    ROUND(
        100.0 * SUM(service_issue_flag) / COUNT(*),
        2
    ) AS service_issue_pct

FROM classified_reviews
GROUP BY review_group
ORDER BY
    CASE review_group
        WHEN 'Low score (1-2)' THEN 1
        WHEN 'Middle score (3)' THEN 2
        ELSE 3
    END;




/*
BUSINESS FINDINGS — MISSION 3AL

1. Nonreceipt keywords appeared in 23.39% of low-score written
   reviews, compared with 0.50% of high-score written reviews.

2. Incomplete-order keywords appeared in 3.09% of low-score
   reviews and 0.35% of high-score reviews.

3. Service/communication keywords appeared in 8.50% of
   low-score reviews versus 3.05% of high-score reviews.

BUSINESS IMPLICATION:
Prioritize investigation of nonreceipt experiences, order
completeness, and customer-support responsiveness.

LIMITATIONS:
- Keyword-based categories are not independently verified labels.
- Categories may overlap within a review.
- The analysis includes written reviews only.
- Association does not establish causation.
*/



-- ============================================================
-- Mission 3AM: Validate Nonreceipt Matches in High-Score Reviews
-- Objective: Inspect potential false positives in the
--            nonreceipt keyword classification.
-- Grain: One review record.
-- Method: Sample high-score reviews matched by current rules.
-- Limitation: A small sample does not estimate full accuracy.
-- ============================================================

SELECT
    review_score,
    review_id,
    order_id,
    review_comment_title,
    LEFT(review_comment_message, 400) AS comment_excerpt
FROM reviews_model
WHERE review_score BETWEEN 4 AND 5
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  )
  AND LOWER(
      CONCAT(
          COALESCE(review_comment_title, ''),
          ' ',
          COALESCE(review_comment_message, '')
      )
  ) REGEXP
      'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
ORDER BY review_score, review_id
LIMIT 20;



-- ============================================================
-- Mission 3AN: Validate Incomplete-Order Keyword Matches
-- Objective: Inspect potential true and false positives.
-- Grain: One written review record.
-- Method: Review records matching existing incomplete-order
--         keywords, across all review scores.
-- Limitation: A sample is diagnostic, not an accuracy estimate.
-- ============================================================

SELECT
    review_score,
    review_id,
    order_id,
    review_comment_title,
    LEFT(review_comment_message, 400) AS comment_excerpt
FROM reviews_model
WHERE review_score BETWEEN 1 AND 5
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  )
  AND LOWER(
      CONCAT(
          COALESCE(review_comment_title, ''),
          ' ',
          COALESCE(review_comment_message, '')
      )
  ) REGEXP
      'faltou|falta de produto|item faltando|pedido incompleto|apenas um|so veio um|só veio um|veio apenas um|na nota consta'
ORDER BY review_score, review_id
LIMIT 25;




/*
BUSINESS FINDINGS — MISSION 3AN

1. Manual inspection of 25 matched reviews found many clear
   examples of incomplete orders, including missing units,
   missing products, and partial quantities.

2. Some reviews also described adjacent problems, such as
   incorrect products, invoice discrepancies, and poor
   seller communication.

3. Incomplete-order and service flags can overlap.

4. The sample supports the face validity of the keyword rule,
   but does not establish classification accuracy across the
   full review dataset.

NEXT ACTION:
Expand Portuguese phrase coverage and validate a new sample.
*/



-- ============================================================
-- Mission 3AO: Validate Newly Detected Incomplete-Order Matches
-- Objective: Check whether expanded keywords find genuine
--            incomplete-order complaints.
-- Grain: One written review record.
-- Method: Updated rule EXCEPT original rule.
-- Limitation: The sample is diagnostic, not a full accuracy test.
-- ============================================================

WITH review_text AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        *,
        comment_text REGEXP
          'faltou|falta de produto|item faltando|pedido incompleto|apenas um|so veio um|só veio um|veio apenas um|na nota consta'
          AS original_flag,

        comment_text REGEXP
          'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
          AS updated_flag

    FROM review_text
)

SELECT
    review_score,
    review_id,
    order_id,
    review_comment_title,
    LEFT(review_comment_message, 400) AS comment_excerpt
FROM classified_reviews
WHERE updated_flag = 1
  AND original_flag = 0
ORDER BY review_score, review_id
LIMIT 25;


/*
BUSINESS FINDINGS — MISSION 3AO

1. Manual inspection of the 25 newly detected matches showed
   strong qualitative evidence of incomplete-order complaints,
   including missing units, partial kits, and missing components.

2. Several comments also described poor customer-service
   responses, supporting the use of independent, overlapping
   issue flags.

3. Some fulfillment complaints involved delayed arrival or
   subsequent delivery, so nonreceipt should not automatically
   be interpreted as permanent loss of the item.

4. The sample supports retaining the expanded incomplete-order
   keyword rule, but does not establish overall precision,
   recall, or classification accuracy.

LIMITATIONS:
The sample was drawn from reviews matched by the expanded rule.
Independent random sampling and manual labeling would be needed
to estimate classification performance.
*/




/* ============================================================
   MISSION 3AP — INCOMPLETE-ORDER AND SERVICE-ISSUE OVERLAP
   Objective: Measure overlap between incomplete-order and
              service-issue keyword flags by rating group.
   Grain: One review record.
   Limitation: Keyword-based flags; categories can overlap.
   ============================================================ */

WITH review_text AS (
    SELECT
        review_id,
        review_score,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        review_id,
        review_score,

        CASE
            WHEN comment_text REGEXP
                'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
            THEN 1 ELSE 0
        END AS incomplete_order_flag,

        CASE
            WHEN comment_text REGEXP
                'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
            THEN 1 ELSE 0
        END AS service_issue_flag

    FROM review_text
),

grouped_results AS (
    SELECT
        CASE
            WHEN review_score <= 2 THEN 'Low score (1-2)'
            WHEN review_score = 3 THEN 'Middle score (3)'
            ELSE 'High score (4-5)'
        END AS rating_group,

        CASE
            WHEN review_score <= 2 THEN 1
            WHEN review_score = 3 THEN 2
            ELSE 3
        END AS sort_order,

        SUM(incomplete_order_flag) AS incomplete_order_matches,

        SUM(
            CASE
                WHEN incomplete_order_flag = 1
                 AND service_issue_flag = 1
                THEN 1 ELSE 0
            END
        ) AS both_issue_matches

    FROM classified_reviews
    GROUP BY
        CASE
            WHEN review_score <= 2 THEN 'Low score (1-2)'
            WHEN review_score = 3 THEN 'Middle score (3)'
            ELSE 'High score (4-5)'
        END,
        CASE
            WHEN review_score <= 2 THEN 1
            WHEN review_score = 3 THEN 2
            ELSE 3
        END
)

SELECT
    rating_group,
    incomplete_order_matches,
    both_issue_matches,
    ROUND(
        100.0 * both_issue_matches
        / NULLIF(incomplete_order_matches, 0),
        2
    ) AS service_overlap_pct_of_incomplete
FROM grouped_results
ORDER BY sort_order;



/* ============================================================
   MISSION 3AQ — CONSOLIDATED REVIEW-ISSUE SUMMARY
   Objective:
   Compare selected issue keyword flags across rating groups.

   Grain: One written review record.
   Important: Issue categories may overlap.
   Limitation: Keyword matches are not verified classifications.
   ============================================================ */

WITH review_text AS (
    SELECT
        review_id,
        review_score,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        review_id,
        review_score,

        CASE
            WHEN comment_text REGEXP
                'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
            THEN 1 ELSE 0
        END AS nonreceipt_flag,

        CASE
            WHEN comment_text REGEXP
                'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
            THEN 1 ELSE 0
        END AS incomplete_order_flag,

        CASE
            WHEN comment_text REGEXP
                'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
            THEN 1 ELSE 0
        END AS service_issue_flag,

        CASE
            WHEN comment_text REGEXP
                'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
            THEN 1 ELSE 0
        END AS product_issue_flag

    FROM review_text
),

grouped_results AS (
    SELECT
        CASE
            WHEN review_score <= 2 THEN 'Low score (1-2)'
            WHEN review_score = 3 THEN 'Middle score (3)'
            ELSE 'High score (4-5)'
        END AS rating_group,

        CASE
            WHEN review_score <= 2 THEN 1
            WHEN review_score = 3 THEN 2
            ELSE 3
        END AS sort_order,

        COUNT(*) AS written_review_records,
        SUM(nonreceipt_flag) AS nonreceipt_matches,
        SUM(incomplete_order_flag) AS incomplete_order_matches,
        SUM(service_issue_flag) AS service_issue_matches,
        SUM(product_issue_flag) AS product_issue_matches

    FROM classified_reviews
    GROUP BY
        CASE
            WHEN review_score <= 2 THEN 'Low score (1-2)'
            WHEN review_score = 3 THEN 'Middle score (3)'
            ELSE 'High score (4-5)'
        END,
        CASE
            WHEN review_score <= 2 THEN 1
            WHEN review_score = 3 THEN 2
            ELSE 3
        END
)

SELECT
    rating_group,
    written_review_records,
    nonreceipt_matches,
    ROUND(100.0 * nonreceipt_matches
        / written_review_records, 2) AS nonreceipt_pct,
    incomplete_order_matches,
    ROUND(100.0 * incomplete_order_matches
        / written_review_records, 2) AS incomplete_order_pct,
    service_issue_matches,
    ROUND(100.0 * service_issue_matches
        / written_review_records, 2) AS service_issue_pct,
    product_issue_matches,
    ROUND(100.0 * product_issue_matches
        / written_review_records, 2) AS product_issue_pct
FROM grouped_results
ORDER BY sort_order;



/* ============================================================
   MISSION 3AR — PRODUCT-ISSUE KEYWORD VALIDATION
   Objective: Inspect 25 low-rated comments matched by the
              exploratory product-issue keyword rule.
   Grain: One review record.
   Limitation: A selected sample checks face validity only.
   ============================================================ */

SELECT
    review_score,
    review_id,
    order_id,
    review_comment_title,
    review_comment_message
FROM reviews_model
WHERE review_score BETWEEN 1 AND 2
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  )
  AND LOWER(
      CONCAT(
          COALESCE(review_comment_title, ''),
          ' ',
          COALESCE(review_comment_message, '')
      )
  ) REGEXP
      'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
ORDER BY review_score, review_id
LIMIT 25;




/* ============================================================
   MISSION 3AS — OVERALL REVIEW-ISSUE PREVALENCE
   Objective:
   Quantify individual issue flags and reviews matching at
   least one of the four issue categories.

   Grain: One review record.
   Limitation: Keyword-based classifications; categories overlap.
   ============================================================ */

WITH review_text AS (
    SELECT
        review_id,
        review_score,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        review_id,

        comment_text REGEXP
          'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
          AS nonreceipt_flag,

        comment_text REGEXP
          'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
          AS incomplete_order_flag,

        comment_text REGEXP
          'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
          AS service_issue_flag,

        comment_text REGEXP
          'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
          AS product_issue_flag

    FROM review_text
),

overall_counts AS (
    SELECT
        COUNT(*) AS written_review_records,
        SUM(nonreceipt_flag) AS nonreceipt_matches,
        SUM(incomplete_order_flag) AS incomplete_order_matches,
        SUM(service_issue_flag) AS service_issue_matches,
        SUM(product_issue_flag) AS product_issue_matches,

        SUM(
            nonreceipt_flag
            OR incomplete_order_flag
            OR service_issue_flag
            OR product_issue_flag
        ) AS reviews_with_any_issue_flag

    FROM classified_reviews
)

SELECT
    written_review_records,
    nonreceipt_matches,
    incomplete_order_matches,
    service_issue_matches,
    product_issue_matches,
    reviews_with_any_issue_flag,

    ROUND(
        100.0 * reviews_with_any_issue_flag
        / written_review_records, 2
    ) AS pct_reviews_with_any_issue_flag

FROM overall_counts;






/* ============================================================
   MISSION 3AT — REVIEW-ISSUE COMBINATION ANALYSIS
   Objective: Identify the most common combinations of issue
              keyword flags in written reviews.
   Grain: One review record.
   Limitation: Keyword flags are not verified classifications.
   ============================================================ */

WITH review_text AS (
    SELECT
        review_id,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        review_id,

        comment_text REGEXP
          'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
          AS nonreceipt_flag,

        comment_text REGEXP
          'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
          AS incomplete_order_flag,

        comment_text REGEXP
          'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
          AS service_issue_flag,

        comment_text REGEXP
          'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
          AS product_issue_flag

    FROM review_text
),

combination_groups AS (
    SELECT
        CASE
            WHEN nonreceipt_flag = 1
             AND incomplete_order_flag = 1
             AND service_issue_flag = 1
             AND product_issue_flag = 1
                THEN 'All four categories'

            WHEN nonreceipt_flag = 1
             AND incomplete_order_flag = 1
             AND service_issue_flag = 1
                THEN 'Nonreceipt + incomplete + service'

            WHEN nonreceipt_flag = 1
             AND incomplete_order_flag = 1
             AND product_issue_flag = 1
                THEN 'Nonreceipt + incomplete + product'

            WHEN nonreceipt_flag = 1
             AND service_issue_flag = 1
             AND product_issue_flag = 1
                THEN 'Nonreceipt + service + product'

            WHEN incomplete_order_flag = 1
             AND service_issue_flag = 1
             AND product_issue_flag = 1
                THEN 'Incomplete + service + product'

            WHEN nonreceipt_flag = 1
             AND incomplete_order_flag = 1
                THEN 'Nonreceipt + incomplete'

            WHEN nonreceipt_flag = 1
             AND service_issue_flag = 1
                THEN 'Nonreceipt + service'

            WHEN nonreceipt_flag = 1
             AND product_issue_flag = 1
                THEN 'Nonreceipt + product'

            WHEN incomplete_order_flag = 1
             AND service_issue_flag = 1
                THEN 'Incomplete + service'

            WHEN incomplete_order_flag = 1
             AND product_issue_flag = 1
                THEN 'Incomplete + product'

            WHEN service_issue_flag = 1
             AND product_issue_flag = 1
                THEN 'Service + product'

            WHEN nonreceipt_flag = 1
                THEN 'Nonreceipt only'

            WHEN incomplete_order_flag = 1
                THEN 'Incomplete order only'

            WHEN service_issue_flag = 1
                THEN 'Service issue only'

            WHEN product_issue_flag = 1
                THEN 'Product issue only'

            ELSE 'No issue flags'
        END AS issue_combination

    FROM classified_reviews
)

SELECT
    issue_combination,
    COUNT(*) AS review_records,
    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM classified_reviews),
        2
    ) AS pct_all_written_reviews
FROM combination_groups
GROUP BY issue_combination
ORDER BY review_records DESC;



/* ============================================================
   MISSION 3AU — ISSUE-COMBINATION COVERAGE CHECK
   Objective: Reconcile the combination analysis with the
              overall issue-flag totals.
   Grain: One written review record.
   ============================================================ */

WITH review_text AS (
    SELECT
        review_id,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        review_id,

        comment_text REGEXP
          'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
          AS nonreceipt_flag,

        comment_text REGEXP
          'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
          AS incomplete_order_flag,

        comment_text REGEXP
          'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
          AS service_issue_flag,

        comment_text REGEXP
          'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
          AS product_issue_flag

    FROM review_text
)

SELECT
    COUNT(*) AS written_review_records,

    SUM(
        nonreceipt_flag
        OR incomplete_order_flag
        OR service_issue_flag
        OR product_issue_flag
    ) AS reviews_with_any_issue_flag,

    SUM(
        NOT (
            nonreceipt_flag
            OR incomplete_order_flag
            OR service_issue_flag
            OR product_issue_flag
        )
    ) AS reviews_with_no_issue_flags,

    SUM(
        nonreceipt_flag
        AND incomplete_order_flag
        AND service_issue_flag
        AND product_issue_flag
    ) AS reviews_matching_all_four_categories

FROM classified_reviews;



/* ============================================================
   MISSION 3AV — REVIEW ISSUE-FLAG COUNT DISTRIBUTION
   Objective: Count how many issue categories each written
              review matches.
   Grain: One written review record.
   Limitation: Flags are keyword-based, not verified diagnoses.
   ============================================================ */

WITH review_text AS (
    SELECT
        review_id,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        review_id,

        comment_text REGEXP
          'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
          AS nonreceipt_flag,

        comment_text REGEXP
          'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
          AS incomplete_order_flag,

        comment_text REGEXP
          'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
          AS service_issue_flag,

        comment_text REGEXP
          'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
          AS product_issue_flag

    FROM review_text
),

flag_counts AS (
    SELECT
        (
            nonreceipt_flag
            + incomplete_order_flag
            + service_issue_flag
            + product_issue_flag
        ) AS number_of_issue_flags
    FROM classified_reviews
)

SELECT
    number_of_issue_flags,
    COUNT(*) AS review_records,
    ROUND(
        100.0 * COUNT(*) /
        (SELECT COUNT(*) FROM flag_counts),
        2
    ) AS pct_written_reviews
FROM flag_counts
GROUP BY number_of_issue_flags
ORDER BY number_of_issue_flags;



/* ============================================================
   MISSION 3AW — ISSUE-FLAG COUNT BY RATING GROUP
   Objective: Compare the number of keyword issue flags across
              low-, middle-, and high-rated written reviews.
   Grain: One written review record.
   Limitation: Flags are keyword-based; association is not causation.
   ============================================================ */

WITH review_text AS (
    SELECT
        review_id,
        review_score,
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
      AND (
          NULLIF(TRIM(review_comment_title), '') IS NOT NULL
          OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
      )
),

classified_reviews AS (
    SELECT
        review_id,
        review_score,

        (
            comment_text REGEXP
            'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
        ) AS nonreceipt_flag,

        (
            comment_text REGEXP
            'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
        ) AS incomplete_order_flag,

        (
            comment_text REGEXP
            'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
        ) AS service_issue_flag,

        (
            comment_text REGEXP
            'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
        ) AS product_issue_flag

    FROM review_text
),

flag_counts AS (
    SELECT
        review_id,
        review_score,
        (
            nonreceipt_flag
            + incomplete_order_flag
            + service_issue_flag
            + product_issue_flag
        ) AS number_of_issue_flags
    FROM classified_reviews
)

SELECT
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        ELSE 'High score (4-5)'
    END AS rating_group,

    COUNT(*) AS written_review_records,

    ROUND(AVG(number_of_issue_flags), 3)
        AS avg_issue_flags_per_review,

    SUM(number_of_issue_flags = 0)
        AS reviews_with_zero_flags,

    SUM(number_of_issue_flags >= 2)
        AS reviews_with_multiple_flags,

    ROUND(
        100.0 * SUM(number_of_issue_flags >= 2) / COUNT(*),
        2
    ) AS pct_with_multiple_flags

FROM flag_counts
GROUP BY
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        ELSE 'High score (4-5)'
    END
ORDER BY
    CASE
        WHEN rating_group = 'Low score (1-2)' THEN 1
        WHEN rating_group = 'Middle score (3)' THEN 2
        ELSE 3
    END;



/* ============================================================
   MISSION 3AX — REVIEW ANALYSIS POPULATION CHECK
   Objective: Validate the written-review population and
              reconcile rating-group counts.
   Grain: One review record.
   ============================================================ */

SELECT
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        WHEN review_score BETWEEN 4 AND 5 THEN 'High score (4-5)'
        ELSE 'Invalid or missing score'
    END AS rating_group,

    COUNT(*) AS review_records,

    SUM(
        CASE
            WHEN NULLIF(TRIM(review_comment_title), '') IS NOT NULL
              OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS written_review_records,

    SUM(
        CASE
            WHEN NULLIF(TRIM(review_comment_title), '') IS NULL
             AND NULLIF(TRIM(review_comment_message), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS reviews_without_written_comments

FROM reviews_model
GROUP BY
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        WHEN review_score BETWEEN 4 AND 5 THEN 'High score (4-5)'
        ELSE 'Invalid or missing score'
    END
ORDER BY
    CASE
        WHEN rating_group = 'Low score (1-2)' THEN 1
        WHEN rating_group = 'Middle score (3)' THEN 2
        WHEN rating_group = 'High score (4-5)' THEN 3
        ELSE 4
    END;



/* ============================================================
   MISSION 3AY — REVIEW FINDINGS SUMMARY BY RATING GROUP
   Objective: Summarize rating and written-comment patterns.
   Grain: One review record.
   Limitation: Issue flags are keyword-based.
   ============================================================ */

WITH review_base AS (
    SELECT
        review_id,
        review_score,
        (
            NULLIF(TRIM(review_comment_title), '') IS NOT NULL
            OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
        ) AS has_written_comment,

        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text

    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
),

classified_reviews AS (
    SELECT
        review_id,
        review_score,
        has_written_comment,

        (
            has_written_comment
            AND (
                comment_text REGEXP
                'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
                OR comment_text REGEXP
                'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
                OR comment_text REGEXP
                'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
                OR comment_text REGEXP
                'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
            )
        ) AS any_issue_flag

    FROM review_base
)

SELECT
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        ELSE 'High score (4-5)'
    END AS rating_group,

    COUNT(*) AS total_review_records,

    ROUND(AVG(review_score), 2) AS avg_review_score,

    SUM(has_written_comment) AS written_review_records,

    ROUND(
        100.0 * SUM(has_written_comment) / COUNT(*), 2
    ) AS written_comment_pct,

    SUM(any_issue_flag) AS written_reviews_with_any_issue_flag,

    ROUND(
        100.0 * SUM(any_issue_flag)
        / NULLIF(SUM(has_written_comment), 0), 2
    ) AS pct_written_reviews_with_issue_flag

FROM classified_reviews
GROUP BY
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        ELSE 'High score (4-5)'
    END
ORDER BY
    CASE
        WHEN rating_group = 'Low score (1-2)' THEN 1
        WHEN rating_group = 'Middle score (3)' THEN 2
        ELSE 3
    END;
    
    
/* ============================================================
   MISSION 3AZ — FINAL REVIEW ANALYSIS SUMMARY

   Objective:
   Consolidate the key findings from the Olist review-analysis
   branch for reporting and portfolio documentation.

   Analysis areas:
   1. Review data quality and rating distribution
   2. Delivery performance and customer ratings
   3. Written-comment patterns
   4. Keyword-based issue signals
   5. Issue overlap and rating-group comparisons

   IMPORTANT LIMITATIONS:
   - Review records are not always equivalent to unique orders.
   - Delivery-delay results depend on the chosen delay definition.
   - Keyword-based issue flags are exploratory, not verified labels.
   - Issue categories may overlap.
   - Associations do not establish causation.
   ============================================================ */


/* ------------------------------------------------------------
   1. REVIEW DATA QUALITY
   ------------------------------------------------------------

   Review records analyzed:              99,224
   Distinct orders reviewed:             98,673
   Distinct review IDs:                  98,410
   Null or invalid review scores:         None observed
   Orders with multiple review records:   547

   Score distribution:
   Score 1: 11,424
   Score 2:  3,151
   Score 3:  8,179
   Score 4: 19,142
   Score 5: 57,328

   Score 5 represented approximately 57.78% of all records.
   Scores 1–2 represented approximately 14.69%.
   */


/* ------------------------------------------------------------
   2. DELIVERY PERFORMANCE AND RATINGS
   ------------------------------------------------------------

   Using timestamp-based delivery classification:
   - On time or early: 88,163 orders; average score 4.29.
   - Late:              7,661 orders; average score 2.57.

   Using calendar-day delay bands:
   - On time or early: 89,443 orders; average score 4.29.
   - 1–7 days late:     3,600 orders; average score 2.72.
   - 8–30 days late:    2,452 orders; average score 1.65.
   - More than 30 days:   329 orders; average score 2.06.

   Definition note:
   1,280 orders were delivered after the estimated timestamp
   but on the same calendar date. Therefore, timestamp-based
   and calendar-day classifications produce different counts.

   The 8–30-day-late group had the lowest average rating.
   The more-than-30-day group had a higher average rating,
   but contained only 329 orders. The relationship is therefore
   not perfectly monotonic.
   */


/* ------------------------------------------------------------
   3. WRITTEN-COMMENT COVERAGE
   ------------------------------------------------------------

   Total review records:                 99,224
   Records with written comments:        42,697
   Records without written comments:     56,527

   Written-comment coverage: approximately 43.03%.

   Written feedback is a subset of all review records.
   Comment-based findings must not be generalized automatically
   to reviews without written comments.
   */


/* ------------------------------------------------------------
   4. KEYWORD-BASED ISSUE SIGNALS
   ------------------------------------------------------------

   Written review records:               42,697
   Nonreceipt keyword matches:            2,965
   Incomplete-order matches:                678
   Service-issue matches:                 1,905
   Product-issue matches:                 1,102
   Reviews with at least one issue flag:  6,203

   Reviews with at least one flag: approximately 14.53%.

   Issue flags by rating group:

   Rating group   Written reviews   Any issue flag   Flag rate
   Low (1–2)          10,994            4,333         39.41%
   Middle (3)          3,644              608         16.68%
   High (4–5)         28,059            1,262          4.50%

   The low-rating group's issue-flag rate was approximately
   8.8 times the high-rating group's rate.

   Important:
   These rates use written reviews as the denominator.
   Keyword matches are exploratory signals, not verified
   issue classifications.
   */


/* ------------------------------------------------------------
   5. ISSUE OVERLAP
   ------------------------------------------------------------

   Number of issue flags per written review:

   Zero flags: 36,494 (85.47%)
   One flag:    5,771 (13.52%)
   Two flags:     417 (0.98%)
   Three flags:    15 (0.04%)
   Four flags:      0 (0.00%)

   Reviews with multiple flags: 432 (approximately 1.01%).

   Issue categories overlap; their individual counts and
   percentages must not be added to calculate unique reviews.

   Manual samples supported the face validity of the nonreceipt
   and incomplete-order keyword rules. Product-issue keyword
   validation was reviewed, including a comparison of the
   original and refined rules. The original rule is retained
   for exploratory analysis because the refined rule excluded
   genuine product complaints. False positives remain possible.
   */


/* ------------------------------------------------------------
   6. BUSINESS IMPLICATIONS
   ------------------------------------------------------------

   A. Prioritize low-rated written reviews for investigation.

   B. Investigate fulfillment and nonreceipt signals, which
      appeared substantially more often in low-rated reviews.

   C. Review delivery-delay performance using a clearly
      documented timestamp or calendar-day definition.

   D. Keep issue categories separate because one comment may
      describe more than one problem.

   E. Validate keyword classifications manually before using
      them as operational performance measures.

   F. Treat all observed relationships as associations rather
      than evidence of causation.
   */


/* ------------------------------------------------------------
   7. REVIEW ANALYSIS STATUS
   ------------------------------------------------------------

   Review data quality checks:            Completed
   Rating distribution:                   Completed
   Delivery and rating analysis:           Completed
   Written-comment analysis:              Completed
   Keyword-based issue analysis:           Completed
   Nonreceipt sample validation:           Completed
   Incomplete-order sample validation:     Completed
   Product-issue sample validation:         Reviewed; limitations documented

   Review-analysis branch is documented, with the product-issue
   classification limitations retained for portfolio transparency.
   ============================================================ */


/* ============================================================
   PHASE 3 — MISSION 3BA
   PRODUCT CATEGORY PERFORMANCE

   Business question:
   Which product categories contribute the most item sales
   value, and how do order volume and average item price compare?

   Grain: One row per product category.
   Sales definition: Product item price only; freight excluded.
   Units: Number of order-item records.
   ============================================================ */

SELECT
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    ) AS product_category,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    COUNT(*) AS order_item_records,

    ROUND(SUM(oi.price), 2) AS item_sales_value,

    ROUND(AVG(oi.price), 2) AS average_item_price,

    ROUND(
        100.0 * SUM(oi.price) /
        NULLIF(
            SUM(SUM(oi.price)) OVER (),
            0
        ),
        2
    ) AS pct_of_item_sales_value

FROM order_items_model AS oi

LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id

GROUP BY
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    )

ORDER BY item_sales_value DESC;



/*
BUSINESS FINDINGS — MISSION 3BA
Product Category Performance

1. beleza_saude ranked first in item sales value:
   R$1,258,681.34, representing 9.26% of item sales.

2. relogios_presentes ranked second:
   R$1,205,005.68, representing 8.87%.

3. cama_mesa_banho had the highest distinct order count:
   9,417 orders and 11,115 order-item records.

4. pcs had a high average item price of R$1,098.34,
   but only 203 distinct orders.

5. Unknown / Unclassified represented 1,603 order-item
   records, 1,451 distinct orders, and R$179,535.28
   in item sales value (1.32%).

BUSINESS IMPLICATION:
Category performance differs by sales value, order volume,
and average item price. These metrics should be evaluated
together when prioritizing categories.

LIMITATIONS:
- Item sales value excludes freight.
- Sales value is not profit.
- Unknown / Unclassified requires further investigation.
- Category-level associations do not establish causation.
*/



/* ============================================================
   PHASE 3 — MISSION 3BB
   PRODUCT CATEGORY DATA-QUALITY AUDIT

   Business question:
   Why are some order items unclassified?

   Grain: Order-item record, summarized by classification status.
   ============================================================ */

SELECT
    CASE
        WHEN p.product_id IS NULL
            THEN 'No matching product record'
        WHEN NULLIF(
            TRIM(p.product_category_name), ''
        ) IS NULL
            THEN 'Product category missing or blank'
        ELSE 'Classified product'
    END AS category_mapping_status,

    COUNT(*) AS order_item_records,

    COUNT(DISTINCT oi.product_id) AS distinct_products,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    ROUND(SUM(oi.price), 2) AS item_sales_value

FROM order_items_model AS oi

LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id

GROUP BY
    CASE
        WHEN p.product_id IS NULL
            THEN 'No matching product record'
        WHEN NULLIF(
            TRIM(p.product_category_name), ''
        ) IS NULL
            THEN 'Product category missing or blank'
        ELSE 'Classified product'
    END

ORDER BY order_item_records DESC;


/*
BUSINESS FINDINGS — MISSION 3BB
Product Category Data-Quality Audit

1. All 112,650 order-item records matched a product record.
   No unmatched product IDs appeared in the results.

2. 111,047 order-item records were classified.

3. 1,603 order-item records had a missing or blank category,
   representing 610 distinct products and 1,451 distinct orders.

4. Unclassified items contributed R$179,535.28 in item sales
   value, approximately 1.32% of total item sales value.

CONCLUSION:
The observed classification gap is due to missing or blank
product-category values, not unmatched product IDs.

NEXT STEP:
Inspect the other attributes of the 610 products with missing
categories before deciding whether remediation is appropriate.
No source data has been changed.
*/



/* ============================================================
   PHASE 3 — MISSION 3BC
   ATTRIBUTE COMPLETENESS OF UNCLASSIFIED PRODUCTS

   Business question:
   Do products with missing categories also have other
   missing or invalid product attributes?

   Grain: One summary row for the 610 unclassified products.
   ============================================================ */

SELECT
    COUNT(*) AS unclassified_products,

    SUM(product_name_length IS NULL)
        AS missing_name_length,

    SUM(product_description_length IS NULL)
        AS missing_description_length,

    SUM(product_photos_qty IS NULL)
        AS missing_photo_quantity,

    SUM(product_weight_g IS NULL)
        AS missing_weight,

    SUM(product_length_cm IS NULL)
        AS missing_length,

    SUM(product_height_cm IS NULL)
        AS missing_height,

    SUM(product_width_cm IS NULL)
        AS missing_width,

    SUM(product_weight_g = 0)
        AS zero_weight,

    SUM(product_length_cm = 0)
        AS zero_length,

    SUM(product_height_cm = 0)
        AS zero_height,

    SUM(product_width_cm = 0)
        AS zero_width

FROM products_model

WHERE NULLIF(TRIM(product_category_name), '') IS NULL;

/*
BUSINESS FINDINGS — MISSION 3BB
Product Category Data-Quality Audit

1. Classified products account for 111,047 order-item
   records and R$13,412,108.42 in item sales value.

2. Missing or blank categories affect 610 distinct products,
   1,603 order-item records, and 1,451 distinct orders.

3. Unclassified items account for R$179,535.28 in item
   sales value.

BUSINESS IMPLICATION:
Missing category labels reduce the completeness of category
performance reporting. Investigate the affected product records
before assigning or imputing category labels.

LIMITATIONS:
- Missing category labels do not establish why classification
  is absent.
- Do not assign categories without a reliable source.
- Item sales value excludes freight and is not profit.
*/





/* ============================================================
   PHASE 3 — MISSION 3BC
   UNCLASSIFIED PRODUCT ATTRIBUTE PATTERNS

   Business question:
   Do all unclassified products have the same missing
   descriptive attributes?

   Grain: One row per missing-attribute pattern.
   Purpose: Identify the exact combinations of missing fields.
   ============================================================ */

SELECT
    CASE
        WHEN product_name_length IS NULL
         AND product_description_length IS NULL
         AND product_photos_qty IS NULL
         AND product_weight_g IS NULL
         AND product_length_cm IS NULL
         AND product_height_cm IS NULL
         AND product_width_cm IS NULL
            THEN 'All seven attributes missing'

        WHEN product_name_length IS NULL
         AND product_description_length IS NULL
         AND product_photos_qty IS NULL
         AND product_weight_g IS NOT NULL
         AND product_length_cm IS NOT NULL
         AND product_height_cm IS NOT NULL
         AND product_width_cm IS NOT NULL
            THEN 'Three descriptive attributes missing; dimensions and weight present'

        ELSE 'Other missing-attribute pattern'
    END AS attribute_pattern,

    COUNT(*) AS product_count

FROM products_model

WHERE NULLIF(TRIM(product_category_name), '') IS NULL

GROUP BY attribute_pattern

ORDER BY product_count DESC;

/*
BUSINESS FINDINGS — MISSION 3BC
Unclassified Product Attribute Patterns

1. Of 610 unclassified products, 609 (99.84%) have
   three missing descriptive attributes while weight
   and dimensions are present.

2. One product (0.16%) has all seven checked attributes
   missing and warrants individual investigation.

BUSINESS IMPLICATION:
Most unclassified products retain physical measurement
data, while descriptive metadata is consistently absent.
The single record with all attributes missing may require
a separate data-quality review.

LIMITATIONS:
- Attribute patterns do not identify the correct category.
- Missing values should not be imputed without evidence.
- The analysis covers products with missing or blank
  category labels only.
*/


/* ============================================================
   PHASE 3 — MISSION 3BD
   INSPECT PRODUCT WITH ALL ATTRIBUTES MISSING

   Business question:
   Which unclassified product has all seven checked
   attributes missing?

   Grain: One row per product.
   ============================================================ */

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

FROM products_model

WHERE NULLIF(TRIM(product_category_name), '') IS NULL
  AND product_name_length IS NULL
  AND product_description_length IS NULL
  AND product_photos_qty IS NULL
  AND product_weight_g IS NULL
  AND product_length_cm IS NULL
  AND product_height_cm IS NULL
  AND product_width_cm IS NULL;
  
  
  /*
BUSINESS FINDINGS — MISSION 3BD
Product Record with All Attributes Missing

1. Product ID:
   5eb564652db742ff8f28759cd8d2652a

2. The product has a missing or blank category and NULL
   values for all seven checked attributes:
   name length, description length, photo quantity,
   weight, length, height, and width.

BUSINESS IMPLICATION:
This record cannot be meaningfully classified using
the available product attributes. Further investigation
would require a reliable source for the missing metadata.

ACTION:
Retain the record and document the data-quality limitation.
Do not assign a category or invent attribute values.

LIMITATION:
The analysis does not establish why the source record
is incomplete.
*/


/* ============================================================
   PHASE 3 — MISSION 3BE
   BUSINESS IMPACT OF THE INCOMPLETE PRODUCT

   Business question:
   Does this product appear in order items, and what is
   its recorded item sales value?

   Grain: One row for the specified product.
   Sales definition: Item price only; freight excluded.
   ============================================================ */

SELECT
    p.product_id,

    COUNT(oi.order_id) AS order_item_records,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    ROUND(SUM(oi.price), 2) AS item_sales_value,

    ROUND(AVG(oi.price), 2) AS average_item_price

FROM products_model AS p

LEFT JOIN order_items_model AS oi
    ON p.product_id = oi.product_id

WHERE p.product_id = '5eb564652db742ff8f28759cd8d2652a'

GROUP BY p.product_id;

/*
BUSINESS FINDINGS — MISSION 3BE
Business Impact of the Incomplete Product

1. The product appears in 17 order-item records across
   15 distinct orders.

2. Its recorded item sales value is R$563.00, with an
   average item price of R$33.12.

BUSINESS IMPLICATION:
The incomplete product record has measurable historical
sales activity. Preserve the record to maintain historical
order-item relationships and reporting integrity.

RECOMMENDED ACTION:
Investigate the original source metadata before attempting
to restore the category or other attributes.

LIMITATIONS:
- Item sales value excludes freight.
- Item sales value is not profit.
- The analysis does not establish why metadata is missing.
*/


/* ============================================================
   PHASE 3 — MISSION 3BF
   UNMATCHED PRODUCT REFERENCES

   Business question:
   Do order items reference product IDs absent from
   products_model?

   Grain: Summary by product-reference status.
   ============================================================ */

SELECT
    CASE
        WHEN p.product_id IS NULL
            THEN 'No matching product record'
        ELSE 'Matching product record exists'
    END AS product_reference_status,

    COUNT(*) AS order_item_records,

    COUNT(DISTINCT oi.product_id) AS distinct_product_ids,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    ROUND(SUM(oi.price), 2) AS item_sales_value

FROM order_items_model AS oi

LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id

GROUP BY
    CASE
        WHEN p.product_id IS NULL
            THEN 'No matching product record'
        ELSE 'Matching product record exists'
    END

ORDER BY order_item_records DESC;

/*
BUSINESS FINDINGS — MISSION 3BF
Unmatched Product References

1. All 112,650 order-item records have matching product
   records in products_model.

2. The order items reference 32,951 distinct product IDs
   across 98,666 distinct orders.

3. Recorded item sales value totals R$13,591,643.70,
   excluding freight.

BUSINESS IMPLICATION:
Product-reference coverage is complete for the current
order-item dataset. The remaining product-category issue
concerns missing metadata rather than unmatched product IDs.

LIMITATIONS:
- Matching product IDs do not guarantee complete attributes.
- Item sales value is not profit.
- This result reflects the current modeled tables.
*/


/* ============================================================
   PHASE 3 — MISSION 3BG
   CATEGORY SALES RECONCILIATION

   Business question:
   Does category-level item sales value reconcile to total
   order-item sales value?

   Grain: One summary row.
   Sales definition: Item price only; freight excluded.
   ============================================================ */

SELECT
    COUNT(*) AS total_order_item_records,

    ROUND(SUM(oi.price), 2) AS total_item_sales_value,

    ROUND(
        SUM(
            CASE
                WHEN p.product_id IS NULL
                  OR NULLIF(
                      TRIM(p.product_category_name), ''
                  ) IS NULL
                THEN oi.price
                ELSE 0
            END
        ),
        2
    ) AS unclassified_item_sales_value,

    ROUND(
        SUM(
            CASE
                WHEN p.product_id IS NOT NULL
                 AND NULLIF(
                     TRIM(p.product_category_name), ''
                 ) IS NOT NULL
                THEN oi.price
                ELSE 0
            END
        ),
        2
    ) AS classified_item_sales_value,

    ROUND(
        SUM(oi.price) -
        SUM(
            CASE
                WHEN p.product_id IS NULL
                  OR NULLIF(
                      TRIM(p.product_category_name), ''
                  ) IS NULL
                THEN oi.price
                ELSE 0
            END
        ) -
        SUM(
            CASE
                WHEN p.product_id IS NOT NULL
                 AND NULLIF(
                     TRIM(p.product_category_name), ''
                 ) IS NOT NULL
                THEN oi.price
                ELSE 0
            END
        ),
        2
    ) AS reconciliation_difference

FROM order_items_model AS oi

LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id;
    
    /*
BUSINESS FINDINGS — MISSION 3BG
Category Sales Reconciliation

1. Total item sales value is R$13,591,643.70 across
   112,650 order-item records.

2. Classified products account for R$13,412,108.42.
   Unclassified products account for R$179,535.28.

3. Classified and unclassified sales reconcile exactly
   to total item sales, with a difference of R$0.00.

4. Approximately 1.32% of item sales value is associated
   with products whose categories are missing or blank.

VALIDATION STATUS:
PASS — Category-level sales classification reconciles
to the total order-item sales value.

LIMITATIONS:
- Item sales value excludes freight.
- Item sales value is not profit.
- Missing categories remain unresolved and should not
  be guessed or silently excluded.
*/


/* ============================================================
   PHASE 3 — MISSION 3BH
   TOP-FIVE PRODUCT CATEGORY SALES CONCENTRATION

   Business question:
   What share of total item sales comes from the five
   highest-selling classified product categories?

   Grain: One row per classified product category.
   Sales definition: Item price only; freight excluded.
   ============================================================ */

WITH category_sales AS (
    SELECT
        p.product_category_name AS product_category,
        SUM(oi.price) AS item_sales_value
    FROM order_items_model AS oi
    INNER JOIN products_model AS p
        ON oi.product_id = p.product_id
    WHERE NULLIF(TRIM(p.product_category_name), '') IS NOT NULL
    GROUP BY p.product_category_name
),

ranked_categories AS (
    SELECT
        product_category,
        item_sales_value,
        ROW_NUMBER() OVER (
            ORDER BY item_sales_value DESC
        ) AS sales_rank
    FROM category_sales
)

SELECT
    COUNT(*) AS top_five_categories,

    ROUND(SUM(item_sales_value), 2)
        AS top_five_item_sales_value,

    ROUND(
        100.0 * SUM(item_sales_value) /
        NULLIF(
            (SELECT SUM(item_sales_value)
             FROM category_sales),
            0
        ),
        2
    ) AS pct_of_classified_item_sales,

    ROUND(
        100.0 * SUM(item_sales_value) /
        NULLIF(
            (SELECT SUM(price)
             FROM order_items_model),
            0
        ),
        2
    ) AS pct_of_all_item_sales

FROM ranked_categories
WHERE sales_rank <= 5;

/*
BUSINESS FINDINGS — MISSION 3BH
Top-Five Product Category Sales Concentration

1. The five highest-selling classified categories generated
   R$5,400,678.99 in item sales value.

2. These categories represent 40.27% of classified item
   sales and 39.74% of all item sales.

BUSINESS IMPLICATION:
A limited group of categories contributes a substantial
share of item sales. These categories may warrant deeper
analysis of margins, demand, fulfillment, and customer
experience before making business decisions.

LIMITATIONS:
- Item sales value excludes freight.
- Sales value is not profit.
- Sales concentration alone does not establish which
  categories deserve additional investment.
*/


/* ============================================================
   PHASE 3 — MISSION 3BI
   TOP-FIVE PRODUCT CATEGORIES BY ITEM SALES

   Business question:
   Which classified categories contribute the most item sales?

   Grain: One row per product category.
   Sales definition: Item price only; freight excluded.
   ============================================================ */

SELECT
    p.product_category_name AS product_category,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    COUNT(*) AS order_item_records,

    ROUND(SUM(oi.price), 2) AS item_sales_value,

    ROUND(
        100.0 * SUM(oi.price) /
        NULLIF(
            (SELECT SUM(oi2.price)
             FROM order_items_model AS oi2
             INNER JOIN products_model AS p2
                 ON oi2.product_id = p2.product_id
             WHERE NULLIF(
                 TRIM(p2.product_category_name), ''
             ) IS NOT NULL),
            0
        ),
        2
    ) AS pct_of_classified_item_sales

FROM order_items_model AS oi

INNER JOIN products_model AS p
    ON oi.product_id = p.product_id

WHERE NULLIF(TRIM(p.product_category_name), '') IS NOT NULL

GROUP BY p.product_category_name

ORDER BY item_sales_value DESC

LIMIT 5;

/*
BUSINESS FINDINGS — MISSION 3BI
Top-Five Product Categories by Item Sales

1. beleza_saude ranked first with R$1,258,681.34 in item
   sales, representing 9.38% of classified item sales.

2. relogios_presentes ranked second with R$1,205,005.68,
   representing 8.98%.

3. cama_mesa_banho had the highest distinct order count:
   9,417 orders and 11,115 order-item records.

4. esporte_lazer generated R$988,048.97 in item sales.

5. informatica_acessorios generated R$911,954.32 in item
   sales.

6. The five categories generated R$5,400,678.99 in
   combined item sales value, approximately 40.27% of
   classified item sales.

BUSINESS IMPLICATION:
Category priorities should consider sales value, order
volume, average item price, profitability, and customer
experience together rather than sales value alone.

LIMITATIONS:
- Item sales value excludes freight.
- Sales value is not profit.
- These results describe historical associations, not
  the causes of category performance.
*/


/* ============================================================
   PHASE 3 — MISSION 3BJ
   TOP-FIVE CATEGORY AVERAGE ITEM PRICE

   Business question:
   How does average item price differ across the five
   highest-selling classified categories?

   Grain: One row per top-five product category.
   ============================================================ */

SELECT
    p.product_category_name AS product_category,

    COUNT(*) AS order_item_records,

    ROUND(SUM(oi.price), 2) AS item_sales_value,

    ROUND(AVG(oi.price), 2) AS average_item_price,

    ROUND(
        SUM(oi.price) / COUNT(*),
        2
    ) AS sales_per_order_item

FROM order_items_model AS oi

INNER JOIN products_model AS p
    ON oi.product_id = p.product_id

WHERE NULLIF(TRIM(p.product_category_name), '') IS NOT NULL

GROUP BY p.product_category_name

ORDER BY SUM(oi.price) DESC

LIMIT 5;

/*
BUSINESS FINDINGS — MISSION 3BJ
Average Item Price in Top-Five Categories

1. relogios_presentes had the highest average item price:
   R$201.14 across 5,991 order-item records.

2. cama_mesa_banho had the highest item volume:
   11,115 records, with an average item price of R$93.30.

3. beleza_saude led total item sales at R$1,258,681.34,
   with an average item price of R$130.16.

BUSINESS IMPLICATION:
Category sales performance reflects a combination of
item volume and average item price. Evaluate both before
making category-level recommendations.

LIMITATIONS:
- Item sales value excludes freight.
- Average item price is not profit margin.
- No causal conclusions can be drawn from these results.
*/


/* ============================================================
   PHASE 3 — MISSION 3BK
   VALIDATE REVIEW ISSUE COMBINATIONS

   Business question:
   Which issue-flag combinations account for all written
   review records, including combinations omitted from
   the original Mission 3AT labels?

   Grain: One row per unique combination of four issue flags.
   Denominator: Written review records only.
   ============================================================ */

WITH review_flags AS (
    SELECT
        CASE
            WHEN review_score IN (1, 2)
                THEN 'Low (1-2)'
            WHEN review_score = 3
                THEN 'Middle (3)'
            WHEN review_score IN (4, 5)
                THEN 'High (4-5)'
        END AS rating_group,

        CASE WHEN LOWER(
            CONCAT_WS(' ',
                review_comment_title,
                review_comment_message
            )
        ) REGEXP
        'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
        THEN 1 ELSE 0 END AS nonreceipt_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ',
                review_comment_title,
                review_comment_message
            )
        ) REGEXP
        'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
        THEN 1 ELSE 0 END AS incomplete_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ',
                review_comment_title,
                review_comment_message
            )
        ) REGEXP
        'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
        THEN 1 ELSE 0 END AS service_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ',
                review_comment_title,
                review_comment_message
            )
        ) REGEXP
        'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
        THEN 1 ELSE 0 END AS product_flag

    FROM reviews_model
    WHERE NULLIF(
        TRIM(CONCAT_WS(' ',
            review_comment_title,
            review_comment_message
        )),
        ''
    ) IS NOT NULL
)

SELECT
    rating_group,
    nonreceipt_flag,
    incomplete_flag,
    service_flag,
    product_flag,

    COUNT(*) AS written_review_records,

    SUM(
        nonreceipt_flag
        + incomplete_flag
        + service_flag
        + product_flag
    ) AS total_flags_in_group

FROM review_flags

GROUP BY
    rating_group,
    nonreceipt_flag,
    incomplete_flag,
    service_flag,
    product_flag

ORDER BY
    rating_group,
    written_review_records DESC;
    
    
    /* ============================================================
   PHASE 3 — MISSION 3BL
   REVIEW ISSUE-FLAG POPULATION RECONCILIATION

   Purpose:
   Reconcile written reviews, flagged reviews, and unflagged
   reviews using the four current keyword rules.

   Grain: One row per population metric.
   ============================================================ */

WITH review_flags AS (
    SELECT
        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
        THEN 1 ELSE 0 END AS nonreceipt_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
        THEN 1 ELSE 0 END AS incomplete_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
        THEN 1 ELSE 0 END AS service_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
        THEN 1 ELSE 0 END AS product_flag

    FROM reviews_model
    WHERE NULLIF(
        TRIM(CONCAT_WS(' ', review_comment_title, review_comment_message)),
        ''
    ) IS NOT NULL
)

SELECT
    COUNT(*) AS written_review_records,

    SUM(
        CASE
            WHEN nonreceipt_flag + incomplete_flag
               + service_flag + product_flag > 0
            THEN 1 ELSE 0
        END
    ) AS reviews_with_any_issue_flag,

    SUM(
        CASE
            WHEN nonreceipt_flag + incomplete_flag
               + service_flag + product_flag = 0
            THEN 1 ELSE 0
        END
    ) AS reviews_with_no_issue_flags,

    SUM(
        CASE
            WHEN nonreceipt_flag + incomplete_flag
               + service_flag + product_flag > 1
            THEN 1 ELSE 0
        END
    ) AS reviews_with_multiple_flags

FROM review_flags;


/* ============================================================
   PHASE 3 — MISSION 3BM
   COMPLETE REVIEW ISSUE-COMBINATION RECONCILIATION

   Purpose:
   Report every observed combination of the four issue flags
   without manually assigning combination labels.

   Validation targets:
   42,697 written reviews
   6,203 reviews with at least one issue flag
   ============================================================ */

WITH review_flags AS (
    SELECT
        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'
        THEN 1 ELSE 0 END AS nonreceipt_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'
        THEN 1 ELSE 0 END AS incomplete_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'
        THEN 1 ELSE 0 END AS service_flag,

        CASE WHEN LOWER(
            CONCAT_WS(' ', review_comment_title, review_comment_message)
        ) REGEXP
        'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
        THEN 1 ELSE 0 END AS product_flag

    FROM reviews_model
    WHERE NULLIF(
        TRIM(CONCAT_WS(' ', review_comment_title, review_comment_message)),
        ''
    ) IS NOT NULL
)

SELECT
    nonreceipt_flag,
    incomplete_flag,
    service_flag,
    product_flag,
    COUNT(*) AS written_review_records,
    SUM(
        CASE
            WHEN nonreceipt_flag + incomplete_flag
               + service_flag + product_flag > 0
            THEN 1 ELSE 0
        END
    ) AS reviews_with_any_issue_flag
FROM review_flags
GROUP BY
    nonreceipt_flag,
    incomplete_flag,
    service_flag,
    product_flag
ORDER BY written_review_records DESC;



 
/* MISSION 3AR — DIAGNOSTIC FOR UNEXPECTED MATCH */

SELECT
    review_id,
    review_comment_title,
    review_comment_message,
    LOWER(
        CONCAT(
            COALESCE(review_comment_title, ''),
            ' ',
            COALESCE(review_comment_message, '')
        )
    ) AS searchable_text,
    LOWER(
        CONCAT(
            COALESCE(review_comment_title, ''),
            ' ',
            COALESCE(review_comment_message, '')
        )
    ) REGEXP
        'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
        AS matches_product_issue_rule
FROM reviews_model
WHERE review_id = '070db8ec4ab348d7c6c594657b22a122';


/* ============================================================
   MISSION 3AR — REFINED PRODUCT-ISSUE RULE TEST
   Objective: Compare the refined rule with the original rule.
   Grain: One review record.
   Note: Exploratory keyword classification; validate before use.
   ============================================================ */

SELECT
    COUNT(*) AS low_score_written_reviews,

    SUM(
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) REGEXP
        'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
    ) AS original_rule_matches,

    SUM(
        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) REGEXP
        'defeito|quebrad|danificad|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado|produto.{0,30}nao funciona|produto.{0,30}não funciona|aparelho.{0,30}nao funciona|aparelho.{0,30}não funciona'
    ) AS refined_rule_matches

FROM reviews_model
WHERE review_score BETWEEN 1 AND 2
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  );
  
  
  
  /* ============================================================
   MISSION 3AR — REVIEW REFINEMENT VALIDATION
   Objective: Inspect reviews excluded by the refined rule.
   Grain: One review record.
   ============================================================ */

SELECT
    review_score,
    review_id,
    review_comment_title,
    review_comment_message
FROM reviews_model
WHERE review_score BETWEEN 1 AND 2
  AND (
      NULLIF(TRIM(review_comment_title), '') IS NOT NULL
      OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
  )
  AND LOWER(
      CONCAT(
          COALESCE(review_comment_title, ''),
          ' ',
          COALESCE(review_comment_message, '')
      )
  ) REGEXP
      'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
  AND LOWER(
      CONCAT(
          COALESCE(review_comment_title, ''),
          ' ',
          COALESCE(review_comment_message, '')
      )
  ) NOT REGEXP
      'defeito|quebrad|danificad|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado|produto.{0,30}nao funciona|produto.{0,30}não funciona|aparelho.{0,30}nao funciona|aparelho.{0,30}não funciona'
ORDER BY review_score, review_id
LIMIT 30;



/*
MISSION 3AR — PRODUCT-ISSUE KEYWORD VALIDATION

Original rule matches: 768 of 10,994 low-score written reviews (6.99%).
Refined rule matches: 705 of 10,994 (6.41%).
Difference: 63 fewer matches under the refined rule.

Manual inspection of the excluded sample found that many reviews
describe genuine product failures, including items that do not work.
The original rule can also generate false positives when phrases
such as "não funciona" refer to a seller's phone or a website.

Decision:
Retain the original rule for exploratory analysis.
Do not treat keyword matches as confirmed product defects.
Further refinement requires broader manual validation.
*/



SHOW VARIABLES LIKE 'secure_file_priv';




-- ============================================================
-- PHASE 4 | MISSION 4A
-- Direct CSV export from MySQL server
-- Expected data rows: 96,470
-- Note: This export does not include column headers.
-- ============================================================

SELECT
    order_id,
    DATE(order_purchase_timestamp) AS purchase_date,
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
        AS purchase_month,
    DATE(order_delivered_customer_date)
        AS actual_delivery_date,
    DATE(order_estimated_delivery_date)
        AS estimated_delivery_date,
    DATEDIFF(
        order_delivered_customer_date,
        order_estimated_delivery_date
    ) AS days_vs_estimate,
    CASE
        WHEN DATE(order_delivered_customer_date)
             <= DATE(order_estimated_delivery_date)
            THEN 'On time or early'
        WHEN DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) <= 7
            THEN '1-7 days late'
        WHEN DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) <= 30
            THEN '8-30 days late'
        ELSE '>30 days late'
    END AS delay_band

INTO OUTFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Mission_4A_Delivery_Performance_SQL.csv'

FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'

FROM orders_model
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;





-- ============================================================
-- PHASE 4 | MISSION 4C
-- Delivery Delay Severity
-- Objective: Compare the volume and severity of late deliveries.
-- Grain: One row per delay category.
-- ============================================================

SELECT
    CASE
        WHEN DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) <= 0 THEN 'On time or early'
        WHEN DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) <= 7 THEN '1-7 days late'
        WHEN DATEDIFF(
            order_delivered_customer_date,
            order_estimated_delivery_date
        ) <= 30 THEN '8-30 days late'
        ELSE '>30 days late'
    END AS delay_band,

    COUNT(*) AS order_count,

    ROUND(AVG(DATEDIFF(
        order_delivered_customer_date,
        order_estimated_delivery_date
    )), 2) AS avg_days_vs_estimate,

    MAX(DATEDIFF(
        order_delivered_customer_date,
        order_estimated_delivery_date
    )) AS max_days_late

FROM orders_model
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL

GROUP BY delay_band
ORDER BY
    CASE delay_band
        WHEN 'On time or early' THEN 1
        WHEN '1-7 days late' THEN 2
        WHEN '8-30 days late' THEN 3
        WHEN '>30 days late' THEN 4
    END;





-- ============================================================
-- PHASE 4 | MISSION 4B
-- Direct CSV export from MySQL server
-- Objective: Monthly order trends and month-over-month growth
-- Grain: One row per purchase month
-- Expected columns: 8
-- Note: This export does not include column headers.
-- ============================================================

USE olist_analytics;

WITH monthly_orders AS (
    SELECT
        DATE_FORMAT(
            order_purchase_timestamp, '%Y-%m'
        ) AS order_month,

        COUNT(*) AS total_orders,

        SUM(order_status = 'delivered')
            AS delivered_orders,

        SUM(order_status = 'canceled')
            AS canceled_orders

    FROM orders_model
    WHERE order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_FORMAT(
        order_purchase_timestamp, '%Y-%m'
    )
),
monthly_comparison AS (
    SELECT
        order_month,
        total_orders,
        delivered_orders,
        canceled_orders,

        LAG(total_orders) OVER (
            ORDER BY order_month
        ) AS previous_month_orders

    FROM monthly_orders
)
SELECT
    order_month,
    total_orders,
    delivered_orders,
    canceled_orders,

    ROUND(
        100.0 * delivered_orders / NULLIF(total_orders, 0),
        2
    ) AS delivered_order_percentage,

    previous_month_orders,

    total_orders - previous_month_orders
        AS order_change,

    ROUND(
        100.0 * (total_orders - previous_month_orders)
        / NULLIF(previous_month_orders, 0),
        2
    ) AS mom_growth_percentage

FROM monthly_comparison
ORDER BY order_month

INTO OUTFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Mission_4B_Monthly_Order_Trends_SQL.csv'

FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n';




-- PHASE 4B.2: MONTHLY PAYMENT VALUE AND AOV
-- Export monthly results for Excel analysis.

WITH payments_per_order AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_payment_value
    FROM payments_model
    GROUP BY order_id
),
monthly_performance AS (
    SELECT
        DATE_FORMAT(
            o.order_purchase_timestamp,
            '%Y-%m'
        ) AS order_month,
        COUNT(*) AS eligible_orders,
        SUM(p.order_payment_value)
            AS total_recorded_payment_value,
        AVG(p.order_payment_value)
            AS average_payment_value_per_order
    FROM orders_model AS o
    INNER JOIN payments_per_order AS p
        ON o.order_id = p.order_id
    WHERE o.order_purchase_timestamp IS NOT NULL
      AND o.order_status <> 'canceled'
    GROUP BY DATE_FORMAT(
        o.order_purchase_timestamp,
        '%Y-%m'
    )
)
SELECT
    order_month,
    eligible_orders,
    ROUND(total_recorded_payment_value, 2)
        AS total_recorded_payment_value,
    ROUND(average_payment_value_per_order, 2)
        AS average_payment_value_per_order
INTO OUTFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Mission_4B_Monthly_Payment_Value_SQL.csv'
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
FROM monthly_performance
ORDER BY order_month;


SELECT
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    ) AS product_category,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    COUNT(*) AS order_item_records,

    ROUND(SUM(oi.price), 2) AS item_sales_value,

    ROUND(AVG(oi.price), 2) AS average_item_price,

    ROUND(
        100.0 * SUM(oi.price) /
        NULLIF(
            SUM(SUM(oi.price)) OVER (),
            0
        ),
        2
    ) AS pct_of_item_sales_value

FROM order_items_model AS oi

LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id

GROUP BY
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    )

ORDER BY item_sales_value DESC;






-- ============================================================
-- PHASE 4C: PRODUCT CATEGORY PERFORMANCE
-- Objective:
-- Analyze product-category sales, order-item volume,
-- average item price, sales contribution, and data quality.
--
-- Source tables:
--   order_items_model
--   products_model
--
-- Important limitations:
--   Item sales value uses product prices and excludes freight.
--   Item sales value is not profit.
--   Order-item records are not the same as distinct orders
--   or individual units sold.
-- ============================================================


-- ============================================================
-- MISSION 4C.1: PRODUCT CATEGORY PERFORMANCE
-- Objective:
-- Produce the category-level dataset used by the Excel
-- PivotTable.
-- ============================================================

SELECT
    -- Replace blank or missing category names with a label.
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    ) AS product_category,

    -- Number of unique orders containing this category.
    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    -- Number of order-item records in this category.
    COUNT(*) AS order_item_records,

    -- Total product-price value, excluding freight.
    ROUND(SUM(oi.price), 2) AS item_sales_value,

    -- Average product price per order-item record.
    ROUND(AVG(oi.price), 2) AS average_item_price,

    -- Percentage contribution to total item sales.
    ROUND(
        100.0 * SUM(oi.price) /
        NULLIF(SUM(SUM(oi.price)) OVER (), 0),
        2
    ) AS pct_of_item_sales_value

FROM order_items_model AS oi

-- Keep order-item records even if category information is missing.
LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id

-- Aggregate the measures at product-category level.
GROUP BY
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    )

-- Show the highest-selling categories first.
ORDER BY
    item_sales_value DESC,
    product_category ASC;


-- ============================================================
-- MISSION 4C.2: TOP 10 ITEM SALES VALUE BY PRODUCT CATEGORY
-- Objective:
-- Return the ten highest-selling categories for comparison
-- with the Excel Top 10 PivotChart.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    ) AS product_category,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    COUNT(*) AS order_item_records,

    ROUND(SUM(oi.price), 2) AS item_sales_value,

    ROUND(
        100.0 * SUM(oi.price) /
        NULLIF(SUM(SUM(oi.price)) OVER (), 0),
        2
    ) AS pct_of_item_sales_value

FROM order_items_model AS oi

LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id

GROUP BY
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    )

-- Deterministic ranking: sales descending, then category name.
ORDER BY
    item_sales_value DESC,
    product_category ASC

LIMIT 10;


-- ============================================================
-- MISSION 4C.3: DATA QUALITY AND RECONCILIATION
-- CHECK 1: CATEGORY COVERAGE AND TOTAL SALES
-- Objective:
-- Validate category count, uniqueness, and full sales total.
-- ============================================================

WITH category_summary AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown / Unclassified'
        ) AS product_category,

        COUNT(DISTINCT oi.order_id) AS distinct_orders,

        COUNT(*) AS order_item_records,

        SUM(oi.price) AS item_sales_value

    FROM order_items_model AS oi

    LEFT JOIN products_model AS p
        ON oi.product_id = p.product_id

    GROUP BY
        COALESCE(
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown / Unclassified'
        )
)

SELECT
    COUNT(*) AS category_count,

    COUNT(DISTINCT product_category) AS unique_category_count,

    ROUND(
        SUM(item_sales_value),
        2
    ) AS total_item_sales_value,

    -- Calculate the total share from unrounded sales values.
    -- This should equal 100.00%, subject to displayed rounding.
    ROUND(
        100.0 * SUM(item_sales_value) /
        NULLIF(SUM(item_sales_value), 0),
        2
    ) AS total_sales_share_pct

FROM category_summary;


-- ============================================================
-- MISSION 4C.3: CHECK 2
-- VALIDATE THE UNKNOWN / UNCLASSIFIED CATEGORY
-- Objective:
-- Inspect the sales and order-item impact of missing
-- or blank category classifications.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    ) AS product_category,

    COUNT(DISTINCT oi.order_id) AS distinct_orders,

    COUNT(*) AS order_item_records,

    ROUND(
        SUM(oi.price),
        2
    ) AS item_sales_value,

    ROUND(
        100.0 * SUM(oi.price) /
        NULLIF(SUM(SUM(oi.price)) OVER (), 0),
        2
    ) AS pct_of_item_sales_value

FROM order_items_model AS oi

LEFT JOIN products_model AS p
    ON oi.product_id = p.product_id

GROUP BY
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    )

HAVING
    COALESCE(
        NULLIF(TRIM(p.product_category_name), ''),
        'Unknown / Unclassified'
    ) = 'Unknown / Unclassified';


-- ============================================================
-- MISSION 4C.3: CHECK 3
-- RECONCILE TOP 10 AND REMAINING CATEGORY SALES
-- Objective:
-- Independently calculate the Top 10 subtotal and the
-- sales contribution from all remaining categories.
-- ============================================================

WITH category_summary AS (
    SELECT
        COALESCE(
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown / Unclassified'
        ) AS product_category,

        SUM(oi.price) AS item_sales_value

    FROM order_items_model AS oi

    LEFT JOIN products_model AS p
        ON oi.product_id = p.product_id

    GROUP BY
        COALESCE(
            NULLIF(TRIM(p.product_category_name), ''),
            'Unknown / Unclassified'
        )
),
ranked_categories AS (
    SELECT
        product_category,

        item_sales_value,

        ROW_NUMBER() OVER (
            ORDER BY
                item_sales_value DESC,
                product_category ASC
        ) AS sales_rank

    FROM category_summary
)

SELECT
    ROUND(
        SUM(item_sales_value),
        2
    ) AS total_item_sales_value,

    ROUND(
        SUM(
            CASE
                WHEN sales_rank <= 10
                THEN item_sales_value
                ELSE 0
            END
        ),
        2
    ) AS top_10_item_sales_value,

    ROUND(
        SUM(
            CASE
                WHEN sales_rank > 10
                THEN item_sales_value
                ELSE 0
            END
        ),
        2
    ) AS remaining_category_sales_value,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN sales_rank <= 10
                THEN item_sales_value
                ELSE 0
            END
        ) /
        NULLIF(SUM(item_sales_value), 0),
        2
    ) AS top_10_share_pct

FROM ranked_categories;


    
/* =====================================================================
   OLIST FLAGSHIP PROJECT — PHASE 4D: CUSTOMER ANALYSIS
   Consolidated SQL script: analysis + CSV exports for Excel

   Database: olist_analytics
   Source tables: customers_model, orders_model

   WORKFLOW
   1. Run the secure_file_priv check below.
   2. Update the EXPORT_DIR variable in the four OUTFILE statements to
      match the exact folder returned by secure_file_priv.
   3. Run each mission's ANALYSIS query first and validate its results.
   4. Run that mission's EXPORT query to create its CSV.
   5. Import the CSVs into your own Excel workbook and build pivots/charts.

   IMPORTANT
   - MySQL INTO OUTFILE does not include column headers automatically.
   - INTO OUTFILE cannot overwrite an existing file. Delete/rename the old
     CSV or use a new filename before rerunning an export.
   - The example directory is common but MUST be checked on your machine.
   - DATEDIFF measures calendar-day boundaries, not exact elapsed 24-hour
     periods.
   ===================================================================== */

USE olist_analytics;

/* ---------------------------------------------------------------------
   SETUP — confirm the permitted export directory
   --------------------------------------------------------------------- */
SHOW VARIABLES LIKE 'secure_file_priv';

/* =====================================================================
   MISSION 4D.1 — CUSTOMER ORDER-FREQUENCY DISTRIBUTION
   Expected validation totals:
   96,096 unique customers; 93,099 with 1 order; 2,745 with 2;
   203 with 3; 49 with 4+.
   ===================================================================== */

/* 4D.1A — Analysis result */
WITH customer_order_counts AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
frequency_groups AS (
    SELECT
        customer_unique_id,
        order_count,
        CASE
            WHEN order_count = 1 THEN '1 order'
            WHEN order_count = 2 THEN '2 orders'
            WHEN order_count = 3 THEN '3 orders'
            ELSE '4+ orders'
        END AS order_frequency_group,
        CASE
            WHEN order_count = 1 THEN 1
            WHEN order_count = 2 THEN 2
            WHEN order_count = 3 THEN 3
            ELSE 4
        END AS group_sort_order
    FROM customer_order_counts
)
SELECT
    order_frequency_group,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_percentage
FROM frequency_groups
GROUP BY order_frequency_group, group_sort_order
ORDER BY group_sort_order;


/* 4D.1B — CSV export (replace directory with secure_file_priv value) */
WITH customer_order_counts AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS order_count
    FROM customers_model AS c
    INNER JOIN orders_model AS o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
frequency_groups AS (
    SELECT
        customer_unique_id,
        order_count,
        CASE
            WHEN order_count = 1 THEN '1 order'
            WHEN order_count = 2 THEN '2 orders'
            WHEN order_count = 3 THEN '3 orders'
            ELSE '4+ orders'
        END AS order_frequency_group,
        CASE
            WHEN order_count = 1 THEN 1
            WHEN order_count = 2 THEN 2
            WHEN order_count = 3 THEN 3
            ELSE 4
        END AS group_sort_order
    FROM customer_order_counts
)
SELECT
    order_frequency_group,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_percentage
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Mission_4D_1_Customer_Order_Frequency.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
FROM frequency_groups
GROUP BY order_frequency_group, group_sort_order
ORDER BY group_sort_order;

  /* =====================================================================
   MISSION 4D.2 — TIME TO SECOND PURCHASE
   Grain: one row per repeat customer with a valid first and second order
   timestamp. DATEDIFF reports calendar-day difference.
   Previously validated: 2,997 repeat customers; average 80.35 days;
   29.93% have a 0-day calendar gap.
   ===================================================================== */
  
  /* 4D.2A — Customer-level time to second purchase */
WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_number
    FROM customers_model AS c
    INNER JOIN orders_model AS o
        ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN purchase_number = 1 THEN order_purchase_timestamp END) AS first_purchase_timestamp,
        MAX(CASE WHEN purchase_number = 2 THEN order_purchase_timestamp END) AS second_purchase_timestamp
    FROM ranked_orders
    WHERE purchase_number <= 2
    GROUP BY customer_unique_id
    HAVING COUNT(*) >= 2
)
SELECT
    customer_unique_id,
    first_purchase_timestamp,
    second_purchase_timestamp,
    DATEDIFF(second_purchase_timestamp, first_purchase_timestamp) AS days_to_second_purchase
FROM first_second
ORDER BY days_to_second_purchase, customer_unique_id;

/* 4D.2B — Summary metrics */
WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_number
    FROM customers_model AS c
    INNER JOIN orders_model AS o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN purchase_number = 1 THEN order_purchase_timestamp END) AS first_purchase_timestamp,
        MAX(CASE WHEN purchase_number = 2 THEN order_purchase_timestamp END) AS second_purchase_timestamp
    FROM ranked_orders
    WHERE purchase_number <= 2
    GROUP BY customer_unique_id
    HAVING COUNT(*) >= 2
),
gaps AS (
    SELECT
        customer_unique_id,
        DATEDIFF(second_purchase_timestamp, first_purchase_timestamp) AS days_to_second_purchase
    FROM first_second
)
SELECT
    COUNT(*) AS repeat_customers_with_timestamps,
    ROUND(AVG(days_to_second_purchase), 2) AS average_days_to_second_purchase,
    MIN(days_to_second_purchase) AS minimum_days,
    MAX(days_to_second_purchase) AS maximum_days,
    SUM(days_to_second_purchase = 0) AS same_calendar_day_customers,
    ROUND(100.0 * SUM(days_to_second_purchase = 0) / COUNT(*), 2) AS same_calendar_day_percentage
FROM gaps;


 /* 4D.2C — CSV export of customer-level gaps */
WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_number
    FROM customers_model AS c
    INNER JOIN orders_model AS o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN purchase_number = 1 THEN order_purchase_timestamp END) AS first_purchase_timestamp,
        MAX(CASE WHEN purchase_number = 2 THEN order_purchase_timestamp END) AS second_purchase_timestamp
    FROM ranked_orders
    WHERE purchase_number <= 2
    GROUP BY customer_unique_id
    HAVING COUNT(*) >= 2
)
SELECT
    customer_unique_id,
    first_purchase_timestamp,
    second_purchase_timestamp,
    DATEDIFF(second_purchase_timestamp, first_purchase_timestamp) AS days_to_second_purchase
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Mission_4D_2_Time_To_Second_Purchase.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
FROM first_second
ORDER BY days_to_second_purchase, customer_unique_id;



/* =====================================================================
   MISSION 4D.3 — FIRST-TO-SECOND PURCHASE GAP DISTRIBUTION
   Groups: same day, 1–30, 31–60, 61–90, 91–180, >180 calendar days.
   Previously validated totals: 2,997 customers; 100% across groups.
   ===================================================================== */

/* 4D.3A — Analysis result */
WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS purchase_number
    FROM customers_model AS c
    INNER JOIN orders_model AS o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN purchase_number = 1 THEN order_purchase_timestamp END) AS first_purchase_timestamp,
        MAX(CASE WHEN purchase_number = 2 THEN order_purchase_timestamp END) AS second_purchase_timestamp
    FROM ranked_orders
    WHERE purchase_number <= 2
    GROUP BY customer_unique_id
    HAVING COUNT(*) >= 2
),
gaps AS (
    SELECT
        customer_unique_id,
        DATEDIFF(second_purchase_timestamp, first_purchase_timestamp) AS gap_days
    FROM first_second
),
bucketed AS (
    SELECT
        customer_unique_id,
        gap_days,
        CASE
            WHEN gap_days = 0 THEN 'Same day'
            WHEN gap_days BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN gap_days BETWEEN 31 AND 60 THEN '31-60 days'
            WHEN gap_days BETWEEN 61 AND 90 THEN '61-90 days'
            WHEN gap_days BETWEEN 91 AND 180 THEN '91-180 days'
            ELSE '>180 days'
        END AS gap_group,
        CASE
            WHEN gap_days = 0 THEN 1
            WHEN gap_days BETWEEN 1 AND 30 THEN 2
            WHEN gap_days BETWEEN 31 AND 60 THEN 3
            WHEN gap_days BETWEEN 61 AND 90 THEN 4
            WHEN gap_days BETWEEN 91 AND 180 THEN 5
            ELSE 6
        END AS group_sort_order
    FROM gaps
)
SELECT
    gap_group,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_percentage,
    ROUND(AVG(gap_days), 2) AS average_gap_days,
    MIN(gap_days) AS minimum_gap_days,
    MAX(gap_days) AS maximum_gap_days
FROM bucketed
GROUP BY gap_group, group_sort_order
ORDER BY group_sort_order;


/* =====================================================================
   MISSION 4D.4 — FIRST-PURCHASE COHORT: 180-DAY REPEAT ANALYSIS

   Cohort = month of customer's first observed purchase.
   Eligible customer = first purchase timestamp is at least 180 days
   before the dataset's maximum purchase timestamp.
   Repeat within 180 days = second purchase timestamp falls from the
   first purchase timestamp through day 180 (inclusive).

   IMPORTANT: This explicit eligibility rule avoids treating recent
   cohorts as if they had a complete 180-day observation window.
   The historical validation target from prior work was 68,940 eligible
   customers, 2,098 repeaters, and a 3.04% rate. If the query below does
   not reproduce those figures, stop and reconcile the exact prior cohort
   cutoff definition before using the export in Excel.
   ===================================================================== */

/* 4D.4A — Cohort analysis result */
WITH order_timestamps AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM customers_model AS c
    INNER JOIN orders_model AS o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
ranked_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number
    FROM order_timestamps
),
customer_first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN purchase_number = 1 THEN order_purchase_timestamp END) AS first_purchase_timestamp,
        MAX(CASE WHEN purchase_number = 2 THEN order_purchase_timestamp END) AS second_purchase_timestamp
    FROM ranked_orders
    WHERE purchase_number <= 2
    GROUP BY customer_unique_id
),
data_end AS (
    SELECT MAX(order_purchase_timestamp) AS max_purchase_timestamp
    FROM order_timestamps
),
cohort_customers AS (
    SELECT
        f.customer_unique_id,
        f.first_purchase_timestamp,
        f.second_purchase_timestamp,
        DATE_FORMAT(f.first_purchase_timestamp, '%Y-%m') AS first_purchase_cohort,
        d.max_purchase_timestamp
    FROM customer_first_second AS f
    CROSS JOIN data_end AS d
    WHERE f.first_purchase_timestamp IS NOT NULL
),
eligible_customers AS (
    SELECT
        customer_unique_id,
        first_purchase_timestamp,
        second_purchase_timestamp,
        first_purchase_cohort,
        CASE
            WHEN second_purchase_timestamp IS NOT NULL
             AND second_purchase_timestamp >= first_purchase_timestamp
             AND second_purchase_timestamp <= DATE_ADD(first_purchase_timestamp, INTERVAL 180 DAY)
            THEN 1 ELSE 0
        END AS repeated_within_180_days
    FROM cohort_customers
    WHERE first_purchase_timestamp <= DATE_SUB(max_purchase_timestamp, INTERVAL 180 DAY)
)
SELECT
    first_purchase_cohort,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_180_days) AS customers_repeating_within_180_days,
    COUNT(*) - SUM(repeated_within_180_days) AS customers_not_repeating_within_180_days,
    ROUND(100.0 * SUM(repeated_within_180_days) / COUNT(*), 2) AS repeat_rate_180_days_percentage
FROM eligible_customers
GROUP BY first_purchase_cohort
ORDER BY first_purchase_cohort;




/* 4D.4B — Reconciliation totals */
WITH order_timestamps AS (
    SELECT c.customer_unique_id, o.order_id, o.order_purchase_timestamp
    FROM customers_model AS c
    INNER JOIN orders_model AS o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
ranked_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number
    FROM order_timestamps
),
customer_first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN purchase_number = 1 THEN order_purchase_timestamp END) AS first_purchase_timestamp,
        MAX(CASE WHEN purchase_number = 2 THEN order_purchase_timestamp END) AS second_purchase_timestamp
    FROM ranked_orders
    WHERE purchase_number <= 2
    GROUP BY customer_unique_id
),
data_end AS (
    SELECT MAX(order_purchase_timestamp) AS max_purchase_timestamp FROM order_timestamps
),
eligible_customers AS (
    SELECT
        f.customer_unique_id,
        f.first_purchase_timestamp,
        f.second_purchase_timestamp,
        CASE
            WHEN f.second_purchase_timestamp IS NOT NULL
             AND f.second_purchase_timestamp >= f.first_purchase_timestamp
             AND f.second_purchase_timestamp <= DATE_ADD(f.first_purchase_timestamp, INTERVAL 180 DAY)
            THEN 1 ELSE 0
        END AS repeated_within_180_days
    FROM customer_first_second AS f
    CROSS JOIN data_end AS d
    WHERE f.first_purchase_timestamp <= DATE_SUB(d.max_purchase_timestamp, INTERVAL 180 DAY)
)
SELECT
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_180_days) AS customers_repeating_within_180_days,
    ROUND(100.0 * SUM(repeated_within_180_days) / COUNT(*), 2) AS overall_repeat_rate_180_days_percentage
FROM eligible_customers;

/* 4D.4C — CSV export */
WITH order_timestamps AS (
    SELECT c.customer_unique_id, o.order_id, o.order_purchase_timestamp
    FROM customers_model AS c
    INNER JOIN orders_model AS o ON c.customer_id = o.customer_id
    WHERE o.order_purchase_timestamp IS NOT NULL
),
ranked_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS purchase_number
    FROM order_timestamps
),
customer_first_second AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN purchase_number = 1 THEN order_purchase_timestamp END) AS first_purchase_timestamp,
        MAX(CASE WHEN purchase_number = 2 THEN order_purchase_timestamp END) AS second_purchase_timestamp
    FROM ranked_orders
    WHERE purchase_number <= 2
    GROUP BY customer_unique_id
),
data_end AS (
    SELECT MAX(order_purchase_timestamp) AS max_purchase_timestamp FROM order_timestamps
),
eligible_customers AS (
    SELECT
        f.customer_unique_id,
        f.first_purchase_timestamp,
        f.second_purchase_timestamp,
        DATE_FORMAT(f.first_purchase_timestamp, '%Y-%m') AS first_purchase_cohort,
        CASE
            WHEN f.second_purchase_timestamp IS NOT NULL
             AND f.second_purchase_timestamp >= f.first_purchase_timestamp
             AND f.second_purchase_timestamp <= DATE_ADD(f.first_purchase_timestamp, INTERVAL 180 DAY)
            THEN 1 ELSE 0
        END AS repeated_within_180_days
    FROM customer_first_second AS f
    CROSS JOIN data_end AS d
    WHERE f.first_purchase_timestamp <= DATE_SUB(d.max_purchase_timestamp, INTERVAL 180 DAY)
)
SELECT
    first_purchase_cohort,
    COUNT(*) AS eligible_customers,
    SUM(repeated_within_180_days) AS customers_repeating_within_180_days,
    COUNT(*) - SUM(repeated_within_180_days) AS customers_not_repeating_within_180_days,
    ROUND(100.0 * SUM(repeated_within_180_days) / COUNT(*), 2) AS repeat_rate_180_days_percentage
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Mission_4D_4_Cohort_180_Day_Repeat.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\r\n'
FROM eligible_customers
GROUP BY first_purchase_cohort
ORDER BY first_purchase_cohort;

/* =====================================================================
   END OF PHASE 4D SCRIPT

   Expected CSV files:
   1. Mission_4D_1_Customer_Order_Frequency.csv
   2. Mission_4D_2_Time_To_Second_Purchase.csv
   3. Mission_4D_3_Purchase_Gap_Distribution.csv
   4. Mission_4D_4_Cohort_180_Day_Repeat.csv

   Note: 4D.2 CSV contains customer-level records; 4D.1, 4D.3, and 4D.4
   contain summary tables. For Excel, import each CSV into a separate sheet.
   ===================================================================== */
   
   
   
   
/* ============================================================
   OLIST FLAGSHIP PROJECT
   PHASE 4E — CUSTOMER REVIEWS EXCEL ANALYSIS EXPORTS

   Purpose:
   Export validated review-analysis summaries from MySQL
   for Excel PivotTables, charts, and business findings.

   Source missions:
   3AE — Review-score distribution by delivery-delay band
   3AF — Written-review comments by delivery-delay band
   3AX — Review population and written-comment coverage
   3AY — Review findings by rating group

   Grain:
   Varies by export. Each section documents its grain.

   IMPORTANT:
   1. Confirm MySQL secure_file_priv before running exports.
   2. Change OUTFILE paths below to your permitted export folder.
   3. MySQL INTO OUTFILE does not overwrite existing files.
   4. These results are descriptive and do not establish causation.
   ============================================================ */


/* ============================================================
   EXPORT 4E.1 — DELIVERY DELAY VS. REVIEW-SCORE DISTRIBUTION

   Source: Mission 3AE
   Grain: One row per delivery-delay band.

   Score bands classify order-level average review scores,
   not individual review records.

   Output columns:
   delay_band, order_count, five score-band counts,
   avg_review_score_per_order
   ============================================================ */

WITH order_review_scores AS (
    -- Aggregate multiple review records to one average score
    -- per order, using only valid scores from 1 through 5.
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score
    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
    GROUP BY order_id
),

order_delivery_experience AS (
    -- Attach delivery timing to the order-level review score.
    -- DATEDIFF measures calendar-day differences.
    SELECT
        o.order_id,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate,
        r.avg_review_score
    FROM orders_model AS o
    INNER JOIN order_review_scores AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),

classified_orders AS (
    -- Classify delivered orders into consistent delay bands.
    SELECT
        order_id,
        avg_review_score,
        CASE
            WHEN days_vs_estimate <= 0
                THEN 'On time or early'
            WHEN days_vs_estimate BETWEEN 1 AND 7
                THEN '1-7 days late'
            WHEN days_vs_estimate BETWEEN 8 AND 30
                THEN '8-30 days late'
            ELSE '>30 days late'
        END AS delay_band
    FROM order_delivery_experience
)

SELECT
    delay_band,
    COUNT(*) AS order_count,

    -- Orders whose average review score falls in each band.
    SUM(CASE WHEN avg_review_score <= 1.5
             THEN 1 ELSE 0 END) AS low_score_1_orders,

    SUM(CASE WHEN avg_review_score > 1.5
                  AND avg_review_score <= 2.5
             THEN 1 ELSE 0 END) AS low_score_2_orders,

    SUM(CASE WHEN avg_review_score > 2.5
                  AND avg_review_score <= 3.5
             THEN 1 ELSE 0 END) AS mid_score_orders,

    SUM(CASE WHEN avg_review_score > 3.5
                  AND avg_review_score <= 4.5
             THEN 1 ELSE 0 END) AS high_score_orders,

    SUM(CASE WHEN avg_review_score > 4.5
             THEN 1 ELSE 0 END) AS top_score_orders,

    ROUND(AVG(avg_review_score), 2)
        AS avg_review_score_per_order

FROM classified_orders
GROUP BY delay_band
ORDER BY
    CASE delay_band
        WHEN 'On time or early' THEN 1
        WHEN '1-7 days late' THEN 2
        WHEN '8-30 days late' THEN 3
        ELSE 4
    END

INTO OUTFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/phase4e_1_delivery_vs_reviews.csv'
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';


/* ============================================================
   EXPORT 4E.2 — WRITTEN-COMMENT RATE BY DELIVERY DELAY

   Source: Mission 3AF
   Grain: One row per delivery-delay band.

   A comment is counted when a nonblank title or message exists.
   Comment presence does not establish sentiment or topic.
   ============================================================ */

WITH order_review_comments AS (
    -- Reduce review records to one written-comment indicator
    -- per order, preventing multiple reviews from multiplying
    -- the delivered-order count.
    SELECT
        order_id,
        MAX(
            CASE
                WHEN NULLIF(
                    TRIM(review_comment_message), ''
                ) IS NOT NULL
                  OR NULLIF(
                    TRIM(review_comment_title), ''
                ) IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS has_written_comment
    FROM reviews_model
    GROUP BY order_id
),

order_delivery AS (
    -- Join the order-level comment indicator to delivery dates.
    -- Orders without a matching review are treated as having
    -- no written comment for this analysis.
    SELECT
        o.order_id,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS days_vs_estimate,
        COALESCE(r.has_written_comment, 0) AS has_written_comment
    FROM orders_model AS o
    LEFT JOIN order_review_comments AS r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),

classified_orders AS (
    -- Apply the same delay bands as Mission 3AE.
    SELECT
        order_id,
        has_written_comment,
        CASE
            WHEN days_vs_estimate <= 0
                THEN 'On time or early'
            WHEN days_vs_estimate BETWEEN 1 AND 7
                THEN '1-7 days late'
            WHEN days_vs_estimate BETWEEN 8 AND 30
                THEN '8-30 days late'
            ELSE '>30 days late'
        END AS delay_band
    FROM order_delivery
)

SELECT
    delay_band,
    COUNT(*) AS total_orders,
    SUM(has_written_comment) AS orders_with_written_comments,
    SUM(1 - has_written_comment) AS orders_without_written_comments,

    ROUND(
        100.0 * SUM(has_written_comment) / COUNT(*),
        2
    ) AS written_comment_rate_pct

FROM classified_orders
GROUP BY delay_band
ORDER BY
    CASE delay_band
        WHEN 'On time or early' THEN 1
        WHEN '1-7 days late' THEN 2
        WHEN '8-30 days late' THEN 3
        ELSE 4
    END

INTO OUTFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/phase4e_2_written_comments_by_delay.csv'
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';


/* ============================================================
   EXPORT 4E.3 — REVIEW POPULATION AND COMMENT COVERAGE

   Source: Mission 3AX
   Grain: One row per rating group.

   Rating groups:
   Low: 1-2
   Middle: 3
   High: 4-5

   Invalid or missing scores remain a separate group so
   population checks are not silently discarded.
   ============================================================ */

SELECT
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        WHEN review_score BETWEEN 4 AND 5 THEN 'High score (4-5)'
        ELSE 'Invalid or missing score'
    END AS rating_group,

    COUNT(*) AS review_records,

    SUM(
        CASE
            WHEN NULLIF(TRIM(review_comment_title), '') IS NOT NULL
              OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS written_review_records,

    SUM(
        CASE
            WHEN NULLIF(TRIM(review_comment_title), '') IS NULL
             AND NULLIF(TRIM(review_comment_message), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS reviews_without_written_comments

FROM reviews_model
GROUP BY
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        WHEN review_score BETWEEN 4 AND 5 THEN 'High score (4-5)'
        ELSE 'Invalid or missing score'
    END
ORDER BY
    CASE
        WHEN rating_group = 'Low score (1-2)' THEN 1
        WHEN rating_group = 'Middle score (3)' THEN 2
        WHEN rating_group = 'High score (4-5)' THEN 3
        ELSE 4
    END

INTO OUTFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/phase4e_3_review_population.csv'
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';


/* ============================================================
   EXPORT 4E.4 — ISSUE FLAGS BY RATING GROUP

   Source: Mission 3AY
   Grain: One row per rating group.

   Issue flags use the existing exploratory keyword rules.
   The output does not treat keyword matches as verified labels.
   ============================================================ */

WITH review_base AS (
    -- Retain valid scores and identify whether written feedback
    -- exists. Combine title and message for keyword checks.
    SELECT
        review_id,
        review_score,

        (
            NULLIF(TRIM(review_comment_title), '') IS NOT NULL
            OR NULLIF(TRIM(review_comment_message), '') IS NOT NULL
        ) AS has_written_comment,

        LOWER(
            CONCAT(
                COALESCE(review_comment_title, ''),
                ' ',
                COALESCE(review_comment_message, '')
            )
        ) AS comment_text

    FROM reviews_model
    WHERE review_score BETWEEN 1 AND 5
),

classified_reviews AS (
    -- Apply the original keyword-based issue classification.
    SELECT
        review_id,
        review_score,
        has_written_comment,

        (
            has_written_comment
            AND (
                comment_text REGEXP
                'nao recebi|não recebi|nao chegou|não chegou|nao entregue|não entregue|ainda nao recebi|ainda não recebi|produto nao chegou|produto não chegou'

                OR comment_text REGEXP
                'faltou|falta de produto|item faltando|pedido incompleto|recebi.{0,30}incompleto|apenas um|apenas uma|so veio um|so veio uma|só veio um|só veio uma|veio apenas um|veio apenas uma|recebi apenas um|recebi apenas uma|somente recebi um|somente recebi uma|so recebi um|so recebi uma|só recebi um|só recebi uma|na nota consta'

                OR comment_text REGEXP
                'sem resposta|nao responde|não responde|nao retorn|não retorn|atendimento|reclama|contato|satisfacao|satisfação'

                OR comment_text REGEXP
                'defeito|quebrad|danificad|nao funciona|não funciona|mal funcionamento|qualidade ruim|baixa qualidade|falso|falsificado'
            )
        ) AS any_issue_flag

    FROM review_base
)

SELECT
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        ELSE 'High score (4-5)'
    END AS rating_group,

    COUNT(*) AS total_review_records,

    ROUND(AVG(review_score), 2) AS avg_review_score,

    SUM(has_written_comment) AS written_review_records,

    ROUND(
        100.0 * SUM(has_written_comment) / COUNT(*),
        2
    ) AS written_comment_pct,

    SUM(any_issue_flag) AS written_reviews_with_any_issue_flag,

    ROUND(
        100.0 * SUM(any_issue_flag)
        / NULLIF(SUM(has_written_comment), 0),
        2
    ) AS pct_written_reviews_with_issue_flag

FROM classified_reviews
GROUP BY
    CASE
        WHEN review_score <= 2 THEN 'Low score (1-2)'
        WHEN review_score = 3 THEN 'Middle score (3)'
        ELSE 'High score (4-5)'
    END
ORDER BY
    CASE
        WHEN rating_group = 'Low score (1-2)' THEN 1
        WHEN rating_group = 'Middle score (3)' THEN 2
        ELSE 3
    END

INTO OUTFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/phase4e_4_issue_flags_by_rating.csv'
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n';


/* ============================================================
   PHASE 4E — EXPORT CHECKLIST

   Expected files:
   1. phase4e_1_delivery_vs_reviews.csv
   2. phase4e_2_written_comments_by_delay.csv
   3. phase4e_3_review_population.csv
   4. phase4e_4_issue_flags_by_rating.csv

   After export:
   - Confirm each file exists.
   - Check headers and row counts.
   - Compare figures with the original mission outputs.
   - Build Excel charts only after validating the exports.

   No separate CSV is generated for Mission 3AZ because it
   contains documented findings and limitations rather than
   a single query result. Use it as the basis for the findings
   worksheet after the exports have been validated.
   ============================================================ */






-- ============================================================
-- Phase 4F — Mission 4F-1: Payment Method Mix
-- Objective: Measure payment-record volume and share by method.
-- Grain: One row per payment method.
-- Important: An order can use multiple payment methods.
-- Therefore, payment-record counts are not unique order counts.
-- ============================================================

SELECT
    payment_type,

    -- Number of payment records for each method.
    COUNT(*) AS payment_record_count,

    -- Total recorded payment value for each method.
    ROUND(SUM(payment_value), 2) AS total_payment_value,

    -- Average value per payment record, not per order.
    ROUND(AVG(payment_value), 2) AS avg_payment_record_value,

    -- Share of all payment records.
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS payment_record_share_pct

FROM payments_model

GROUP BY payment_type

ORDER BY SUM(payment_value) DESC;



-- ============================================================
-- Phase 4F — Mission 4F-2: Payment Installment Distribution
-- Objective: Analyze payment-record volume and value by
--            installment-count group.
-- Grain: One row per installment band.
-- Limitation: A payment record is not necessarily a unique order.
-- ============================================================

WITH installment_groups AS (
    SELECT
        CASE
            WHEN payment_installments IS NULL
                THEN 'Unknown'
            WHEN payment_installments = 1
                THEN '1 installment'
            WHEN payment_installments = 2
                THEN '2 installments'
            WHEN payment_installments BETWEEN 3 AND 6
                THEN '3–6 installments'
            WHEN payment_installments BETWEEN 7 AND 12
                THEN '7–12 installments'
            WHEN payment_installments > 12
                THEN '13+ installments'
            ELSE 'Invalid (below 1)'
        END AS installment_band,

        payment_installments,
        payment_value

    FROM payments_model
)

SELECT
    installment_band,

    COUNT(*) AS payment_record_count,

    ROUND(SUM(payment_value), 2)
        AS total_payment_value,

    ROUND(AVG(payment_value), 2)
        AS avg_payment_record_value,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS payment_record_share_pct

FROM installment_groups

GROUP BY installment_band

ORDER BY
    CASE installment_band
        WHEN '1 installment' THEN 1
        WHEN '2 installments' THEN 2
        WHEN '3–6 installments' THEN 3
        WHEN '7–12 installments' THEN 4
        WHEN '13+ installments' THEN 5
        WHEN 'Unknown' THEN 6
        ELSE 7
    END;
    
    
    
    
-- ============================================================
-- Phase 4F — Mission 4F-3: Payment Method by Installment Count
-- Objective: Compare installment patterns across payment types.
-- Grain: One row per payment type and installment band.
-- Limitation: Counts are payment records, not unique orders.
-- ============================================================

SELECT
    payment_type,

    CASE
        WHEN payment_installments IS NULL THEN 'Unknown'
        WHEN payment_installments = 1 THEN '1 installment'
        WHEN payment_installments = 2 THEN '2 installments'
        WHEN payment_installments BETWEEN 3 AND 6
            THEN '3–6 installments'
        WHEN payment_installments BETWEEN 7 AND 12
            THEN '7–12 installments'
        WHEN payment_installments > 12 THEN '13+ installments'
        ELSE 'Invalid (below 1)'
    END AS installment_band,

    COUNT(*) AS payment_record_count,

    ROUND(SUM(payment_value), 2) AS total_payment_value

FROM payments_model

GROUP BY
    payment_type,
    CASE
        WHEN payment_installments IS NULL THEN 'Unknown'
        WHEN payment_installments = 1 THEN '1 installment'
        WHEN payment_installments = 2 THEN '2 installments'
        WHEN payment_installments BETWEEN 3 AND 6
            THEN '3–6 installments'
        WHEN payment_installments BETWEEN 7 AND 12
            THEN '7–12 installments'
        WHEN payment_installments > 12 THEN '13+ installments'
        ELSE 'Invalid (below 1)'
    END

ORDER BY
    payment_type,
    CASE installment_band
        WHEN '1 installment' THEN 1
        WHEN '2 installments' THEN 2
        WHEN '3–6 installments' THEN 3
        WHEN '7–12 installments' THEN 4
        WHEN '13+ installments' THEN 5
        WHEN 'Unknown' THEN 6
        ELSE 7
    END;





-- ============================================================
-- Phase 4G-1: Individual Seller Performance
-- Objective: Measure seller activity and item-level sales.
-- Grain: One row per seller.
-- Important: price is item sales value, not profit or
--            reconciled order-level payment revenue.
-- ============================================================


-- ============================================================
-- Phase 4G-1: Individual Seller Performance
-- Objective: Measure seller activity and item-level sales.
-- Grain: One row per seller.
-- Important: price is item sales value, not profit or
--            reconciled order-level payment revenue.
-- ============================================================

USE olist_analytics;

SELECT
    seller_id,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) AS order_item_records,
    ROUND(SUM(price), 2) AS total_item_sales,
    ROUND(AVG(price), 2) AS avg_item_price,
    ROUND(
        100.0 * SUM(price) /
        SUM(SUM(price)) OVER (),
        2
    ) AS sales_share_pct
FROM order_items_model
GROUP BY seller_id
ORDER BY SUM(price) DESC;



-- ============================================================
-- Mission 4G-7: Individual Seller Delivery Performance
-- Objective: Compare delivery outcomes for orders associated
--            with each seller.
-- Grain: One row per seller.
-- Important: An order with multiple sellers is counted once
--            for each seller associated with that order.
-- ============================================================

WITH seller_orders AS (
    SELECT DISTINCT
        seller_id,
        order_id
    FROM olist_analytics.order_items_model
),
seller_delivery AS (
    SELECT
        so.seller_id,
        so.order_id,
        o.order_status,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM seller_orders AS so
    INNER JOIN olist_analytics.orders_model AS o
        ON so.order_id = o.order_id
)
SELECT
    seller_id,
    COUNT(*) AS associated_orders,
    SUM(
        CASE
            WHEN order_status = 'delivered' THEN 1
            ELSE 0
        END
    ) AS delivered_orders,
    SUM(
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date >
                 order_estimated_delivery_date
            THEN 1
            ELSE 0
        END
    ) AS late_delivered_orders,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN order_status = 'delivered'
                 AND order_delivered_customer_date IS NOT NULL
                 AND order_estimated_delivery_date IS NOT NULL
                 AND order_delivered_customer_date >
                     order_estimated_delivery_date
                THEN 1
                ELSE 0
            END
        ) / NULLIF(
            SUM(
                CASE
                    WHEN order_status = 'delivered' THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS late_delivery_rate_pct
FROM seller_delivery
GROUP BY seller_id
ORDER BY late_delivery_rate_pct DESC;


