-- ============================================================
-- Q2: What is the month-over-month revenue trend?
-- Techniques: CTE, LAG() window function, date formatting
-- ============================================================

WITH monthly AS (
    SELECT
        STRFTIME('%Y-%m', o.order_date)          AS month,
        SUM(oi.quantity * oi.unit_price)          AS revenue
    FROM orders      o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
    GROUP BY month
),
with_lag AS (
    SELECT
        month,
        ROUND(revenue, 2)                                           AS revenue,
        LAG(revenue) OVER (ORDER BY month)                          AS prev_revenue
    FROM monthly
)
SELECT
    month,
    revenue,
    ROUND(prev_revenue, 2)                                          AS prev_month_revenue,
    ROUND(100.0 * (revenue - prev_revenue) / prev_revenue, 1)      AS mom_growth_pct
FROM with_lag
ORDER BY month;
