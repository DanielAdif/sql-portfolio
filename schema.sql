-- ============================================================
-- E-Commerce Analytics — SQLite Schema
-- ============================================================

CREATE TABLE customers (
    customer_id  INTEGER PRIMARY KEY,
    name         TEXT NOT NULL,
    email        TEXT NOT NULL,
    country      TEXT NOT NULL,          -- US | UK | Canada | Germany | Australia | France | Indonesia | Singapore
    signup_date  TEXT NOT NULL,          -- ISO 8601: YYYY-MM-DD
    segment      TEXT NOT NULL           -- retail | wholesale | enterprise
);

CREATE TABLE products (
    product_id  INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    category    TEXT NOT NULL,           -- Electronics | Apparel | Home & Garden | Sports | Books | Beauty
    price       REAL NOT NULL,           -- selling price
    cost        REAL NOT NULL            -- cost of goods
);

CREATE TABLE orders (
    order_id          INTEGER PRIMARY KEY,
    customer_id       INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date        TEXT NOT NULL,     -- ISO 8601: YYYY-MM-DD
    status            TEXT NOT NULL,     -- completed | cancelled | processing
    shipping_country  TEXT NOT NULL
);

CREATE TABLE order_items (
    item_id     INTEGER PRIMARY KEY,
    order_id    INTEGER NOT NULL REFERENCES orders(order_id),
    product_id  INTEGER NOT NULL REFERENCES products(product_id),
    quantity    INTEGER NOT NULL,
    unit_price  REAL NOT NULL            -- price at time of purchase
);

CREATE TABLE returns (
    return_id   INTEGER PRIMARY KEY,
    order_id    INTEGER NOT NULL REFERENCES orders(order_id),
    reason      TEXT NOT NULL,           -- Damaged | Wrong item | Changed mind | Not as described
    return_date TEXT NOT NULL            -- ISO 8601: YYYY-MM-DD
);

-- ── Quick reference: row counts after seeding ───────────────
-- customers   : 300
-- products    :  50
-- orders      : ~1710
-- order_items : ~5176
-- returns     : ~122
