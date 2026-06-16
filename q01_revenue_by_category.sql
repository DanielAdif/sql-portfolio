-- ============================================================
-- Q1: Which product category generates the most revenue and profit?
-- Techniques: JOIN, GROUP BY, window functions (RANK)
-- ============================================================

WITH category_metrics AS (
    SELECT
        p.category,
        COUNT(DISTINCT oi.item_id)                          AS units_sold,
        SUM(oi.quantity * oi.unit_price)                    AS gross_revenue,
        SUM(oi.quantity * p.cost)                           AS total_cost,
        SUM(oi.quantity * (oi.unit_price - p.cost))         AS gross_profit
    FROM order_items oi
    JOIN products    p  ON p.product_id = oi.product_id
    JOIN orders      o  ON o.order_id   = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY p.category
)
SELECT
    category,
    units_sold,
    ROUND(gross_revenue, 2)                                 AS gross_revenue,
    ROUND(total_cost,    2)                                 AS total_cost,
    ROUND(gross_profit,  2)                                 AS gross_profit,
    ROUND(100.0 * gross_profit / gross_revenue, 1)          AS margin_pct,
    RANK() OVER (ORDER BY gross_revenue DESC)               AS revenue_rank,
    RANK() OVER (ORDER BY gross_profit  DESC)               AS profit_rank
FROM category_metrics
ORDER BY gross_revenue DESC;

