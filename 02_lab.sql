-- =====================================================================
-- ADVANCED SQL FOR DATA ENGINEERS - 02 LAB (90 minutes)
-- Run 01_setup.sql first.
--
-- How to run in Workbench:
--   Ctrl+Enter        runs the statement under the cursor
--   Ctrl+Shift+Enter  runs the selected block (or the whole file)
-- Work top to bottom. Each block is short on purpose - run it, read
-- the result, then move on.
--
-- Blocks marked [CORE] are run live. Blocks marked [IF TIME] can be
-- skipped and left as take-home reading.
-- =====================================================================

USE de_sql_lab;
SET SQL_SAFE_UPDATES = 0;   -- Workbench blocks UPDATEs without a key column otherwise


-- #####################################################################
-- PART 1  DATABASE DESIGN AND MODELLING                    (0:05-0:25)
-- #####################################################################

-- ---------------------------------------------------------------------
-- 1.1 [CORE] Look at the raw data
-- Ask: what is repeated here? What happens if a customer moves city?
-- ---------------------------------------------------------------------
SELECT * FROM orders_raw ORDER BY order_id;

-- Priya's name and city are stored once per order LINE
SELECT customer_id, customer_name, customer_city,
       COUNT(*) AS times_stored
FROM   orders_raw
GROUP  BY customer_id, customer_name, customer_city
ORDER  BY times_stored DESC;

-- ---------------------------------------------------------------------
-- 1.2 [CORE] Update anomaly - see it, then undo it
-- Priya moves to Noida. Someone updates only one order. Now the data
-- disagrees with itself.
-- ---------------------------------------------------------------------
START TRANSACTION;

UPDATE orders_raw
SET    customer_city = 'Noida'
WHERE  order_id = 1001;            -- forgot her other orders

SELECT DISTINCT customer_id, customer_name, customer_city
FROM   orders_raw
WHERE  customer_id = 'C101';      -- two cities for one person

ROLLBACK;                          -- put it back

-- ---------------------------------------------------------------------
-- 1.3 [CORE] Normalise to 3NF (logical design -> physical design)
--
-- Dependencies we found in the raw table:
--   order_id        -> order_date, customer_id
--   customer_id     -> customer_name, customer_city
--   customer_city   -> city_region          (transitive - breaks 3NF)
--   product_code    -> product_name, category
--   (order_id, product_code) -> qty, unit_price
--
-- Each dependency gets its own table. Physical design choices made
-- here: data types, PRIMARY KEY, FOREIGN KEY, NOT NULL, CHECK, index.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS order_items, orders, products, customers, cities;

CREATE TABLE cities (
    city    VARCHAR(30) PRIMARY KEY,
    region  VARCHAR(10) NOT NULL
);

CREATE TABLE customers (
    customer_id    VARCHAR(10) PRIMARY KEY,
    customer_name  VARCHAR(50) NOT NULL,
    city           VARCHAR(30) NOT NULL,
    FOREIGN KEY (city) REFERENCES cities(city)
);

CREATE TABLE products (
    product_code  VARCHAR(10) PRIMARY KEY,
    product_name  VARCHAR(50) NOT NULL,
    category      VARCHAR(20) NOT NULL,
    list_price    DECIMAL(10,2) NOT NULL
);

CREATE TABLE orders (
    order_id     INT PRIMARY KEY,
    order_date   DATE NOT NULL,
    customer_id  VARCHAR(10) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_orders_date (order_date)       -- we filter by date a lot
);

CREATE TABLE order_items (
    order_id      INT,
    product_code  VARCHAR(10),
    qty           INT NOT NULL CHECK (qty > 0),
    unit_price    DECIMAL(10,2) NOT NULL,     -- price AT TIME OF SALE, not a duplicate of list_price
    PRIMARY KEY (order_id, product_code),     -- composite key
    FOREIGN KEY (order_id)     REFERENCES orders(order_id),
    FOREIGN KEY (product_code) REFERENCES products(product_code)
);

-- Load the new tables from the raw table (parents first, then children)
INSERT INTO cities
SELECT DISTINCT customer_city, city_region FROM orders_raw;

INSERT INTO customers
SELECT DISTINCT customer_id, customer_name, customer_city FROM orders_raw;

INSERT INTO products
SELECT product_code, product_name, category, MAX(unit_price)
FROM   orders_raw
GROUP  BY product_code, product_name, category;

INSERT INTO orders
SELECT DISTINCT order_id, order_date, customer_id FROM orders_raw;

INSERT INTO order_items
SELECT order_id, product_code, qty, unit_price FROM orders_raw;

-- Records that could not exist in the raw table (insert anomaly solved):
-- a customer and products with no orders yet
INSERT INTO customers VALUES ('C108','Karan Mehta','Delhi'),
                             ('C109','Fatima Khan','Mumbai');
INSERT INTO products  VALUES ('P09','Webcam HD','Electronics',2500),
                             ('P10','Filing Cabinet','Furniture',6000);

-- Reconcile: nothing lost in the move (always do this in a pipeline)
SELECT (SELECT SUM(qty*unit_price) FROM orders_raw)  AS raw_revenue,
       (SELECT SUM(qty*unit_price) FROM order_items) AS model_revenue;

-- The constraints now protect the data. Run this - it SHOULD fail:
-- INSERT INTO orders VALUES (9999,'2026-07-01','C999');

-- ---------------------------------------------------------------------
-- 1.4 [CORE] See the ER diagram
-- Workbench menu: Database > Reverse Engineer > pick de_sql_lab >
-- tick the tables > Execute. Read the crow's feet:
--   one customer  -> many orders
--   one order     -> many order_items
--   one product   -> many order_items
-- order_items resolves the many-to-many between orders and products.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 1.5 [CORE] Denormalise for reporting
-- Normalised = good for writing data. Reports need joins every time.
-- So data engineers build a wide, read-friendly table on top.
-- We use it in Parts 2 and 3.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS sales_report;

CREATE TABLE sales_report AS
SELECT o.order_id,
       o.order_date,
       DATE_FORMAT(o.order_date,'%Y-%m') AS order_month,
       c.customer_id,
       c.customer_name,
       c.city,
       ci.region,
       p.product_code,
       p.product_name,
       p.category,
       oi.qty,
       oi.unit_price,
       oi.qty * oi.unit_price            AS line_amount
FROM   orders o
JOIN   customers   c  ON c.customer_id   = o.customer_id
JOIN   cities      ci ON ci.city         = c.city
JOIN   order_items oi ON oi.order_id     = o.order_id
JOIN   products    p  ON p.product_code  = oi.product_code;

SELECT * FROM sales_report ORDER BY order_id LIMIT 10;


-- #####################################################################
-- PART 2  ADVANCED SQL FUNCTIONS                            (0:25-0:55)
-- #####################################################################

-- ---------------------------------------------------------------------
-- 2.1 [CORE] GROUP BY vs window function
-- GROUP BY squashes rows. OVER() keeps every row and adds a column.
-- ---------------------------------------------------------------------
SELECT dept_id, AVG(salary) AS dept_avg
FROM   employees
GROUP  BY dept_id;                         -- 5 rows, names gone

SELECT emp_name, dept_id, salary,
       ROUND(AVG(salary) OVER (PARTITION BY dept_id)) AS dept_avg,
       salary - ROUND(AVG(salary) OVER (PARTITION BY dept_id)) AS vs_avg
FROM   employees
ORDER  BY dept_id, salary DESC;            -- 14 rows, names kept

-- ---------------------------------------------------------------------
-- 2.2 [CORE] ROW_NUMBER vs RANK vs DENSE_RANK
-- Watch Pooja and Nikhil - same salary. ROW_NUMBER picks one of them
-- at random to be 4th; add a tie-breaker (ORDER BY salary DESC, emp_id)
-- whenever the result must be repeatable, e.g. in a pipeline.
-- ---------------------------------------------------------------------
SELECT emp_name, dept_id, salary,
       ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS row_num,
       RANK()       OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS dense_rnk
FROM   employees
WHERE  dept_id = 2;

-- ---------------------------------------------------------------------
-- 2.3 [CORE] Top-N per group: best-selling product in each category
-- A window result cannot go in WHERE directly - wrap it in a CTE.
-- ---------------------------------------------------------------------
WITH product_sales AS (
    SELECT category, product_name, SUM(line_amount) AS revenue
    FROM   sales_report
    GROUP  BY category, product_name
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM   product_sales
)
SELECT * FROM ranked WHERE rnk = 1;

-- ---------------------------------------------------------------------
-- 2.4 [CORE] Deduplication - the everyday data engineering use
-- Keep only each customer's latest order.
-- ---------------------------------------------------------------------
WITH latest AS (
    SELECT o.*,
           ROW_NUMBER() OVER (PARTITION BY customer_id
                              ORDER BY order_date DESC) AS rn
    FROM   orders o
)
SELECT customer_id, order_id, order_date
FROM   latest
WHERE  rn = 1;

-- ---------------------------------------------------------------------
-- 2.5 [CORE] Running totals
-- ORDER BY inside OVER() turns SUM into a running SUM.
-- ---------------------------------------------------------------------
WITH order_totals AS (
    SELECT order_id, order_date, customer_name, SUM(line_amount) AS order_value
    FROM   sales_report
    GROUP  BY order_id, order_date, customer_name
)
SELECT order_id, order_date, customer_name, order_value,
       SUM(order_value) OVER (ORDER BY order_date)                 AS company_running_total,
       SUM(order_value) OVER (PARTITION BY customer_name
                              ORDER BY order_date)                 AS customer_running_total
FROM   order_totals
ORDER  BY order_date;

-- ---------------------------------------------------------------------
-- 2.6 [CORE] LAG / LEAD - compare with the previous row
-- Month-on-month revenue change.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT order_month, SUM(line_amount) AS revenue
    FROM   sales_report
    GROUP  BY order_month
)
SELECT order_month, revenue,
       LAG(revenue)  OVER (ORDER BY order_month) AS prev_month,
       LEAD(revenue) OVER (ORDER BY order_month) AS next_month,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
                 / LAG(revenue) OVER (ORDER BY order_month), 1) AS pct_change
FROM   monthly;

-- ---------------------------------------------------------------------
-- 2.7 [CORE] Frames - moving average
-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW = this month + 2 before
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT order_month, SUM(line_amount) AS revenue
    FROM   sales_report
    GROUP  BY order_month
)
SELECT order_month, revenue,
       ROUND(AVG(revenue) OVER (ORDER BY order_month
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS moving_avg_3m
FROM   monthly;

-- ---------------------------------------------------------------------
-- 2.8 [IF TIME] Share of total, NTILE, FIRST_VALUE / LAST_VALUE
-- ---------------------------------------------------------------------
WITH cust AS (
    SELECT customer_name, SUM(line_amount) AS spend
    FROM   sales_report
    GROUP  BY customer_name
)
SELECT customer_name, spend,
       ROUND(100 * spend / SUM(spend) OVER (), 1)        AS pct_of_total,
       NTILE(3) OVER (ORDER BY spend DESC)               AS spend_tier,      -- 1 = top third
       FIRST_VALUE(customer_name) OVER (ORDER BY spend DESC) AS top_customer
FROM   cust;

-- LAST_VALUE trap: with ORDER BY, the default frame stops at the
-- current row (plus any ties), so "last" means "this row". Look at
-- Pooja - she shows Nikhil because they tie. Fix: widen the frame.
SELECT emp_name, salary,
       LAST_VALUE(emp_name) OVER (ORDER BY salary DESC)          AS wrong_lowest,
       LAST_VALUE(emp_name) OVER (ORDER BY salary DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS right_lowest
FROM   employees;

-- ---------------------------------------------------------------------
-- 2.9 [CORE] CASE - simple and searched
-- ---------------------------------------------------------------------
SELECT order_id, product_name, line_amount,
       CASE category                              -- simple CASE: one column, exact matches
            WHEN 'Electronics' THEN 'ELEC'
            WHEN 'Furniture'   THEN 'FURN'
            ELSE 'OTHER'
       END AS cat_code,
       CASE                                       -- searched CASE: any condition, first TRUE wins
            WHEN line_amount >= 50000 THEN 'Large'
            WHEN line_amount >= 10000 THEN 'Medium'
            ELSE 'Small'
       END AS line_size
FROM   sales_report
ORDER  BY line_amount DESC;

-- ---------------------------------------------------------------------
-- 2.10 [CORE] CASE inside aggregates - pivot rows into columns
-- ---------------------------------------------------------------------
SELECT order_month,
       SUM(CASE WHEN category = 'Electronics' THEN line_amount ELSE 0 END) AS electronics,
       SUM(CASE WHEN category = 'Furniture'   THEN line_amount ELSE 0 END) AS furniture,
       SUM(CASE WHEN category = 'Stationery'  THEN line_amount ELSE 0 END) AS stationery,
       SUM(line_amount)                                                    AS total
FROM   sales_report
GROUP  BY order_month
ORDER  BY order_month;

-- ---------------------------------------------------------------------
-- 2.11 [IF TIME] CASE + window together
-- Is each customer's order bigger or smaller than their previous one?
-- ---------------------------------------------------------------------
WITH order_totals AS (
    SELECT order_id, order_date, customer_name, SUM(line_amount) AS order_value
    FROM   sales_report
    GROUP  BY order_id, order_date, customer_name
)
SELECT customer_name, order_date, order_value,
       CASE
           WHEN LAG(order_value) OVER w IS NULL         THEN 'First order'
           WHEN order_value > LAG(order_value) OVER w   THEN 'Up'
           WHEN order_value < LAG(order_value) OVER w   THEN 'Down'
           ELSE 'Same'
       END AS trend
FROM   order_totals
WINDOW w AS (PARTITION BY customer_name ORDER BY order_date)   -- named window, written once
ORDER  BY customer_name, order_date;

-- CASE in ORDER BY: custom sort (regions in business order, not A-Z)
SELECT DISTINCT region
FROM   sales_report
ORDER  BY CASE region WHEN 'North' THEN 1 WHEN 'West' THEN 2
                      WHEN 'South' THEN 3 ELSE 4 END;


-- #####################################################################
-- PART 3  ADVANCED JOINS AND SUBQUERIES                    (0:55-1:25)
-- #####################################################################

-- ---------------------------------------------------------------------
-- 3.1 [CORE] Missing data with LEFT JOIN ... IS NULL
-- ---------------------------------------------------------------------
-- Customers who have never ordered
SELECT c.customer_id, c.customer_name
FROM   customers c
LEFT   JOIN orders o ON o.customer_id = c.customer_id
WHERE  o.order_id IS NULL;

-- Products never sold
SELECT p.product_code, p.product_name
FROM   products p
LEFT   JOIN order_items oi ON oi.product_code = p.product_code
WHERE  oi.order_id IS NULL;

-- ---------------------------------------------------------------------
-- 3.2 [CORE] ON vs WHERE in a LEFT JOIN - the classic trap
-- Goal: every customer, with their Electronics spend (0 if none)
-- ---------------------------------------------------------------------
-- WRONG: the filter in WHERE throws away customers with no Electronics
SELECT c.customer_name, COALESCE(SUM(s.line_amount),0) AS electronics_spend
FROM   customers c
LEFT   JOIN sales_report s ON s.customer_id = c.customer_id
WHERE  s.category = 'Electronics'
GROUP  BY c.customer_name;

-- RIGHT: the filter in ON keeps every customer
SELECT c.customer_name, COALESCE(SUM(s.line_amount),0) AS electronics_spend
FROM   customers c
LEFT   JOIN sales_report s ON s.customer_id = c.customer_id
                          AND s.category    = 'Electronics'
GROUP  BY c.customer_name
ORDER  BY electronics_spend DESC;

-- ---------------------------------------------------------------------
-- 3.3 [CORE] Self-join: the same table, two roles
-- employees e = the employee, employees m = their manager
-- ---------------------------------------------------------------------
SELECT e.emp_name  AS employee,
       m.emp_name  AS manager,
       mm.emp_name AS managers_manager
FROM   employees e
LEFT   JOIN employees m  ON m.emp_id  = e.manager_id     -- LEFT keeps the CEO
LEFT   JOIN employees mm ON mm.emp_id = m.manager_id
ORDER  BY e.emp_id;

-- Team size per manager
SELECT m.emp_name AS manager, COUNT(e.emp_id) AS direct_reports
FROM   employees m
JOIN   employees e ON e.manager_id = m.emp_id
GROUP  BY m.emp_name
ORDER  BY direct_reports DESC;

-- ---------------------------------------------------------------------
-- 3.4 [CORE] Non-equijoins: match on a range, not an equal key
-- ---------------------------------------------------------------------
-- Which salary grade is each employee in?
SELECT e.emp_name, e.salary, g.grade, g.grade_name
FROM   employees e
JOIN   salary_grades g
       ON e.salary BETWEEN g.min_salary AND g.max_salary
ORDER  BY e.salary DESC;

-- Which orders fell inside a promotion window?
SELECT o.order_id, o.order_date,
       COALESCE(p.promo_name,'No promotion') AS promo
FROM   orders o
LEFT   JOIN promotions p
       ON o.order_date BETWEEN p.start_date AND p.end_date
ORDER  BY o.order_date;

-- ---------------------------------------------------------------------
-- 3.5 [IF TIME] Self-join + non-equijoin together
-- ---------------------------------------------------------------------
-- Products bought together in the same order (market basket).
-- a.product_code < b.product_code stops duplicates (A-B and B-A)
SELECT a.product_code AS product_1, b.product_code AS product_2,
       COUNT(*) AS times_together
FROM   order_items a
JOIN   order_items b
       ON  a.order_id     = b.order_id
       AND a.product_code < b.product_code
GROUP  BY a.product_code, b.product_code
ORDER  BY times_together DESC;

-- Repeat customers: orders placed within 60 days of an earlier order
SELECT o1.customer_id, o1.order_id AS first_order, o1.order_date,
       o2.order_id AS repeat_order, o2.order_date AS repeat_date,
       DATEDIFF(o2.order_date, o1.order_date) AS days_between
FROM   orders o1
JOIN   orders o2
       ON  o2.customer_id = o1.customer_id
       AND o2.order_date  > o1.order_date
       AND o2.order_date <= o1.order_date + INTERVAL 60 DAY
ORDER  BY o1.customer_id, o1.order_date;

-- ---------------------------------------------------------------------
-- 3.6 [CORE] Subqueries - four places a query can sit
-- ---------------------------------------------------------------------
-- (a) Scalar subquery in WHERE: lines above the average line value
SELECT order_id, product_name, line_amount
FROM   sales_report
WHERE  line_amount > (SELECT AVG(line_amount) FROM sales_report);

-- (b) IN subquery: customers who bought a Laptop
SELECT customer_name
FROM   customers
WHERE  customer_id IN (SELECT customer_id FROM sales_report
                       WHERE  product_name = 'Laptop');

-- (c) Correlated subquery: runs once per outer row.
--     Employees earning more than their own department's average
SELECT e.emp_name, e.dept_id, e.salary
FROM   employees e
WHERE  e.salary > (SELECT AVG(e2.salary)
                   FROM   employees e2
                   WHERE  e2.dept_id = e.dept_id);    -- links to the outer row

-- (d) Derived table in FROM: customer spend vs their region's average
SELECT cs.customer_name, cs.region, cs.spend,
       ROUND(ra.region_avg) AS region_avg
FROM  (SELECT customer_name, region, SUM(line_amount) AS spend
       FROM   sales_report GROUP BY customer_name, region) cs
JOIN  (SELECT region, AVG(spend) AS region_avg
       FROM  (SELECT customer_name, region, SUM(line_amount) AS spend
              FROM   sales_report GROUP BY customer_name, region) x
       GROUP  BY region) ra
      ON ra.region = cs.region
ORDER BY cs.region, cs.spend DESC;

-- ---------------------------------------------------------------------
-- 3.7 [CORE] EXISTS and NOT EXISTS
-- EXISTS only asks "is there at least one row?" - it stops at the first match.
-- ---------------------------------------------------------------------
-- Customers who ordered during any promotion
-- (EXISTS with a non-equijoin inside it)
SELECT c.customer_name
FROM   customers c
WHERE  EXISTS (SELECT 1
               FROM   orders o
               JOIN   promotions p
                      ON o.order_date BETWEEN p.start_date AND p.end_date
               WHERE  o.customer_id = c.customer_id);

-- Customers who have never bought Stationery
-- Note: Karan and Fatima appear too - they have never bought anything.
SELECT c.customer_name
FROM   customers c
WHERE  NOT EXISTS (SELECT 1 FROM sales_report s
                   WHERE  s.customer_id = c.customer_id
                   AND    s.category    = 'Stationery');

-- Churn risk: ordered before, but nothing since 1 May
SELECT c.customer_name
FROM   customers c
WHERE  EXISTS     (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
AND    NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
                                            AND o.order_date >= '2026-05-01');

-- ---------------------------------------------------------------------
-- 3.8 [CORE] Why data engineers prefer NOT EXISTS over NOT IN
-- Question: which departments have no staff? (Answer: Research)
-- Harsh has dept_id = NULL.
-- ---------------------------------------------------------------------
SELECT dept_name
FROM   departments
WHERE  dept_id NOT IN (SELECT dept_id FROM employees);     -- returns NOTHING

SELECT d.dept_name
FROM   departments d
WHERE  NOT EXISTS (SELECT 1 FROM employees e
                   WHERE  e.dept_id = d.dept_id);          -- returns Research

-- Why: "x NOT IN (1,2,NULL)" means x<>1 AND x<>2 AND x<>NULL.
-- x<>NULL is UNKNOWN, so the whole test is never TRUE.

-- ---------------------------------------------------------------------
-- 3.9 [IF TIME] Double NOT EXISTS: customers who bought from EVERY category
-- Read it as: "there is no category this customer has not bought from"
-- ---------------------------------------------------------------------
SELECT c.customer_name
FROM   customers c
WHERE  NOT EXISTS (
         SELECT 1 FROM (SELECT DISTINCT category FROM products) cat
         WHERE  NOT EXISTS (
                  SELECT 1 FROM sales_report s
                  WHERE  s.customer_id = c.customer_id
                  AND    s.category    = cat.category));

-- =====================================================================
-- End of lab. Practice tasks: 03_exercises.sql
-- =====================================================================
