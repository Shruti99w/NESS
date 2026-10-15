-- =====================================================================
-- ADVANCED SQL FOR DATA ENGINEERS - 03 PRACTICE TASKS
-- Run 01_setup.sql and 02_lab.sql first.
-- Try each task before opening 04_solutions.sql.
-- Tasks 1, 3 and 5 fit inside the session. The rest are take-home.
-- =====================================================================
USE de_sql_lab;

-- ---------------------------------------------------------------------
-- TASK 1  (Design - physical model)
-- Each product comes from one supplier; a supplier can supply many
-- products. Create a suppliers table (supplier_id, supplier_name, city),
-- with city linked to the cities table. Then add a supplier_id column to
-- products with a foreign key. Insert two suppliers and assign them.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- TASK 2  (Design - denormalised view)
-- Build a view v_customer_summary with one row per customer:
-- customer_name, region, number_of_orders, total_spend, last_order_date.
-- Customers with no orders must still appear (0 orders, 0 spend).
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- TASK 3  (Window functions)
-- For each category, rank customers by how much they spent in that
-- category. Show only the top 2 customers per category.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- TASK 4  (Window + CASE)
-- For every order, show the customer, order date, and the number of
-- days since that customer's previous order. Add a label:
--   'New'        - first order
--   'Frequent'   - under 50 days since the previous order
--   'Occasional' - 50 days or more
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- TASK 5  (Self-join + non-equijoin)
-- Find pairs of employees who work in the same department AND fall in
-- the same salary grade. Show each pair once.
-- Expected: one pair.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- TASK 6  (EXISTS / NOT EXISTS)
-- Find customers who have bought Furniture but have never bought
-- Electronics.
-- ---------------------------------------------------------------------


-- ---------------------------------------------------------------------
-- STRETCH  Find the second-highest salary in each department.
-- If two people tie for first, the next salary down is "second".
-- ---------------------------------------------------------------------
