-- SQL Hands-on Lab: MySQL setup (MySQL 5.7 / 8.x)
-- Open this file in MySQL Workbench and execute the entire script.
-- Requires permission to create/use the sql_hands_on_lab database.
-- WARNING: Re-running rebuilds the named lab tables and removes their existing data.
CREATE DATABASE IF NOT EXISTS sql_hands_on_lab CHARACTER SET utf8mb4;
USE sql_hands_on_lab;

DROP VIEW  IF EXISTS v_monthly_revenue;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS promotions;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS salary_grades;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

-- Generate 1..150000 without PostgreSQL generate_series or recursive CTE limits.
DROP TEMPORARY TABLE IF EXISTS lab_digits;
DROP TEMPORARY TABLE IF EXISTS lab_numbers;
CREATE TEMPORARY TABLE lab_digits (d INT PRIMARY KEY);
INSERT INTO lab_digits VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);
CREATE TEMPORARY TABLE lab_numbers (g INT PRIMARY KEY);
-- Separate derived digit sets avoid MySQL temporary-table reopen errors.
INSERT INTO lab_numbers (g)
SELECT 1 + a.d + 10*b.d + 100*c.d + 1000*d.d + 10000*e.d + 100000*f.d
FROM lab_digits a
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) e
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1) f
WHERE 1 + a.d + 10*b.d + 100*c.d + 1000*d.d + 10000*e.d + 100000*f.d <= 150000;

-- ---------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------
CREATE TABLE departments (
    dept_id    INT PRIMARY KEY,
    dept_name  VARCHAR(40) NOT NULL,
    location   VARCHAR(40) NOT NULL
) ENGINE=InnoDB;

INSERT INTO departments VALUES
 (10, 'Executive',   'Mumbai'),
 (20, 'Sales',       'Delhi'),
 (30, 'Engineering', 'Bengaluru'),
 (40, 'Finance',     'Mumbai'),
 (50, 'Support',     'Pune');

CREATE TABLE employees (
    emp_id     INT PRIMARY KEY,
    emp_name   VARCHAR(40) NOT NULL,
    job_title  VARCHAR(40) NOT NULL,
    manager_id INT,
    dept_id    INT NOT NULL,
    hire_date  DATE NOT NULL,
    salary     NUMERIC(10,2) NOT NULL,
    FOREIGN KEY (manager_id) REFERENCES employees(emp_id),
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
) ENGINE=InnoDB;

INSERT INTO employees VALUES
 (1,  'Meera Kapoor',   'CEO',                 NULL, 10, '2015-04-01', 310000),
 (2,  'Arjun Rao',      'VP Sales',            1,    20, '2016-02-15', 190000),
 (3,  'Kavita Nair',    'VP Engineering',      1,    30, '2016-06-01', 200000),
 (4,  'Sandeep Joshi',  'Finance Controller',  1,    40, '2017-01-10', 165000),
 (5,  'Priya Menon',    'Support Head',        1,    50, '2018-03-12', 120000),
 (6,  'Rohit Verma',    'Sales Manager',       2,    20, '2018-07-01',  95000),
 (7,  'Neha Kulkarni',  'Sales Executive',     6,    20, '2019-09-16',  62000),
 (8,  'Imran Sheikh',   'Sales Executive',     6,    20, '2020-01-20',  58000),
 (9,  'Divya Iyer',     'Sales Executive',     6,    20, '2020-01-27',  58000),
 (10, 'Karan Malhotra', 'Sales Executive',     6,    20, '2021-05-03',  71000),
 (11, 'Anita Desai',    'Engineering Manager', 3,    30, '2017-08-21', 150000),
 (12, 'Vikram Singh',   'Senior Engineer',     11,   30, '2019-02-04', 118000),
 (13, 'Sneha Reddy',    'Senior Engineer',     11,   30, '2019-11-11', 118000),
 (14, 'Manoj Pillai',   'Engineer',            11,   30, '2021-06-14',  82000),
 (15, 'Pooja Bhatt',    'Engineer',            11,   30, '2022-08-01',  76000),
 (16, 'Rahul Gupta',    'Engineer',            11,   30, '2023-02-13',  74000),
 (17, 'Farah Khan',     'Accountant',          4,    40, '2019-04-22',  68000),
 (18, 'Deepak Chawla',  'Accountant',          4,    40, '2020-10-05',  64000),
 (19, 'Lakshmi Narayan','Support Analyst',     5,    50, '2020-12-01',  46000),
 (20, 'Tarun Bose',     'Support Analyst',     5,    50, '2022-01-17',  44000),
 (21, 'Isha Trivedi',   'Support Analyst',     5,    50, '2023-07-03',  41000),
 -- a deliberately awkward case: a team member paid more than their manager
 (22, 'Nikhil Anand',   'Sales Executive',     6,    20, '2017-03-06', 101000);

CREATE TABLE salary_grades (
    grade       CHAR(1) PRIMARY KEY,
    min_salary  NUMERIC(10,2) NOT NULL,
    max_salary  NUMERIC(10,2) NOT NULL
) ENGINE=InnoDB;

INSERT INTO salary_grades VALUES
 ('A',      0,  49999.99),
 ('B',  50000,  79999.99),
 ('C',  80000, 119999.99),
 ('D', 120000, 199999.99),
 ('E', 200000, 999999.99);

CREATE TABLE promotions (
    promo_id      INT PRIMARY KEY,
    promo_name    VARCHAR(40) NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    discount_pct  NUMERIC(4,1) NOT NULL
) ENGINE=InnoDB;

INSERT INTO promotions VALUES
 (1, 'Diwali 2023',      '2023-10-20', '2023-11-15', 10.0),
 (2, 'New Year 2024',    '2023-12-26', '2024-01-05',  8.0),
 (3, 'Summer Sale 2024', '2024-05-01', '2024-06-15', 12.0),
 (4, 'Diwali 2024',      '2024-10-25', '2024-11-12', 10.0),
 (5, 'Republic Day 2025','2025-01-20', '2025-01-28',  7.5),
 (6, 'Diwali 2025',      '2025-10-15', '2025-11-05', 15.0);

-- ---------------------------------------------------------------
-- Transactional data (generated, deterministic - no random())
-- ---------------------------------------------------------------
CREATE TABLE customers (
    customer_id    INT PRIMARY KEY,
    customer_name  VARCHAR(60) NOT NULL,
    city           VARCHAR(30) NOT NULL,
    segment        VARCHAR(15) NOT NULL,
    signup_date    DATE NOT NULL
) ENGINE=InnoDB;

INSERT INTO customers
SELECT g,
       CONCAT('Customer ', LPAD(CAST(g AS CHAR), 5, '0')),
       ELT(1 + g % 8, 'Mumbai','Delhi','Bengaluru','Pune','Chennai','Hyderabad','Kolkata','Jaipur'),
       ELT(1 + g % 3, 'Retail','Corporate','SME'),
       DATE_ADD('2021-01-01', INTERVAL (g % 900) DAY)
FROM lab_numbers WHERE g <= 5000;

CREATE TABLE products (
    product_id    INT PRIMARY KEY,
    product_name  VARCHAR(60) NOT NULL,
    category      VARCHAR(30) NOT NULL,
    unit_price    NUMERIC(10,2) NOT NULL
) ENGINE=InnoDB;

INSERT INTO products
SELECT g,
       CONCAT('Product ', LPAD(CAST(g AS CHAR), 3, '0')),
       ELT(1 + g % 5, 'Laptops','Accessories','Software','Storage','Networking'),
       ROUND(500 + (g * 937) % 45000, 2)
FROM lab_numbers WHERE g <= 60;

-- products 59 and 60 are never ordered (see the generator below)

CREATE TABLE orders (
    order_id     INT PRIMARY KEY,
    customer_id  INT NOT NULL,
    emp_id       INT,   -- NULL = online order, no sales rep
    order_date   DATE NOT NULL,
    status       VARCHAR(12) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
) ENGINE=InnoDB;

INSERT INTO orders
SELECT g,
       1 + (g * 7919) % 4800,                         -- customers 4801-5000 never order
       CASE WHEN g % 10 = 0 THEN NULL                 -- every 10th order is online
            ELSE CAST(ELT(1 + g % 4, 7,8,10,22) AS UNSIGNED) END,   -- only four reps actually sell
       DATE_ADD('2022-01-01', INTERVAL ((g * 13) % 1460) DAY),           -- 2022-01-01 .. 2025-12-30
       CASE WHEN g % 50 = 0 THEN 'CANCELLED'
            WHEN g % 25 = 0 THEN 'PENDING'
            WHEN g % 7  = 0 THEN 'RETURNED'
            ELSE 'DELIVERED' END
FROM lab_numbers;

CREATE TABLE order_items (
    order_item_id  INT PRIMARY KEY,
    order_id       INT NOT NULL,
    product_id     INT NOT NULL,
    quantity       INT NOT NULL,
    unit_price     NUMERIC(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

INSERT INTO order_items
SELECT 2 * (o.order_id - 1) + FLOOR(MOD(o.order_id - 1, 3) / 2) + seq.n,
       o.order_id,
       p.product_id,
       1 + (o.order_id + seq.n) % 4,
       p.unit_price
FROM orders o
JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3) seq
  ON seq.n <= 1 + o.order_id % 3
JOIN products p ON p.product_id = 1 + (o.order_id * 3 + seq.n * 11) % 58;

-- Monthly revenue helper used in Module 1 (delivered orders only)
CREATE VIEW v_monthly_revenue AS
SELECT CAST(DATE_FORMAT(o.order_date, '%Y-%m-01') AS DATE) AS sales_month,
       COUNT(DISTINCT o.order_id)              AS orders,
       SUM(oi.quantity * oi.unit_price)        AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DELIVERED'
GROUP BY 1;

ANALYZE TABLE departments, employees, salary_grades, promotions,
              customers, products, orders, order_items;
DROP TEMPORARY TABLE lab_numbers;
DROP TEMPORARY TABLE lab_digits;

-- Expected counts: 5, 22, 5, 6, 5000, 60, 150000, 300000.
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'salary_grades', COUNT(*) FROM salary_grades
UNION ALL SELECT 'promotions', COUNT(*) FROM promotions
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;
