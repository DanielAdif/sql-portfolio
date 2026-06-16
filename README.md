# SQL Business Analytics Portfolio

A self-contained, end-to-end SQL portfolio project demonstrating business intelligence skills using a synthetic e-commerce dataset. Every query answers a real business question and showcases a different SQL technique.

---

## Project structure

```
sql-portfolio/
├── data/
│   ├── seed.py          ← generates ecommerce.db (run once)
│   ├── schema.sql       ← table definitions + comments
│   └── ecommerce.db     ← SQLite database (git-ignored by default)
├── queries/
│   ├── q01_revenue_by_category.sql
│   ├── q02_monthly_revenue_trend.sql
│   └── q03_to_q10_business_queries.sql
├── results/
│   └── query_results.json   ← raw output captured from each query
└── README.md
```

---

## Dataset

Five tables, ~7,300 rows total, spanning 2021–2023.

| Table | Rows | Description |
|---|---|---|
| `customers` | 300 | Name, country, signup date, segment |
| `products` | 50 | Name, category, price, cost |
| `orders` | ~1,710 | Per-customer orders with status |
| `order_items` | ~5,176 | Line-items linking orders to products |
| `returns` | ~122 | Returned orders with reason |

**Schema diagram:**

```
customers ──< orders ──< order_items >── products
                │
              returns
```

---

## Entity-Relationship Diagram

## Tables and relationships

```
┌─────────────────┐         ┌─────────────────┐
│   customers     │         │    products      │
│─────────────────│         │─────────────────│
│ customer_id PK  │         │ product_id PK   │
│ name            │         │ name            │
│ email           │         │ category        │
│ country         │         │ price           │
│ signup_date     │         │ cost            │
│ segment         │         └────────┬────────┘
└────────┬────────┘                  │
         │ 1                         │
         │                           │ 1
         ▼ N                         ▼ N
┌─────────────────┐         ┌─────────────────┐
│    orders       │◄────────│  order_items    │
│─────────────────│    N    │─────────────────│
│ order_id PK     │         │ item_id PK      │
│ customer_id FK  │         │ order_id FK     │
│ order_date      │         │ product_id FK   │
│ status          │         │ quantity        │
│ shipping_country│         │ unit_price      │
└────────┬────────┘         └─────────────────┘
         │ 1
         │
         ▼ N
┌─────────────────┐
│    returns      │
│─────────────────│
│ return_id PK    │
│ order_id FK     │
│ reason          │
│ return_date     │
└─────────────────┘
```

## Cardinality

| Relationship | Type |
|---|---|
| customers → orders | One-to-many (a customer can place many orders) |
| orders → order_items | One-to-many (an order has many line items) |
| products → order_items | One-to-many (a product can appear in many orders) |
| orders → returns | One-to-one (at most one return per order in this model) |

## Key design decisions

- `unit_price` on `order_items` captures the price *at time of purchase*, decoupled from the current `products.price`. This allows historical revenue analysis to be accurate even after price changes.
- `shipping_country` on `orders` may differ from `customers.country` (international buyers, gift orders).
- `status` on `orders` distinguishes revenue-generating orders (`completed`) from noise (`cancelled`, `processing`). All revenue queries filter `WHERE status = 'completed'`.

---

## Business questions & techniques

| # | Business question | SQL techniques |
|---|---|---|
| Q1 | Which category generates the most revenue *and* profit? | `JOIN`, `GROUP BY`, `RANK()` |
| Q2 | What is the month-over-month revenue trend? | CTE, `LAG()`, date formatting |
| Q3 | How does LTV distribute across customer segments? | Multi-CTE chain, `NTILE()` |
| Q4 | Who are the top 20 customers and what is their cumulative revenue share? | `ROW_NUMBER()`, cumulative `SUM()` |
| Q5 | Which product categories have the highest return rates? | Two CTEs, `LEFT JOIN`, `COALESCE`, `RANK()` |
| Q6 | Which countries grew fastest year-over-year? | `CASE`-based pivot, `NULLIF` safe division |
| Q7 | What share of revenue comes from repeat vs one-time buyers? | `CASE` labelling, `SUM() OVER PARTITION` |
| Q8 | What is the average basket size by country and segment? | Multi-metric aggregation, `HAVING` |
| Q9 | What does cohort retention look like for 2022 cohorts? | Self-referencing CTEs, retention % |
| Q10 | What are the top 3 products within each category? | `DENSE_RANK() OVER PARTITION BY` |

### Answers
- Q1: Beauty leads on raw revenue but Books wins on margin (54.4%). Wholesale strategy should prioritise Books for highest profit-per-dollar.
- Q2: Revenue grows organically through 2021-2023 with high volatility in early months (small base effect). By 2023, monthly revenue stabilised at  around 30-40k with single-digit MoM swings — a sign of business maturity.
- Q3: Enterprise Q4 customers average 6.8 orders and around $12k LTV 8x higher than Q1. Retention programs should target Q2–Q3 customers to push them into the top quartile.
- Q4: Top 20 customers (~6.7% of base) account for roughly 22% of total revenue — a mild Pareto effect. All top 3 are wholesale segment, confirming wholesale accounts need priority account management.
- Q5: Electronics has the highest return rate (13%), expected given complexity and expectation mismatch. Beauty is the lowest, suggesting strong product descriptions. Investigate Electronics listings for accuracy improvements.
- Q6: Germany (+389%) and Singapore (+332%) are the fastest-growing markets despite smaller absolute bases — prime candidates for localised marketing investment.
- Q7: Repeat buyers drive 96% of enterprise revenue but generate 4.7x the revenue per customer vs one-time buyers. Acquisition cost is only justified if the customer converts to repeat — focus churn prevention on customers after their first order.
- Q8: US wholesale leads with $2,091 average order value. Enterprise customers in Germany and UK have high basket sizes despite fewer orders high-value, low-frequency buyers who need VIP treatment.
- Q9: Retention drops sharply after the first month (~20-40% by month 3). The Jan 2022 cohort shows a retention spike at month 6. Cohort analysis like this should drive email flow design.
- Q10: Top performers in each category are high-priced items ($350-$400), validating the premium pricing strategy. However, margin varies widely (48-58%) within the same category — a signal to review cost structures on lower-margin top sellers.

---

## Key findings

### Revenue & profitability
- **Beauty** leads on raw revenue ($409k) but **Books** has the highest margin (54.4%), making it the most profitable category per dollar sold.
- Top 3 revenue-generating products in every category are priced $350–$400, validating the premium pricing strategy.

### Customer behaviour
- **Repeat buyers drive 96% of enterprise segment revenue** and generate 4.7× more revenue per customer than one-time buyers — acquisition only pays off if the customer comes back.
- Top 20 customers (~6.7% of the base) account for ~22% of total revenue. All top 3 are wholesale, confirming wholesale accounts deserve priority treatment.

### Growth & market expansion
- **Germany (+389% YoY)** and **Singapore (+332% YoY)** are the fastest-growing markets despite smaller absolute bases — strong signals for localised marketing investment.
- Revenue matured from high-volatility early months (small base effect) to stable $30–40k/month by late 2023.

### Returns & risk
- **Electronics has the highest return rate (13%)**, likely driven by expectation mismatch. Improving product descriptions and spec accuracy is the lowest-cost intervention.
- Cohort retention drops sharply after month 1 (~20–40% by month 3), which is typical for e-commerce but highlights the need for post-purchase engagement flows.

---

## SQL patterns demonstrated

```sql
-- Window function: running total + cumulative share
SUM(revenue) OVER (
    ORDER BY revenue DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS running_total

-- Window function: customer LTV quartiles
NTILE(4) OVER (ORDER BY lifetime_revenue) AS ltv_quartile

-- Window function: rank within group
DENSE_RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rank_in_category

-- CTE chain: build up logic step by step
WITH base AS (...),
     enriched AS (SELECT * FROM base JOIN ...),
     summary  AS (SELECT ... FROM enriched GROUP BY ...)
SELECT * FROM summary;

-- MoM growth using LAG
LAG(revenue) OVER (ORDER BY month) AS prev_revenue

-- Safe division
100.0 * numerator / NULLIF(denominator, 0)

-- CASE-based pivot (year columns)
SUM(CASE WHEN year = '2022' THEN revenue ELSE 0 END) AS rev_2022
```


---

## Tech stack

| Tool | Role |
|---|---|
| Python 3 (stdlib) | Data generation (`seed.py`) |
| SQLite 3 | Database engine |
| SQL | All analytics |
| Git / GitHub | Version control & portfolio hosting |


---

## Author

**Daniel Adif Nugroho** 
