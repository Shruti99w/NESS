-- SQL Hands-on Lab : setup script (PostgreSQL 12+)
-- Run once in an empty database. Safe to re-run: it drops and rebuilds the lab tables.

DROP VIEW  IF EXISTS v_monthly_revenue;
DROP TABLE IF EXISTS order_items, orders, promotions, products, customers,
                     salary_grades, employees, departments CASCADE;

-- ---------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------
CREATE TABLE departments (
    dept_id    INT PRIMARY KEY,
    dept_name  VARCHAR(40) NOT NULL,
    location   VARCHAR(40) NOT NULL
);

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
    manager_id INT REFERENCES employees(emp_id),
    dept_id    INT NOT NULL REFERENCES departments(dept_id),
    hire_date  DATE NOT NULL,
    salary     NUMERIC(10,2) NOT NULL
);

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
);

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
);

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
);

INSERT INTO customers
SELECT g,
       'Customer ' || LPAD(g::text, 5, '0'),
       (ARRAY['Mumbai','Delhi','Bengaluru','Pune','Chennai','Hyderabad','Kolkata','Jaipur'])[1 + g % 8],
       (ARRAY['Retail','Corporate','SME'])[1 + g % 3],
       DATE '2021-01-01' + (g % 900)
FROM generate_series(1, 5000) g;

CREATE TABLE products (
    product_id    INT PRIMARY KEY,
    product_name  VARCHAR(60) NOT NULL,
    category      VARCHAR(30) NOT NULL,
    unit_price    NUMERIC(10,2) NOT NULL
);

INSERT INTO products
SELECT g,
       'Product ' || LPAD(g::text, 3, '0'),
       (ARRAY['Laptops','Accessories','Software','Storage','Networking'])[1 + g % 5],
       ROUND((500 + (g * 937) % 45000)::numeric, 2)
FROM generate_series(1, 60) g;

-- products 59 and 60 are never ordered (see the generator below)

CREATE TABLE orders (
    order_id     INT PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(customer_id),
    emp_id       INT REFERENCES employees(emp_id),   -- NULL = online order, no sales rep
    order_date   DATE NOT NULL,
    status       VARCHAR(12) NOT NULL
);

INSERT INTO orders
SELECT g,
       1 + (g * 7919) % 4800,                         -- customers 4801-5000 never order
       CASE WHEN g % 10 = 0 THEN NULL                 -- every 10th order is online
            ELSE (ARRAY[7,8,10,22])[1 + g % 4] END,   -- only four reps actually sell
       DATE '2022-01-01' + (g * 13) % 1460,           -- 2022-01-01 .. 2025-12-30
       CASE WHEN g % 50 = 0 THEN 'CANCELLED'
            WHEN g % 25 = 0 THEN 'PENDING'
            WHEN g % 7  = 0 THEN 'RETURNED'
            ELSE 'DELIVERED' END
FROM generate_series(1, 150000) g;

CREATE TABLE order_items (
    order_item_id  INT PRIMARY KEY,
    order_id       INT NOT NULL REFERENCES orders(order_id),
    product_id     INT NOT NULL REFERENCES products(product_id),
    quantity       INT NOT NULL,
    unit_price     NUMERIC(10,2) NOT NULL
);

INSERT INTO order_items
SELECT ROW_NUMBER() OVER (ORDER BY o.order_id, n),
       o.order_id,
       p.product_id,
       1 + (o.order_id + n) % 4,
       p.unit_price
FROM orders o
CROSS JOIN LATERAL generate_series(1, 1 + o.order_id % 3) n
JOIN products p ON p.product_id = 1 + (o.order_id * 3 + n * 11) % 58;

-- Monthly revenue helper used in Module 1 (delivered orders only)
CREATE VIEW v_monthly_revenue AS
SELECT DATE_TRUNC('month', o.order_date)::date AS sales_month,
       COUNT(DISTINCT o.order_id)              AS orders,
       SUM(oi.quantity * oi.unit_price)        AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'DELIVERED'
GROUP BY 1;

ANALYZE;
