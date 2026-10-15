-- =====================================================================
-- ADVANCED SQL FOR DATA ENGINEERS - 01 SETUP
-- Run this once, before the session starts.
-- Needs MySQL 8.0 or later (window functions are not in 5.7).
-- In Workbench: open this file, then Query > Execute (All or Selection)
-- or press Ctrl+Shift+Enter.
-- =====================================================================

DROP DATABASE IF EXISTS de_sql_lab;
CREATE DATABASE de_sql_lab;
USE de_sql_lab;

-- ---------------------------------------------------------------------
-- 1. orders_raw
-- A flat extract, the way sales data often arrives from a spreadsheet
-- or a legacy system. One row per order line. Deliberately NOT
-- normalised - we will fix it in Part 1 of the lab.
-- ---------------------------------------------------------------------
CREATE TABLE orders_raw (
    order_id       INT,
    order_date     DATE,
    customer_id    VARCHAR(10),
    customer_name  VARCHAR(50),
    customer_city  VARCHAR(30),
    city_region    VARCHAR(10),
    product_code   VARCHAR(10),
    product_name   VARCHAR(50),
    category       VARCHAR(20),
    unit_price     DECIMAL(10,2),
    qty            INT
);

INSERT INTO orders_raw VALUES
(1001,'2026-01-05','C101','Priya Sharma','Delhi','North','P01','Laptop','Electronics',55000,1),
(1001,'2026-01-05','C101','Priya Sharma','Delhi','North','P02','Wireless Mouse','Electronics',800,2),
(1002,'2026-01-12','C102','Rahul Verma','Mumbai','West','P04','Office Chair','Furniture',7500,2),
(1003,'2026-01-20','C103','Ananya Iyer','Chennai','South','P07','Notebook Pack','Stationery',250,10),
(1003,'2026-01-20','C103','Ananya Iyer','Chennai','South','P08','Gel Pen Box','Stationery',180,5),
(1004,'2026-01-28','C101','Priya Sharma','Delhi','North','P03','Monitor 24in','Electronics',12000,2),
(1005,'2026-02-03','C104','Vikram Singh','Gurugram','North','P05','Standing Desk','Furniture',18000,1),
(1005,'2026-02-03','C104','Vikram Singh','Gurugram','North','P04','Office Chair','Furniture',7500,1),
(1006,'2026-02-14','C105','Meera Nair','Bengaluru','South','P01','Laptop','Electronics',52000,2),
(1006,'2026-02-14','C105','Meera Nair','Bengaluru','South','P02','Wireless Mouse','Electronics',800,2),
(1007,'2026-02-21','C106','Arjun Das','Kolkata','East','P06','Bookshelf','Furniture',4500,3),
(1008,'2026-03-02','C102','Rahul Verma','Mumbai','West','P03','Monitor 24in','Electronics',12000,1),
(1008,'2026-03-02','C102','Rahul Verma','Mumbai','West','P02','Wireless Mouse','Electronics',800,1),
(1009,'2026-03-10','C107','Sneha Kulkarni','Pune','West','P07','Notebook Pack','Stationery',250,20),
(1010,'2026-03-18','C101','Priya Sharma','Delhi','North','P05','Standing Desk','Furniture',18000,1),
(1011,'2026-03-25','C103','Ananya Iyer','Chennai','South','P01','Laptop','Electronics',55000,1),
(1012,'2026-04-04','C104','Vikram Singh','Gurugram','North','P08','Gel Pen Box','Stationery',180,10),
(1012,'2026-04-04','C104','Vikram Singh','Gurugram','North','P07','Notebook Pack','Stationery',250,10),
(1013,'2026-04-15','C105','Meera Nair','Bengaluru','South','P04','Office Chair','Furniture',7500,4),
(1013,'2026-04-15','C105','Meera Nair','Bengaluru','South','P06','Bookshelf','Furniture',4500,2),
(1014,'2026-04-22','C106','Arjun Das','Kolkata','East','P02','Wireless Mouse','Electronics',800,5),
(1015,'2026-05-06','C102','Rahul Verma','Mumbai','West','P01','Laptop','Electronics',55000,1),
(1015,'2026-05-06','C102','Rahul Verma','Mumbai','West','P03','Monitor 24in','Electronics',12000,1),
(1016,'2026-05-15','C107','Sneha Kulkarni','Pune','West','P05','Standing Desk','Furniture',18000,2),
(1017,'2026-05-27','C101','Priya Sharma','Delhi','North','P07','Notebook Pack','Stationery',250,15),
(1017,'2026-05-27','C101','Priya Sharma','Delhi','North','P08','Gel Pen Box','Stationery',180,10),
(1018,'2026-06-03','C103','Ananya Iyer','Chennai','South','P04','Office Chair','Furniture',7500,1),
(1018,'2026-06-03','C103','Ananya Iyer','Chennai','South','P06','Bookshelf','Furniture',4500,1),
(1019,'2026-06-12','C104','Vikram Singh','Gurugram','North','P01','Laptop','Electronics',55000,1),
(1020,'2026-06-24','C105','Meera Nair','Bengaluru','South','P03','Monitor 24in','Electronics',12000,2),
(1020,'2026-06-24','C105','Meera Nair','Bengaluru','South','P02','Wireless Mouse','Electronics',800,2);

-- ---------------------------------------------------------------------
-- 2. HR data - used for self-joins, non-equijoins and EXISTS
-- ---------------------------------------------------------------------
CREATE TABLE departments (
    dept_id    INT PRIMARY KEY,
    dept_name  VARCHAR(30) NOT NULL
);

INSERT INTO departments VALUES
(1,'Executive'),
(2,'Data Engineering'),
(3,'Analytics'),
(4,'Sales'),
(5,'Research');          -- no staff yet

CREATE TABLE employees (
    emp_id      INT PRIMARY KEY,
    emp_name    VARCHAR(50) NOT NULL,
    dept_id     INT NULL,              -- NULL = new joiner, not yet allocated
    manager_id  INT NULL,              -- points to another emp_id
    salary      INT NOT NULL,
    hire_date   DATE NOT NULL,
    FOREIGN KEY (dept_id)    REFERENCES departments(dept_id),
    FOREIGN KEY (manager_id) REFERENCES employees(emp_id)
);

INSERT INTO employees VALUES
(1 ,'Neha Kapoor'   ,1   ,NULL,250000,'2015-04-01'),
(2 ,'Rohan Gupta'   ,2   ,1   ,180000,'2017-06-15'),
(3 ,'Aditi Rao'     ,3   ,1   ,170000,'2018-01-10'),
(4 ,'Sameer Joshi'  ,4   ,1   ,150000,'2016-09-01'),
(5 ,'Kavya Menon'   ,2   ,2   ,120000,'2020-03-01'),
(6 ,'Imran Sheikh'  ,2   ,2   , 95000,'2022-07-11'),
(7 ,'Pooja Bhat'    ,2   ,5   , 65000,'2024-08-01'),
(8 ,'Nikhil Jain'   ,2   ,5   , 65000,'2024-08-01'),
(9 ,'Divya Reddy'   ,3   ,3   ,110000,'2019-11-20'),
(10,'Aman Khanna'   ,3   ,3   , 72000,'2023-02-14'),
(11,'Ritu Saxena'   ,4   ,4   , 90000,'2021-05-05'),
(12,'Varun Malhotra',4   ,4   , 58000,'2025-01-06'),
(13,'Tanvi Desai'   ,4   ,11  , 45000,'2025-09-01'),
(14,'Harsh Vardhan' ,NULL,2   , 40000,'2026-07-01');

-- Salary bands: an employee matches a band by RANGE, not by equal key
CREATE TABLE salary_grades (
    grade       CHAR(2) PRIMARY KEY,
    grade_name  VARCHAR(20),
    min_salary  INT,
    max_salary  INT
);

INSERT INTO salary_grades VALUES
('G1','Associate'     ,      0,  49999),
('G2','Engineer'      ,  50000,  79999),
('G3','Senior'        ,  80000, 119999),
('G4','Lead'          , 120000, 179999),
('G5','Leadership'    , 180000, 999999);

-- Promotions: an order matches a campaign if its date falls in the window
CREATE TABLE promotions (
    promo_name  VARCHAR(30),
    start_date  DATE,
    end_date    DATE
);

INSERT INTO promotions VALUES
('Valentine Tech Fest','2026-02-10','2026-02-16'),
('Summer Sale'        ,'2026-05-01','2026-05-20'),
('Monsoon Deals'      ,'2026-07-01','2026-07-15');

SELECT 'Setup complete' AS status,
       (SELECT COUNT(*) FROM orders_raw) AS raw_rows,
       (SELECT COUNT(*) FROM employees)  AS employees;
