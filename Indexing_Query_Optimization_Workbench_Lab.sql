-- =====================================================================
-- ADVANCED SQL FOR DATA ENGINEERS | INDEXING AND QUERY OPTIMIZATION
-- MySQL Workbench practical lab | MySQL 8.0+
-- Prerequisite: Run your existing 01_setup.sql first (de_sql_lab).
-- NOTE: This file creates/replaces only lab_digits and order_perf.
--       It does NOT drop or change orders_raw, employees, or other base tables.
--
-- IMPORTANT FOR TEACHING:
-- Run SECTION 0 first. Then run each numbered section in order.
-- Highlight and execute one statement (Ctrl+Enter in Workbench), or select
-- a section. DO NOT create an index before its "BEFORE" EXPLAIN.
-- Use Query > Execute (All or Selection) only if you want to run every step.
-- EXPLAIN shows the PLAN, not the actual execution time.
-- EXPLAIN ANALYZE (optional, commented below) requires MySQL 8.0.18+.
-- =====================================================================

USE de_sql_lab;

-- SECTION 0 | PRECHECK AND SCALE-UP (about 2-5 minutes)
-- The original orders_raw has only 31 rows. On such a small table,
-- a full scan can be faster than an index, so performance differences
-- will not be convincing. Build a larger COPY to use for experiments.
SELECT VERSION() AS mysql_version;
SELECT COUNT(*) AS original_raw_rows FROM orders_raw;

DROP TABLE IF EXISTS order_perf;
DROP TABLE IF EXISTS lab_digits;

CREATE TABLE lab_digits (
    d TINYINT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=InnoDB;
INSERT INTO lab_digits (d) VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

CREATE TABLE order_perf (
    sale_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    order_id      INT NOT NULL,
    order_date    DATE NOT NULL,
    customer_id   VARCHAR(10) NOT NULL,
    product_code  VARCHAR(10) NOT NULL,
    category      VARCHAR(20) NOT NULL,
    qty           INT NOT NULL,
    line_amount   DECIMAL(12,2) NOT NULL
) ENGINE=InnoDB;

-- 5,000 repetitions of all 31 source lines -> 155,000 test records.
-- Offsetting order IDs preserves distinct synthetic orders.
-- Offsetting dates makes month-range filtering meaningful.
INSERT INTO order_perf
    (order_id, order_date, customer_id, product_code, category, qty, line_amount)
SELECT
    r.order_id + (n.n * 10000) AS order_id,
    DATE_ADD(r.order_date, INTERVAL (n.n % 180) DAY) AS order_date,
    r.customer_id,
    r.product_code,
    r.category,
    r.qty,
    r.unit_price * r.qty AS line_amount
FROM orders_raw AS r
CROSS JOIN (
    SELECT a.d + 10*b.d + 100*c.d + 1000*d.d AS n
    FROM lab_digits a
    CROSS JOIN lab_digits b
    CROSS JOIN lab_digits c
    CROSS JOIN lab_digits d
    WHERE a.d + 10*b.d + 100*c.d + 1000*d.d < 5000
) AS n;

SELECT COUNT(*) AS practice_rows FROM order_perf;   -- expected: 155000
SELECT COUNT(DISTINCT order_id) AS distinct_orders FROM order_perf; -- 100000

-- SECTION 1 | SINGLE-COLUMN INDEX: BEFORE VS AFTER (8-10 minutes)
-- Q: Find order 1001. Check EXPLAIN 'type', 'key', and 'rows'.
-- BEFORE INDEX: commonly 'type = ALL', 'key = NULL'.
EXPLAIN
SELECT order_id, order_date, line_amount
FROM order_perf
WHERE order_id = 1001;

-- Optional actual runtime for MySQL 8.0.18+ (uncomment to run):
-- EXPLAIN ANALYZE SELECT order_id, order_date, line_amount
-- FROM order_perf WHERE order_id = 1001;

CREATE INDEX idx_perf_order_id ON order_perf (order_id);

-- AFTER INDEX: commonly 'type = ref', 'key = idx_perf_order_id'.
EXPLAIN
SELECT order_id, order_date, line_amount
FROM order_perf
WHERE order_id = 1001;

SELECT order_id, order_date, line_amount
FROM order_perf
WHERE order_id = 1001;

-- Optional for MySQL 8.0.18+:
-- EXPLAIN ANALYZE SELECT order_id, order_date, line_amount
-- FROM order_perf WHERE order_id = 1001;

-- SECTION 2 | COMPOSITE INDEX AND LEFTMOST PREFIX (10 minutes)
-- Business query: C101's spending in June 2026, chronological order.
-- BEFORE COMPOSITE INDEX: likely scans many rows / sorts.
EXPLAIN
SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
  AND order_date >= '2026-06-01'
  AND order_date <  '2026-07-01'
ORDER BY order_date
LIMIT 30;

CREATE INDEX idx_perf_customer_date_amount
    ON order_perf (customer_id, order_date, line_amount);

-- AFTER: customer_id equality + date range; index also covers output.
EXPLAIN
SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
  AND order_date >= '2026-06-01'
  AND order_date <  '2026-07-01'
ORDER BY order_date
LIMIT 30;

SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
  AND order_date >= '2026-06-01'
  AND order_date <  '2026-07-01'
ORDER BY order_date
LIMIT 30;

-- Leftmost prefix: index begins with customer_id, then order_date.
-- A filter on customer_id alone can use the prefix.
EXPLAIN SELECT customer_id, order_date
FROM order_perf WHERE customer_id = 'C101' LIMIT 20;

-- A filter only on order_date is NOT a normal leftmost-prefix lookup.
-- Optimizer may scan, or choose an alternate strategy such as skip scan.
EXPLAIN SELECT customer_id, order_date
FROM order_perf
WHERE order_date >= '2026-06-01'
  AND order_date <  '2026-07-01' LIMIT 20;

-- SECTION 3 | SARGABILITY (8 minutes)
-- An expression applied to indexed date may stop MySQL from using
-- the date column as an index RANGE predicate.
-- LESS OPTIMIZABLE: DATE_FORMAT on the column.
EXPLAIN
SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
  AND DATE_FORMAT(order_date, '%Y-%m') = '2026-06';

-- BETTER: equivalent half-open date range (also works for DATETIME).
EXPLAIN
SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
  AND order_date >= '2026-06-01'
  AND order_date <  '2026-07-01';

-- SECTION 4 | COVERING INDEX AND SELECT * (6 minutes)
-- The composite index stores customer_id, order_date, line_amount;
-- InnoDB also carries the primary key in its secondary index entries.
-- Look for 'Using index' in EXPLAIN Extra for a covering read.
EXPLAIN
SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
  AND order_date >= '2026-06-01'
  AND order_date <  '2026-07-01';

-- Product code is NOT in the composite index; row lookups are needed.
EXPLAIN
SELECT customer_id, order_date, line_amount, product_code
FROM order_perf
WHERE customer_id = 'C101'
  AND order_date >= '2026-06-01'
  AND order_date <  '2026-07-01';

-- SECTION 5 | ORDER BY AND SORTING (5 minutes)
-- Index order matches date sorting once customer_id is fixed.
EXPLAIN
SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
ORDER BY order_date
LIMIT 20;

-- Different sorting column may need a separate sort ('Using filesort').
EXPLAIN
SELECT customer_id, order_date, line_amount
FROM order_perf
WHERE customer_id = 'C101'
ORDER BY line_amount DESC
LIMIT 20;

-- SECTION 6 | INDEX MANAGEMENT: SEE, HIDE, RESTORE (7 minutes)
SHOW INDEX FROM order_perf;

-- Invisible indexes let us test a plan WITHOUT physically dropping
-- the index. Do not leave the exercise index invisible by accident.
ALTER TABLE order_perf ALTER INDEX idx_perf_order_id INVISIBLE;
EXPLAIN
SELECT order_id, order_date, line_amount
FROM order_perf
WHERE order_id = 1001;

ALTER TABLE order_perf ALTER INDEX idx_perf_order_id VISIBLE;
EXPLAIN
SELECT order_id, order_date, line_amount
FROM order_perf
WHERE order_id = 1001;

-- Refresh optimizer table/index statistics when distributions change.
ANALYZE TABLE order_perf;
SHOW INDEX FROM order_perf;

-- OPTIONAL: show how an index is dropped (DO NOT run before finishing).
-- DROP INDEX idx_perf_order_id ON order_perf;

-- SECTION 7 | REALISTIC LIMITATIONS AND REVIEW (5 minutes)
-- Few distinct category values -> usually poor index selectivity.
SELECT category, COUNT(*) AS lines_in_category
FROM order_perf
GROUP BY category ORDER BY lines_in_category DESC;

-- Aggregating across the ENTIRE table can require reading many rows;
-- an index is not guaranteed to make this faster.
EXPLAIN
SELECT category, SUM(line_amount) AS revenue
FROM order_perf
GROUP BY category;

-- REVIEW: one record's order, narrow customer/date, and whole-table report
-- are different workloads: index choices should follow the workload.
-- No original table was changed in this lab.
