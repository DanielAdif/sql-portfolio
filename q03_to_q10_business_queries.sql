-- ============================================================
-- Q3: What is the LTV distribution across customer segments?
-- Techniques: multi-CTE chain, NTILE() window function
-- ============================================================

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.segment,
        c.country,
        COUNT(DISTINCT o.order_id)           AS total_orders,
        SUM(oi.quantity * oi.unit_price)     AS lifetime_revenue,
        MIN(o.order_date)                    AS first_order,
        MAX(o.order_date)                    AS last_order
    FROM customers   c
    JOIN orders      o  ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.segment, c.country
),
percentiles AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY lifetime_revenue)  AS ltv_quartile
    FROM customer_revenue
)
SELECT
    segment,
    ltv_quartile,
    COUNT(*)                        AS customer_count,
    ROUND(AVG(lifetime_revenue), 2) AS avg_ltv,
    ROUND(MIN(lifetime_revenue), 2) AS min_ltv,
    ROUND(MAX(lifetime_revenue), 2) AS max_ltv,
    ROUND(AVG(total_orders),     1) AS avg_orders
FROM percentiles
GROUP BY segment, ltv_quartile
ORDER BY segment, ltv_quartile;



-- ============================================================
-- Q4: Top 20 customers by revenue with cumulative share
-- Techniques: ROW_NUMBER, SUM() cumulative window, pct calculations
-- ============================================================

WITH customer_rev AS (
    SELECT
        c.customer_id,
        c.name,
        c.segment,
        c.country,
        ROUND(SUM(oi.quantity * oi.unit_price), 2)  AS total_revenue
    FROM customers   c
    JOIN orders      o  ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.name, c.segment, c.country
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC)  AS rank,
        SUM(total_revenue) OVER ()                       AS grand_total,
        SUM(total_revenue) OVER (
            ORDER BY total_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                AS running_total
    FROM customer_rev
)
SELECT
    rank,
    name,
    segment,
    country,
    total_revenue,
    ROUND(100.0 * total_revenue / grand_total,  1)  AS pct_of_total,
    ROUND(100.0 * running_total  / grand_total, 1)  AS cumulative_pct
FROM ranked
WHERE rank <= 20
ORDER BY rank;



-- ============================================================
-- Q5: Which product categories have the highest return rates?
-- Techniques: two CTEs, LEFT JOIN, COALESCE, window RANK
-- ============================================================

WITH completed_items AS (
    SELECT
        p.category,
        COUNT(DISTINCT o.order_id)  AS completed_orders
    FROM order_items oi
    JOIN products p  ON p.product_id = oi.product_id
    JOIN orders   o  ON o.order_id   = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY p.category
),
returned_items AS (
    SELECT
        p.category,
        COUNT(DISTINCT r.order_id)  AS returned_orders
    FROM returns     r
    JOIN orders      o  ON o.order_id   = r.order_id
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products    p  ON p.product_id = oi.product_id
    GROUP BY p.category
)
SELECT
    ci.category,
    ci.completed_orders,
    COALESCE(ri.returned_orders, 0)                                              AS returned_orders,
    ROUND(100.0 * COALESCE(ri.returned_orders, 0) / ci.completed_orders, 2)     AS return_rate_pct,
    RANK() OVER (
        ORDER BY 100.0 * COALESCE(ri.returned_orders, 0) / ci.completed_orders DESC
    )                                                                            AS return_rank
FROM completed_items ci
LEFT JOIN returned_items ri ON ri.category = ci.category
ORDER BY return_rate_pct DESC;



-- ============================================================
-- Q6: Which countries showed strongest YoY revenue growth?
-- Techniques: CASE-based pivot, NULLIF for safe division
-- ============================================================

WITH yearly AS (
    SELECT
        o.shipping_country                        AS country,
        STRFTIME('%Y', o.order_date)              AS year,
        SUM(oi.quantity * oi.unit_price)          AS revenue
    FROM orders      o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
      AND STRFTIME('%Y', o.order_date) IN ('2022', '2023')
    GROUP BY country, year
),
pivot AS (
    SELECT
        country,
        SUM(CASE WHEN year = '2022' THEN revenue ELSE 0 END)  AS rev_2022,
        SUM(CASE WHEN year = '2023' THEN revenue ELSE 0 END)  AS rev_2023
    FROM yearly
    GROUP BY country
)
SELECT
    country,
    ROUND(rev_2022, 2)                                              AS rev_2022,
    ROUND(rev_2023, 2)                                              AS rev_2023,
    ROUND(rev_2023 - rev_2022, 2)                                   AS abs_growth,
    ROUND(100.0 * (rev_2023 - rev_2022) / NULLIF(rev_2022, 0), 1)  AS yoy_growth_pct
FROM pivot
WHERE rev_2022 > 0
ORDER BY yoy_growth_pct DESC;



-- ============================================================
-- Q7: Repeat vs one-time buyer revenue share by segment
-- Techniques: CASE labelling, SUM() OVER PARTITION, pct of group
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_id,
        c.segment,
        COUNT(DISTINCT o.order_id)        AS order_count,
        SUM(oi.quantity * oi.unit_price)  AS revenue
    FROM customers   c
    JOIN orders      o  ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.segment
),
labelled AS (
    SELECT *,
        CASE WHEN order_count = 1 THEN 'one-time' ELSE 'repeat' END  AS buyer_type
    FROM customer_orders
)
SELECT
    segment,
    buyer_type,
    COUNT(*)                         AS customer_count,
    ROUND(SUM(revenue), 2)           AS total_revenue,
    ROUND(AVG(revenue), 2)           AS avg_revenue_per_customer,
    ROUND(
        100.0 * SUM(revenue)
        / SUM(SUM(revenue)) OVER (PARTITION BY segment), 1
    )                                AS pct_of_segment_revenue
FROM labelled
GROUP BY segment, buyer_type
ORDER BY segment, buyer_type;



-- ============================================================
-- Q8: Average basket size by country × segment
-- Techniques: aggregated JOIN, HAVING filter, multi-metric summary
-- ============================================================

WITH order_totals AS (
    SELECT
        o.order_id,
        o.shipping_country                    AS country,
        c.segment,
        COUNT(oi.item_id)                     AS line_items,
        SUM(oi.quantity)                      AS total_units,
        SUM(oi.quantity * oi.unit_price)      AS order_value
    FROM orders      o
    JOIN customers   c  ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.shipping_country, c.segment
)
SELECT
    country,
    segment,
    COUNT(order_id)              AS order_count,
    ROUND(AVG(line_items),  2)   AS avg_line_items,
    ROUND(AVG(total_units), 2)   AS avg_units,
    ROUND(AVG(order_value), 2)   AS avg_order_value,
    ROUND(MAX(order_value), 2)   AS max_order_value
FROM order_totals
GROUP BY country, segment
HAVING COUNT(order_id) >= 5
ORDER BY avg_order_value DESC;



-- ============================================================
-- Q9: Cohort retention for H1 2022 customer cohorts
-- Techniques: self-referencing CTEs, cohort date math, retention %
-- ============================================================

WITH first_orders AS (
    SELECT
        customer_id,
        MIN(STRFTIME('%Y-%m', order_date))  AS cohort_month
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
),
order_months AS (
    SELECT
        o.customer_id,
        STRFTIME('%Y-%m', o.order_date)     AS order_month
    FROM orders o
    WHERE status = 'completed'
),
cohort_data AS (
    SELECT
        f.cohort_month,
        om.order_month,
        COUNT(DISTINCT om.customer_id)       AS active_customers
    FROM first_orders f
    JOIN order_months om ON om.customer_id = f.customer_id
    WHERE f.cohort_month BETWEEN '2022-01' AND '2022-06'
    GROUP BY f.cohort_month, om.order_month
),
cohort_size AS (
    SELECT cohort_month, active_customers  AS cohort_size
    FROM cohort_data
    WHERE cohort_month = order_month
)
SELECT
    cd.cohort_month,
    cs.cohort_size,
    cd.order_month,
    cd.active_customers,
    ROUND(100.0 * cd.active_customers / cs.cohort_size, 1)  AS retention_pct
FROM cohort_data cd
JOIN cohort_size cs ON cs.cohort_month = cd.cohort_month
ORDER BY cd.cohort_month, cd.order_month;



-- ============================================================
-- Q10: Top 3 products by revenue within each category
-- Techniques: DENSE_RANK() OVER PARTITION, margin calculation
-- ============================================================

WITH product_revenue AS (
    SELECT
        p.category,
        p.name                                        AS product_name,
        p.price,
        SUM(oi.quantity)                              AS units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price), 2)    AS total_revenue,
        ROUND(SUM(oi.quantity * (oi.unit_price - p.cost)), 2) AS total_profit
    FROM products    p
    JOIN order_items oi ON oi.product_id = p.product_id
    JOIN orders      o  ON o.order_id    = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY p.category, p.product_id, p.name, p.price
),
ranked AS (
    SELECT *,
        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY total_revenue DESC
        )  AS rank_in_category
    FROM product_revenue
)
SELECT
    category,
    rank_in_category,
    product_name,
    price,
    units_sold,
    total_revenue,
    total_profit,
    ROUND(100.0 * total_profit / NULLIF(total_revenue, 0), 1)  AS margin_pct
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

