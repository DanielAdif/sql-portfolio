"""
seed.py — Generate the ecommerce.db SQLite dataset.
Run once: python data/seed.py
"""

import sqlite3
import random
from datetime import date, timedelta
from pathlib import Path

DB_PATH = Path(__file__).parent / "ecommerce.db"

def main():
    if DB_PATH.exists():
        DB_PATH.unlink()

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.executescript("""
    CREATE TABLE customers (
        customer_id  INTEGER PRIMARY KEY,
        name         TEXT NOT NULL,
        email        TEXT NOT NULL,
        country      TEXT NOT NULL,
        signup_date  TEXT NOT NULL,
        segment      TEXT NOT NULL          -- retail | wholesale | enterprise
    );

    CREATE TABLE products (
        product_id  INTEGER PRIMARY KEY,
        name        TEXT NOT NULL,
        category    TEXT NOT NULL,
        price       REAL NOT NULL,
        cost        REAL NOT NULL
    );

    CREATE TABLE orders (
        order_id          INTEGER PRIMARY KEY,
        customer_id       INTEGER NOT NULL REFERENCES customers(customer_id),
        order_date        TEXT NOT NULL,
        status            TEXT NOT NULL,    -- completed | cancelled | processing
        shipping_country  TEXT NOT NULL
    );

    CREATE TABLE order_items (
        item_id     INTEGER PRIMARY KEY,
        order_id    INTEGER NOT NULL REFERENCES orders(order_id),
        product_id  INTEGER NOT NULL REFERENCES products(product_id),
        quantity    INTEGER NOT NULL,
        unit_price  REAL NOT NULL
    );

    CREATE TABLE returns (
        return_id   INTEGER PRIMARY KEY,
        order_id    INTEGER NOT NULL REFERENCES orders(order_id),
        reason      TEXT NOT NULL,
        return_date TEXT NOT NULL
    );
    """)

    # ── seed parameters ──────────────────────────────────────────────────────
    random.seed(42)

    COUNTRIES      = ["US", "UK", "Canada", "Germany", "Australia", "France", "Indonesia", "Singapore"]
    SEGMENTS       = ["retail", "wholesale", "enterprise"]
    CATEGORIES     = ["Electronics", "Apparel", "Home & Garden", "Sports", "Books", "Beauty"]
    RETURN_REASONS = ["Damaged", "Wrong item", "Changed mind", "Not as described"]
    STATUSES       = ["completed", "completed", "completed", "cancelled", "processing"]

    # ── products ─────────────────────────────────────────────────────────────
    products = []
    for i in range(1, 51):
        price = round(random.uniform(10, 500), 2)
        cost  = round(price * random.uniform(0.30, 0.70), 2)
        products.append((i, f"Product {i}", random.choice(CATEGORIES), price, cost))
    c.executemany("INSERT INTO products VALUES (?,?,?,?,?)", products)

    # ── customers ────────────────────────────────────────────────────────────
    base = date(2021, 1, 1)
    customers = []
    for i in range(1, 301):
        signup = base + timedelta(days=random.randint(0, 1095))
        customers.append((
            i, f"Customer {i}", f"cust{i}@email.com",
            random.choice(COUNTRIES), str(signup), random.choice(SEGMENTS)
        ))
    c.executemany("INSERT INTO customers VALUES (?,?,?,?,?,?)", customers)

    # ── orders, items, returns ───────────────────────────────────────────────
    order_id = 1; item_id = 1; return_id = 1
    orders_rows = []; items_rows = []; return_rows = []

    for cust in customers:
        cid    = cust[0]
        signup = date.fromisoformat(cust[4])

        for _ in range(random.randint(0, 12)):
            odate  = signup + timedelta(days=random.randint(1, 900))
            if odate > date(2023, 12, 31):
                odate = date(2023, 12, 31)
            status = random.choice(STATUSES)
            orders_rows.append((order_id, cid, str(odate), status, cust[3]))

            for _ in range(random.randint(1, 5)):
                prod = random.choice(products)
                items_rows.append((item_id, order_id, prod[0], random.randint(1, 4), prod[3]))
                item_id += 1

            if status == "completed" and random.random() < 0.12:
                rdate = odate + timedelta(days=random.randint(2, 30))
                return_rows.append((return_id, order_id, random.choice(RETURN_REASONS), str(rdate)))
                return_id += 1

            order_id += 1

    c.executemany("INSERT INTO orders VALUES (?,?,?,?,?)", orders_rows)
    c.executemany("INSERT INTO order_items VALUES (?,?,?,?,?)", items_rows)
    c.executemany("INSERT INTO returns VALUES (?,?,?,?)", return_rows)
    conn.commit()

    # ── summary ──────────────────────────────────────────────────────────────
    print(f"Database created: {DB_PATH}")
    for tbl in ["customers", "products", "orders", "order_items", "returns"]:
        n = c.execute(f"SELECT COUNT(*) FROM {tbl}").fetchone()[0]
        print(f"  {tbl:<15} {n:>6} rows")

    conn.close()

if __name__ == "__main__":
    main()
