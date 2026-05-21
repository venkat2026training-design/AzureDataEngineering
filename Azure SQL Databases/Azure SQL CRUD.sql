-- ============================================================
--  Azure SQL CRUD Practice Script
--  Schema  : RetailDB
--  Tables  : Departments, Employees, Customers,
--             Products, Orders, OrderItems
--  Sections: 1 - Create Tables
--             2 - Insert Dummy Data
--             3 - CRUD Operations  (INSERT / UPDATE / DELETE)
--             4 - Basic Queries
--             5 - Complex Queries  (JOINs, Subqueries, CTEs)
--             6 - Window Functions & Analytics
--             7 - Aggregations & Grouping
--             8 - Advanced T-SQL   (MERGE, PIVOT, TRY/CATCH)
--  Target  : Azure SQL Database (SQL Server >= 2016)
-- ============================================================


-- ============================================================
-- SECTION 1 : CREATE TABLES
-- ============================================================

-- Drop tables in FK-safe order if they already exist
IF OBJECT_ID('dbo.OrderItems',  'U') IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID('dbo.Orders',      'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Products',    'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Customers',   'U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.Employees',   'U') IS NOT NULL DROP TABLE dbo.Employees;
IF OBJECT_ID('dbo.Departments', 'U') IS NOT NULL DROP TABLE dbo.Departments;

-- 1.1  Departments
CREATE TABLE dbo.Departments (
    DepartmentID   INT           IDENTITY(1,1) PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL UNIQUE,
    Location       NVARCHAR(100) NOT NULL,
    Budget         DECIMAL(15,2) NOT NULL DEFAULT 0,
    CreatedAt      DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);

-- 1.2  Employees
CREATE TABLE dbo.Employees (
    EmployeeID     INT           IDENTITY(1,1) PRIMARY KEY,
    FirstName      NVARCHAR(50)  NOT NULL,
    LastName       NVARCHAR(50)  NOT NULL,
    Email          NVARCHAR(150) NOT NULL UNIQUE,
    Phone          NVARCHAR(20)  NULL,
    HireDate       DATE          NOT NULL,
    Salary         DECIMAL(10,2) NOT NULL,
    DepartmentID   INT           NOT NULL,
    ManagerID      INT           NULL,
    IsActive       BIT           NOT NULL DEFAULT 1,
    CONSTRAINT FK_Employee_Department FOREIGN KEY (DepartmentID)
        REFERENCES dbo.Departments(DepartmentID),
    CONSTRAINT FK_Employee_Manager    FOREIGN KEY (ManagerID)
        REFERENCES dbo.Employees(EmployeeID)
);

-- 1.3  Customers
CREATE TABLE dbo.Customers (
    CustomerID     INT           IDENTITY(1,1) PRIMARY KEY,
    FirstName      NVARCHAR(50)  NOT NULL,
    LastName       NVARCHAR(50)  NOT NULL,
    Email          NVARCHAR(150) NOT NULL UNIQUE,
    Phone          NVARCHAR(20)  NULL,
    City           NVARCHAR(100) NOT NULL,
    Country        NVARCHAR(100) NOT NULL DEFAULT 'USA',
    LoyaltyTier    NVARCHAR(20)  NOT NULL DEFAULT 'Bronze'
                   CHECK (LoyaltyTier IN ('Bronze','Silver','Gold','Platinum')),
    CreatedAt      DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);

-- 1.4  Products
CREATE TABLE dbo.Products (
    ProductID      INT           IDENTITY(1,1) PRIMARY KEY,
    ProductName    NVARCHAR(200) NOT NULL,
    Category       NVARCHAR(100) NOT NULL,
    UnitPrice      DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    StockQty       INT           NOT NULL DEFAULT 0 CHECK (StockQty >= 0),
    ReorderLevel   INT           NOT NULL DEFAULT 10,
    IsDiscontinued BIT           NOT NULL DEFAULT 0,
    CreatedAt      DATETIME2     NOT NULL DEFAULT GETUTCDATE()
);

-- 1.5  Orders
CREATE TABLE dbo.Orders (
    OrderID        INT           IDENTITY(1,1) PRIMARY KEY,
    CustomerID     INT           NOT NULL,
    EmployeeID     INT           NOT NULL,
    OrderDate      DATETIME2     NOT NULL DEFAULT GETUTCDATE(),
    ShipDate       DATETIME2     NULL,
    Status         NVARCHAR(20)  NOT NULL DEFAULT 'Pending'
                   CHECK (Status IN ('Pending','Processing','Shipped','Delivered','Cancelled')),
    ShippingCity   NVARCHAR(100) NOT NULL,
    ShippingCountry NVARCHAR(100) NOT NULL DEFAULT 'USA',
    Discount       DECIMAL(5,2)  NOT NULL DEFAULT 0 CHECK (Discount BETWEEN 0 AND 100),
    CONSTRAINT FK_Order_Customer FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT FK_Order_Employee FOREIGN KEY (EmployeeID)
        REFERENCES dbo.Employees(EmployeeID)
);

-- 1.6  OrderItems
CREATE TABLE dbo.OrderItems (
    OrderItemID    INT           IDENTITY(1,1) PRIMARY KEY,
    OrderID        INT           NOT NULL,
    ProductID      INT           NOT NULL,
    Quantity       INT           NOT NULL CHECK (Quantity > 0),
    UnitPrice      DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    CONSTRAINT FK_OrderItem_Order   FOREIGN KEY (OrderID)
        REFERENCES dbo.Orders(OrderID),
    CONSTRAINT FK_OrderItem_Product FOREIGN KEY (ProductID)
        REFERENCES dbo.Products(ProductID)
);


-- ============================================================
-- SECTION 2 : INSERT DUMMY DATA
-- ============================================================

-- 2.1  Departments
INSERT INTO dbo.Departments (DepartmentName, Location, Budget) VALUES
('Sales',          'New York',     750000.00),
('Engineering',    'San Francisco',1200000.00),
('Marketing',      'Chicago',       500000.00),
('Human Resources','Austin',        300000.00),
('Finance',        'Boston',        450000.00),
('Operations',     'Seattle',       600000.00);

-- 2.2  Employees  (insert managers first, then direct reports)
INSERT INTO dbo.Employees (FirstName, LastName, Email, Phone, HireDate, Salary, DepartmentID, ManagerID) VALUES
('Alice',   'Johnson',  'alice.johnson@retail.com',  '212-555-0101', '2018-03-15', 95000.00, 1, NULL),
('Bob',     'Martinez', 'bob.martinez@retail.com',   '415-555-0202', '2017-07-01', 110000.00,2, NULL),
('Carol',   'Lee',      'carol.lee@retail.com',      '312-555-0303', '2019-01-10', 88000.00, 3, NULL),
('David',   'Kim',      'david.kim@retail.com',      '512-555-0404', '2016-11-20', 75000.00, 4, NULL),
('Eva',     'Patel',    'eva.patel@retail.com',      '617-555-0505', '2020-05-05', 92000.00, 5, NULL),
('Frank',   'Nguyen',   'frank.nguyen@retail.com',   '206-555-0606', '2015-09-01', 105000.00,6, NULL),
('Grace',   'Wilson',   'grace.wilson@retail.com',   '212-555-0707', '2021-02-14', 68000.00, 1, 1),
('Henry',   'Brown',    'henry.brown@retail.com',    '212-555-0808', '2022-06-01', 62000.00, 1, 1),
('Iris',    'Chen',     'iris.chen@retail.com',      '415-555-0909', '2021-08-15', 97000.00, 2, 2),
('James',   'Taylor',   'james.taylor@retail.com',   '415-555-1010', '2023-01-09', 89000.00, 2, 2),
('Karen',   'Adams',    'karen.adams@retail.com',    '312-555-1111', '2022-03-22', 72000.00, 3, 3),
('Leo',     'Roberts',  'leo.roberts@retail.com',    '512-555-1212', '2020-11-01', 66000.00, 4, 4);

-- 2.3  Customers
INSERT INTO dbo.Customers (FirstName, LastName, Email, Phone, City, Country, LoyaltyTier) VALUES
('Liam',    'Walker',   'liam.walker@email.com',   '646-111-0001', 'New York',    'USA',    'Gold'),
('Olivia',  'Hall',     'olivia.hall@email.com',   '323-111-0002', 'Los Angeles', 'USA',    'Platinum'),
('Noah',    'Young',    'noah.young@email.com',    '713-111-0003', 'Houston',     'USA',    'Silver'),
('Emma',    'Allen',    'emma.allen@email.com',    '602-111-0004', 'Phoenix',     'USA',    'Bronze'),
('William', 'Scott',    'william.scott@email.com', '215-111-0005', 'Philadelphia','USA',    'Gold'),
('Ava',     'Green',    'ava.green@email.com',     '210-111-0006', 'San Antonio', 'USA',    'Silver'),
('James',   'Baker',    'james.baker@email.com',   '619-111-0007', 'San Diego',   'USA',    'Bronze'),
('Sophia',  'Nelson',   'sophia.nelson@email.com', '214-111-0008', 'Dallas',      'USA',    'Platinum'),
('Oliver',  'Carter',   'oliver.carter@email.com', '408-111-0009', 'San Jose',    'USA',    'Gold'),
('Isabella','Mitchell', 'isabella.m@email.com',    '512-111-0010', 'Austin',      'USA',    'Silver'),
('Ethan',   'Perez',    'ethan.perez@email.com',   '904-111-0011', 'Jacksonville','USA',    'Bronze'),
('Mia',     'Turner',   'mia.turner@email.com',    '904-111-0012', 'Jacksonville','USA',    'Gold'),
('Lucas',   'Phillips', 'lucas.phillips@email.com','614-111-0013', 'Columbus',    'USA',    'Silver'),
('Amelia',  'Campbell', 'amelia.c@email.com',      '317-111-0014', 'Indianapolis','USA',    'Bronze'),
('Mason',   'Parker',   'mason.parker@email.com',  '650-111-0015', 'San Francisco','USA',   'Platinum');

-- 2.4  Products
INSERT INTO dbo.Products (ProductName, Category, UnitPrice, StockQty, ReorderLevel) VALUES
('Wireless Keyboard',       'Electronics',  49.99,  200, 20),
('USB-C Hub 7-in-1',        'Electronics',  39.99,  150, 15),
('Noise Cancelling Headset','Electronics', 129.99,   80, 10),
('Mechanical Keyboard',     'Electronics',  99.99,   60, 10),
('27-inch Monitor',         'Electronics', 349.99,   40,  5),
('Ergonomic Office Chair',  'Furniture',   299.99,   30,  5),
('Standing Desk',           'Furniture',   499.99,   20,  3),
('Laptop Stand',            'Accessories',  29.99,  300, 30),
('Cable Management Kit',    'Accessories',   9.99,  500, 50),
('Webcam 1080p',            'Electronics',  79.99,  120, 15),
('Blue Light Glasses',      'Accessories',  19.99,  250, 25),
('Desk Organizer',          'Office',       24.99,  180, 20),
('Whiteboard 4x3ft',        'Office',       89.99,   45,  8),
('Shredder Cross-Cut',      'Office',       69.99,   35,  5),
('Coffee Maker 12-cup',     'Appliances',   59.99,   90, 10),
('Air Purifier HEPA',       'Appliances',  149.99,   55,  8),
('Wireless Mouse',          'Electronics',  34.99,  220, 25),
('Mousepad XL',             'Accessories',  14.99,  400, 40),
('HDMI Cable 2m',           'Accessories',   8.99, 1000, 100),
('Power Strip Surge',       'Accessories',  27.99,  180, 20);

-- 2.5  Orders
INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, ShipDate, Status, ShippingCity, ShippingCountry, Discount) VALUES
(1,  7,  '2025-11-01', '2025-11-03', 'Delivered', 'New York',     'USA', 0),
(2,  7,  '2025-11-05', '2025-11-07', 'Delivered', 'Los Angeles',  'USA', 10),
(3,  8,  '2025-11-10', '2025-11-12', 'Delivered', 'Houston',      'USA', 0),
(4,  8,  '2025-11-12', NULL,         'Cancelled', 'Phoenix',      'USA', 0),
(5,  7,  '2025-11-15', '2025-11-18', 'Delivered', 'Philadelphia', 'USA', 5),
(6,  8,  '2025-11-20', '2025-11-22', 'Shipped',   'San Antonio',  'USA', 0),
(7,  7,  '2025-12-01', '2025-12-03', 'Delivered', 'San Diego',    'USA', 0),
(8,  8,  '2025-12-05', '2025-12-07', 'Delivered', 'Dallas',       'USA', 15),
(9,  7,  '2025-12-10', '2025-12-13', 'Delivered', 'San Jose',     'USA', 0),
(10, 8,  '2025-12-15', NULL,         'Processing','Austin',        'USA', 0),
(1,  7,  '2026-01-02', '2026-01-05', 'Delivered', 'New York',     'USA', 0),
(2,  7,  '2026-01-08', '2026-01-10', 'Delivered', 'Los Angeles',  'USA', 10),
(11, 8,  '2026-01-15', '2026-01-18', 'Delivered', 'Jacksonville', 'USA', 0),
(12, 7,  '2026-01-20', NULL,         'Pending',   'Jacksonville', 'USA', 0),
(13, 8,  '2026-02-01', '2026-02-04', 'Delivered', 'Columbus',     'USA', 0),
(14, 7,  '2026-02-10', NULL,         'Processing','Indianapolis', 'USA', 5),
(15, 8,  '2026-02-15', '2026-02-17', 'Shipped',   'San Francisco','USA', 0),
(3,  7,  '2026-02-20', NULL,         'Pending',   'Houston',      'USA', 0),
(5,  8,  '2026-03-01', '2026-03-03', 'Delivered', 'Philadelphia', 'USA', 0),
(8,  7,  '2026-03-05', NULL,         'Processing','Dallas',       'USA', 10);

-- 2.6  OrderItems
INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice) VALUES
(1,  1, 2,  49.99), (1,  8, 1,  29.99), (1, 18, 2,  14.99),
(2,  3, 1, 129.99), (2,  5, 1, 349.99),
(3,  2, 2,  39.99), (3, 17, 1,  34.99),
(4,  6, 1, 299.99),
(5,  4, 1,  99.99), (5,  1, 1,  49.99), (5, 19, 3,   8.99),
(6,  7, 1, 499.99), (6,  9, 2,   9.99),
(7, 10, 1,  79.99), (7, 11, 2,  19.99),
(8,  5, 2, 349.99), (8,  3, 1, 129.99),
(9,  4, 1,  99.99), (9,  2, 2,  39.99), (9, 20, 1,  27.99),
(10, 15, 1,  59.99),(10, 16, 1, 149.99),
(11,  1, 1,  49.99),(11,  8, 2,  29.99),(11, 19, 5,  8.99),
(12,  3, 2, 129.99),(12, 10, 1,  79.99),
(13,  6, 1, 299.99),(13,  9, 3,   9.99),
(14, 12, 2,  24.99),(14, 13, 1,  89.99),
(15, 17, 2,  34.99),(15, 18, 3,  14.99),(15, 11, 1, 19.99),
(16, 14, 1,  69.99),(16, 15, 1,  59.99),
(17,  5, 1, 349.99),(17,  4, 1,  99.99),(17,  1, 2, 49.99),
(18,  7, 1, 499.99),(18, 20, 2,  27.99),
(19,  2, 3,  39.99),(19, 17, 2,  34.99),
(20,  3, 2, 129.99),(20,  5, 1, 349.99);


-- ============================================================
-- SECTION 3 : CRUD OPERATIONS
-- ============================================================

-- ─── INSERT — add a new customer ──────────────────────────
INSERT INTO dbo.Customers (FirstName, LastName, Email, Phone, City, Country, LoyaltyTier)
VALUES ('Zara', 'Hughes', 'zara.hughes@email.com', '720-222-0099', 'Denver', 'USA', 'Silver');

-- INSERT — add a new product
INSERT INTO dbo.Products (ProductName, Category, UnitPrice, StockQty, ReorderLevel)
VALUES ('Smart Plug Wi-Fi', 'Electronics', 22.99, 300, 30);

-- INSERT — add a new order for the new customer
INSERT INTO dbo.Orders (CustomerID, EmployeeID, OrderDate, Status, ShippingCity, Discount)
VALUES (
    (SELECT CustomerID FROM dbo.Customers WHERE Email = 'zara.hughes@email.com'),
    7,
    GETUTCDATE(),
    'Pending',
    'Denver',
    0
);

-- INSERT — add order items for the new order
INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
SELECT
    (SELECT MAX(OrderID) FROM dbo.Orders),
    ProductID,
    2,
    UnitPrice
FROM dbo.Products
WHERE ProductName = 'Smart Plug Wi-Fi';


-- ─── UPDATE — raise salary by 10% for top earners in Engineering ──
UPDATE dbo.Employees
SET    Salary = Salary * 1.10
WHERE  DepartmentID = (SELECT DepartmentID FROM dbo.Departments WHERE DepartmentName = 'Engineering')
  AND  Salary >= 95000;

-- UPDATE — upgrade loyalty tier for customers with 3+ delivered orders
UPDATE dbo.Customers
SET    LoyaltyTier = 'Gold'
WHERE  LoyaltyTier = 'Silver'
  AND  CustomerID IN (
           SELECT o.CustomerID
           FROM   dbo.Orders o
           WHERE  o.Status = 'Delivered'
           GROUP  BY o.CustomerID
           HAVING COUNT(*) >= 3
       );

-- UPDATE — mark stock as critical (reorder level) and bump reorder level
UPDATE dbo.Products
SET    ReorderLevel = ReorderLevel + 5
WHERE  StockQty <= ReorderLevel;

-- UPDATE — ship all Processing orders older than 3 days
UPDATE dbo.Orders
SET    Status   = 'Shipped',
       ShipDate = GETUTCDATE()
WHERE  Status    = 'Processing'
  AND  OrderDate <= DATEADD(DAY, -3, GETUTCDATE());


-- ─── DELETE — remove cancelled orders and their items ─────
DELETE FROM dbo.OrderItems
WHERE  OrderID IN (SELECT OrderID FROM dbo.Orders WHERE Status = 'Cancelled');

DELETE FROM dbo.Orders
WHERE  Status = 'Cancelled';

-- DELETE — remove discontinued products with zero stock
DELETE FROM dbo.Products
WHERE  IsDiscontinued = 1
  AND  StockQty = 0;


-- ============================================================
-- SECTION 4 : BASIC QUERIES
-- ============================================================

-- 4.1  All active employees with their department name
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName   AS FullName,
    e.Email,
    d.DepartmentName,
    e.Salary,
    e.HireDate
FROM   dbo.Employees e
JOIN   dbo.Departments d ON d.DepartmentID = e.DepartmentID
WHERE  e.IsActive = 1
ORDER  BY d.DepartmentName, e.LastName;

-- 4.2  Products low on stock (at or below reorder level)
SELECT
    ProductID,
    ProductName,
    Category,
    StockQty,
    ReorderLevel,
    UnitPrice,
    (ReorderLevel - StockQty) AS UnitsNeeded
FROM   dbo.Products
WHERE  StockQty <= ReorderLevel
  AND  IsDiscontinued = 0
ORDER  BY UnitsNeeded DESC;

-- 4.3  All orders with customer full name and status
SELECT
    o.OrderID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.LoyaltyTier,
    o.OrderDate,
    o.Status,
    o.ShippingCity,
    o.Discount
FROM   dbo.Orders o
JOIN   dbo.Customers c ON c.CustomerID = o.CustomerID
ORDER  BY o.OrderDate DESC;

-- 4.4  Total revenue per order (before discount)
SELECT
    oi.OrderID,
    SUM(oi.Quantity * oi.UnitPrice)                              AS GrossRevenue,
    o.Discount,
    SUM(oi.Quantity * oi.UnitPrice) * (1 - o.Discount / 100.0)  AS NetRevenue
FROM   dbo.OrderItems oi
JOIN   dbo.Orders      o ON o.OrderID = oi.OrderID
GROUP  BY oi.OrderID, o.Discount
ORDER  BY NetRevenue DESC;


-- ============================================================
-- SECTION 5 : COMPLEX QUERIES — JOINs, Subqueries, CTEs
-- ============================================================

-- 5.1  Multi-table JOIN: full order detail with employee name
SELECT
    o.OrderID,
    o.OrderDate,
    o.Status,
    c.FirstName + ' ' + c.LastName  AS CustomerName,
    c.LoyaltyTier,
    e.FirstName + ' ' + e.LastName  AS SalesRepName,
    p.ProductName,
    p.Category,
    oi.Quantity,
    oi.UnitPrice,
    oi.Quantity * oi.UnitPrice      AS LineTotal
FROM   dbo.Orders      o
JOIN   dbo.Customers   c  ON c.CustomerID  = o.CustomerID
JOIN   dbo.Employees   e  ON e.EmployeeID  = o.EmployeeID
JOIN   dbo.OrderItems  oi ON oi.OrderID    = o.OrderID
JOIN   dbo.Products    p  ON p.ProductID   = oi.ProductID
ORDER  BY o.OrderDate DESC, o.OrderID, oi.OrderItemID;


-- 5.2  LEFT JOIN: customers who have never placed an order
SELECT
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.Email,
    c.City,
    c.LoyaltyTier
FROM   dbo.Customers c
LEFT   JOIN dbo.Orders o ON o.CustomerID = c.CustomerID
WHERE  o.OrderID IS NULL
ORDER  BY c.LastName;


-- 5.3  Subquery: products that appear in more than 3 distinct orders
SELECT
    p.ProductID,
    p.ProductName,
    p.Category,
    p.UnitPrice,
    (
        SELECT COUNT(DISTINCT oi2.OrderID)
        FROM   dbo.OrderItems oi2
        WHERE  oi2.ProductID = p.ProductID
    ) AS TimesOrdered
FROM   dbo.Products p
WHERE  (
           SELECT COUNT(DISTINCT oi.OrderID)
           FROM   dbo.OrderItems oi
           WHERE  oi.ProductID = p.ProductID
       ) > 3
ORDER  BY TimesOrdered DESC;


-- 5.4  CTE: top 5 customers by net revenue
WITH CustomerRevenue AS (
    SELECT
        c.CustomerID,
        c.FirstName + ' ' + c.LastName            AS CustomerName,
        c.LoyaltyTier,
        SUM(oi.Quantity * oi.UnitPrice
            * (1 - o.Discount / 100.0))            AS NetRevenue,
        COUNT(DISTINCT o.OrderID)                  AS TotalOrders
    FROM   dbo.Customers  c
    JOIN   dbo.Orders     o  ON o.CustomerID  = c.CustomerID
    JOIN   dbo.OrderItems oi ON oi.OrderID    = o.OrderID
    WHERE  o.Status <> 'Cancelled'
    GROUP  BY c.CustomerID, c.FirstName, c.LastName, c.LoyaltyTier
)
SELECT   TOP 5
    CustomerID,
    CustomerName,
    LoyaltyTier,
    ROUND(NetRevenue, 2)  AS NetRevenue,
    TotalOrders
FROM   CustomerRevenue
ORDER  BY NetRevenue DESC;


-- 5.5  Recursive CTE: employee management hierarchy
WITH EmployeeHierarchy AS (
    -- Anchor: top-level managers (no manager)
    SELECT
        EmployeeID,
        FirstName + ' ' + LastName  AS FullName,
        ManagerID,
        DepartmentID,
        0                           AS Level,
        CAST(FirstName + ' ' + LastName AS NVARCHAR(500)) AS HierarchyPath
    FROM   dbo.Employees
    WHERE  ManagerID IS NULL

    UNION ALL

    -- Recursive: direct reports
    SELECT
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName,
        e.ManagerID,
        e.DepartmentID,
        h.Level + 1,
        CAST(h.HierarchyPath + ' > ' + e.FirstName + ' ' + e.LastName AS NVARCHAR(500))
    FROM   dbo.Employees       e
    JOIN   EmployeeHierarchy   h ON h.EmployeeID = e.ManagerID
)
SELECT
    REPLICATE('    ', Level) + FullName  AS OrgChart,
    Level,
    HierarchyPath
FROM   EmployeeHierarchy
ORDER  BY HierarchyPath;


-- 5.6  CTE chaining: monthly revenue trend
WITH OrderTotals AS (
    SELECT
        o.OrderID,
        o.OrderDate,
        SUM(oi.Quantity * oi.UnitPrice * (1 - o.Discount / 100.0)) AS NetRevenue
    FROM   dbo.Orders     o
    JOIN   dbo.OrderItems oi ON oi.OrderID = o.OrderID
    WHERE  o.Status <> 'Cancelled'
    GROUP  BY o.OrderID, o.OrderDate
),
MonthlyRevenue AS (
    SELECT
        YEAR(OrderDate)  AS OrderYear,
        MONTH(OrderDate) AS OrderMonth,
        COUNT(OrderID)   AS OrderCount,
        ROUND(SUM(NetRevenue), 2) AS TotalRevenue
    FROM   OrderTotals
    GROUP  BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT
    OrderYear,
    OrderMonth,
    OrderCount,
    TotalRevenue,
    SUM(TotalRevenue) OVER (ORDER BY OrderYear, OrderMonth) AS RunningTotal
FROM   MonthlyRevenue
ORDER  BY OrderYear, OrderMonth;


-- ============================================================
-- SECTION 6 : WINDOW FUNCTIONS & ANALYTICS
-- ============================================================

-- 6.1  Rank employees by salary within each department
SELECT
    d.DepartmentName,
    e.FirstName + ' ' + e.LastName  AS FullName,
    e.Salary,
    RANK()         OVER (PARTITION BY e.DepartmentID ORDER BY e.Salary DESC) AS SalaryRank,
    DENSE_RANK()   OVER (PARTITION BY e.DepartmentID ORDER BY e.Salary DESC) AS DenseRank,
    ROW_NUMBER()   OVER (PARTITION BY e.DepartmentID ORDER BY e.Salary DESC) AS RowNum,
    AVG(e.Salary)  OVER (PARTITION BY e.DepartmentID)                        AS AvgDeptSalary,
    MAX(e.Salary)  OVER (PARTITION BY e.DepartmentID)                        AS MaxDeptSalary,
    e.Salary - AVG(e.Salary) OVER (PARTITION BY e.DepartmentID)              AS VsAvg
FROM   dbo.Employees e
JOIN   dbo.Departments d ON d.DepartmentID = e.DepartmentID
WHERE  e.IsActive = 1
ORDER  BY d.DepartmentName, SalaryRank;


-- 6.2  Running total and moving average of order revenue (last 3 orders)
WITH OrderNetRevenue AS (
    SELECT
        o.OrderID,
        o.OrderDate,
        c.FirstName + ' ' + c.LastName AS CustomerName,
        SUM(oi.Quantity * oi.UnitPrice * (1 - o.Discount / 100.0)) AS NetRevenue
    FROM   dbo.Orders     o
    JOIN   dbo.Customers  c  ON c.CustomerID = o.CustomerID
    JOIN   dbo.OrderItems oi ON oi.OrderID   = o.OrderID
    WHERE  o.Status <> 'Cancelled'
    GROUP  BY o.OrderID, o.OrderDate, c.FirstName, c.LastName
)
SELECT
    OrderID,
    OrderDate,
    CustomerName,
    ROUND(NetRevenue, 2)                                                       AS NetRevenue,
    ROUND(SUM(NetRevenue)  OVER (ORDER BY OrderDate, OrderID
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS RunningTotal,
    ROUND(AVG(NetRevenue)  OVER (ORDER BY OrderDate, OrderID
                                 ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)         AS MovingAvg3,
    ROUND(LAG(NetRevenue)  OVER (ORDER BY OrderDate, OrderID), 2)                      AS PrevOrderRevenue,
    ROUND(LEAD(NetRevenue) OVER (ORDER BY OrderDate, OrderID), 2)                      AS NextOrderRevenue
FROM   OrderNetRevenue
ORDER  BY OrderDate, OrderID;


-- 6.3  NTILE: segment customers into 4 spending quartiles
WITH CustomerSpend AS (
    SELECT
        c.CustomerID,
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.LoyaltyTier,
        ROUND(SUM(oi.Quantity * oi.UnitPrice * (1 - o.Discount / 100.0)), 2) AS TotalSpend
    FROM   dbo.Customers  c
    JOIN   dbo.Orders     o  ON o.CustomerID = c.CustomerID
    JOIN   dbo.OrderItems oi ON oi.OrderID   = o.OrderID
    WHERE  o.Status <> 'Cancelled'
    GROUP  BY c.CustomerID, c.FirstName, c.LastName, c.LoyaltyTier
)
SELECT
    CustomerName,
    LoyaltyTier,
    TotalSpend,
    NTILE(4) OVER (ORDER BY TotalSpend)        AS SpendQuartile,
    PERCENT_RANK() OVER (ORDER BY TotalSpend)  AS PercentRank,
    CUME_DIST()    OVER (ORDER BY TotalSpend)  AS CumulativeDist
FROM   CustomerSpend
ORDER  BY TotalSpend DESC;


-- ============================================================
-- SECTION 7 : AGGREGATIONS & GROUPING
-- ============================================================

-- 7.1  Revenue summary by product category
SELECT
    p.Category,
    COUNT(DISTINCT oi.OrderID)              AS OrderCount,
    SUM(oi.Quantity)                        AS UnitsSold,
    ROUND(SUM(oi.Quantity * oi.UnitPrice), 2) AS GrossRevenue,
    ROUND(AVG(oi.UnitPrice), 2)             AS AvgUnitPrice
FROM   dbo.OrderItems oi
JOIN   dbo.Products   p  ON p.ProductID = oi.ProductID
GROUP  BY p.Category
ORDER  BY GrossRevenue DESC;


-- 7.2  GROUPING SETS: revenue totals at multiple granularities
SELECT
    COALESCE(p.Category,       'ALL CATEGORIES') AS Category,
    COALESCE(o.Status,         'ALL STATUSES')   AS OrderStatus,
    ROUND(SUM(oi.Quantity * oi.UnitPrice * (1 - o.Discount / 100.0)), 2) AS NetRevenue
FROM   dbo.Orders     o
JOIN   dbo.OrderItems oi ON oi.OrderID  = o.OrderID
JOIN   dbo.Products   p  ON p.ProductID = oi.ProductID
GROUP  BY GROUPING SETS (
    (p.Category, o.Status),
    (p.Category),
    (o.Status),
    ()
)
ORDER  BY Category, OrderStatus;


-- 7.3  ROLLUP: department salary by department and manager
SELECT
    d.DepartmentName,
    COALESCE(m.FirstName + ' ' + m.LastName, 'Department Total') AS ManagerName,
    COUNT(e.EmployeeID)     AS HeadCount,
    ROUND(SUM(e.Salary), 2) AS TotalSalary,
    ROUND(AVG(e.Salary), 2) AS AvgSalary
FROM   dbo.Employees  e
JOIN   dbo.Departments d ON d.DepartmentID = e.DepartmentID
LEFT   JOIN dbo.Employees m ON m.EmployeeID = e.ManagerID
WHERE  e.IsActive = 1
GROUP  BY ROLLUP (d.DepartmentName, m.FirstName + ' ' + m.LastName)
ORDER  BY d.DepartmentName, ManagerName;


-- 7.4  HAVING: departments with average salary above 80,000
SELECT
    d.DepartmentName,
    COUNT(e.EmployeeID)     AS HeadCount,
    ROUND(AVG(e.Salary), 2) AS AvgSalary,
    ROUND(MIN(e.Salary), 2) AS MinSalary,
    ROUND(MAX(e.Salary), 2) AS MaxSalary,
    ROUND(SUM(e.Salary), 2) AS TotalSalaryBill
FROM   dbo.Employees  e
JOIN   dbo.Departments d ON d.DepartmentID = e.DepartmentID
WHERE  e.IsActive = 1
GROUP  BY d.DepartmentName
HAVING AVG(e.Salary) > 80000
ORDER  BY AvgSalary DESC;


-- 7.5  Top product per category by units sold (using subquery + RANK)
WITH ProductRank AS (
    SELECT
        p.Category,
        p.ProductName,
        SUM(oi.Quantity)                                             AS UnitsSold,
        ROUND(SUM(oi.Quantity * oi.UnitPrice), 2)                   AS Revenue,
        RANK() OVER (PARTITION BY p.Category ORDER BY SUM(oi.Quantity) DESC) AS Rnk
    FROM   dbo.OrderItems oi
    JOIN   dbo.Products   p ON p.ProductID = oi.ProductID
    GROUP  BY p.Category, p.ProductName
)
SELECT Category, ProductName, UnitsSold, Revenue
FROM   ProductRank
WHERE  Rnk = 1
ORDER  BY Revenue DESC;


-- ============================================================
-- SECTION 8 : ADVANCED T-SQL
-- ============================================================

-- 8.1  PIVOT: monthly orders per order status (last 6 months)
SELECT *
FROM (
    SELECT
        FORMAT(OrderDate, 'yyyy-MM')  AS OrderMonth,
        Status
    FROM   dbo.Orders
    WHERE  OrderDate >= DATEADD(MONTH, -6, GETUTCDATE())
) AS SourceData
PIVOT (
    COUNT(Status)
    FOR Status IN ([Pending],[Processing],[Shipped],[Delivered],[Cancelled])
) AS PivotTable
ORDER  BY OrderMonth;


-- 8.2  MERGE: upsert product stock from a staging table
-- (Simulates receiving a stock update feed)
DECLARE @StockUpdates TABLE (
    ProductName NVARCHAR(200) NOT NULL,
    NewStockQty INT           NOT NULL
);

INSERT INTO @StockUpdates VALUES
('Wireless Keyboard',  250),
('27-inch Monitor',     55),
('Smart Plug Wi-Fi',   400),   -- new product already inserted
('Gaming Headset 7.1', 100);   -- does not exist in Products

MERGE dbo.Products AS target
USING (
    SELECT su.NewStockQty, p.ProductID
    FROM   @StockUpdates su
    JOIN   dbo.Products   p ON p.ProductName = su.ProductName
) AS source (NewStockQty, ProductID)
ON target.ProductID = source.ProductID
WHEN MATCHED THEN
    UPDATE SET target.StockQty = source.NewStockQty
WHEN NOT MATCHED BY SOURCE
    AND target.ProductName = 'Gaming Headset 7.1' THEN
    DELETE;

SELECT ProductName, StockQty
FROM   dbo.Products
WHERE  ProductName IN ('Wireless Keyboard','27-inch Monitor','Smart Plug Wi-Fi')
ORDER  BY ProductName;


-- 8.3  TRY / CATCH: safe insert with error handling
BEGIN TRY
    BEGIN TRANSACTION;

    -- Intentionally try to insert a duplicate email (will fail)
    INSERT INTO dbo.Customers (FirstName, LastName, Email, Phone, City, LoyaltyTier)
    VALUES ('Test', 'Duplicate', 'alice.johnson@retail.com', NULL, 'Denver', 'Bronze');

    COMMIT TRANSACTION;
    PRINT 'INSERT succeeded.';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'Error caught — transaction rolled back.';
    PRINT 'Error Number  : ' + CAST(ERROR_NUMBER()    AS NVARCHAR(10));
    PRINT 'Error Message : ' + ERROR_MESSAGE();
    PRINT 'Error Line    : ' + CAST(ERROR_LINE()      AS NVARCHAR(10));
END CATCH;


-- 8.4  STRING_AGG: list all products per order (comma-separated)
SELECT
    o.OrderID,
    o.OrderDate,
    c.FirstName + ' ' + c.LastName  AS CustomerName,
    o.Status,
    STRING_AGG(p.ProductName, ', ')
        WITHIN GROUP (ORDER BY p.ProductName)  AS ProductList,
    COUNT(oi.OrderItemID)            AS ItemCount,
    ROUND(SUM(oi.Quantity * oi.UnitPrice * (1 - o.Discount / 100.0)), 2) AS NetRevenue
FROM   dbo.Orders     o
JOIN   dbo.Customers  c  ON c.CustomerID = o.CustomerID
JOIN   dbo.OrderItems oi ON oi.OrderID   = o.OrderID
JOIN   dbo.Products   p  ON p.ProductID  = oi.ProductID
GROUP  BY o.OrderID, o.OrderDate, c.FirstName, c.LastName, o.Status
ORDER  BY o.OrderDate DESC;


-- 8.5  EXISTS vs IN performance pattern: customers with a Delivered order
--      EXISTS is generally more efficient for large datasets
SELECT
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.LoyaltyTier
FROM   dbo.Customers c
WHERE  EXISTS (
    SELECT 1
    FROM   dbo.Orders o
    WHERE  o.CustomerID = c.CustomerID
      AND  o.Status     = 'Delivered'
)
ORDER  BY c.LastName;


-- 8.6  Date functions: orders placed in the last 90 days with aging
SELECT
    o.OrderID,
    o.OrderDate,
    o.Status,
    c.FirstName + ' ' + c.LastName  AS CustomerName,
    DATEDIFF(DAY, o.OrderDate, GETUTCDATE())  AS DaysSinceOrder,
    CASE
        WHEN DATEDIFF(DAY, o.OrderDate, GETUTCDATE()) <= 7  THEN 'This Week'
        WHEN DATEDIFF(DAY, o.OrderDate, GETUTCDATE()) <= 30 THEN 'This Month'
        WHEN DATEDIFF(DAY, o.OrderDate, GETUTCDATE()) <= 90 THEN 'Last 90 Days'
        ELSE 'Older'
    END AS OrderAging
FROM   dbo.Orders    o
JOIN   dbo.Customers c ON c.CustomerID = o.CustomerID
WHERE  o.OrderDate >= DATEADD(DAY, -90, GETUTCDATE())
ORDER  BY o.OrderDate DESC;


-- 8.7  JSON output: return order summary as JSON (Azure SQL supports FOR JSON)
SELECT
    o.OrderID,
    o.OrderDate,
    o.Status,
    c.FirstName + ' ' + c.LastName  AS CustomerName,
    (
        SELECT
            p.ProductName,
            oi.Quantity,
            oi.UnitPrice
        FROM   dbo.OrderItems oi
        JOIN   dbo.Products   p ON p.ProductID = oi.ProductID
        WHERE  oi.OrderID = o.OrderID
        FOR JSON PATH
    ) AS ItemsJSON
FROM   dbo.Orders    o
JOIN   dbo.Customers c ON c.CustomerID = o.CustomerID
WHERE  o.Status = 'Delivered'
ORDER  BY o.OrderDate DESC
FOR JSON PATH, ROOT('DeliveredOrders');


-- ============================================================
-- SECTION 9 : FINAL VERIFICATION QUERIES
-- ============================================================

-- Row counts per table
SELECT 'Departments' AS TableName, COUNT(*) AS RowCount FROM dbo.Departments
UNION ALL SELECT 'Employees',  COUNT(*) FROM dbo.Employees
UNION ALL SELECT 'Customers',  COUNT(*) FROM dbo.Customers
UNION ALL SELECT 'Products',   COUNT(*) FROM dbo.Products
UNION ALL SELECT 'Orders',     COUNT(*) FROM dbo.Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems
ORDER  BY TableName;
