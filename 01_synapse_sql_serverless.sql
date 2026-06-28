-- ============================================================================
-- Synapse SQL: Basic Queries & Table Operations
-- Run this in: Synapse Studio > SQL script editor
-- ============================================================================

-- 1. CREATE EXTERNAL DATA SOURCE (pointing to ADLS)
CREATE EXTERNAL DATA SOURCE adls_storage
WITH (
    TYPE = HADOOP,
    LOCATION = 'abfss://container-name@storageaccount.dfs.core.windows.net'
);

-- 2. CREATE EXTERNAL FILE FORMAT for CSV/Parquet
CREATE EXTERNAL FILE FORMAT csv_format
WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS (
        FIELD_TERMINATOR = ',',
        STRING_DELIMITER = '"',
        FIRST_ROW = 2
    )
);

CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET
);

-- 3. CREATE EXTERNAL TABLE reading from ADLS CSV
CREATE EXTERNAL TABLE sales_external (
    SalesID INT,
    CustomerID INT,
    ProductName VARCHAR(100),
    SalesAmount DECIMAL(10,2),
    SalesDate DATE
)
WITH (
    LOCATION = '/raw/sales/',
    DATA_SOURCE = adls_storage,
    FILE_FORMAT = csv_format
);

-- 4. QUERY the external table
SELECT TOP 100
    SalesID,
    CustomerID,
    ProductName,
    SalesAmount,
    SalesDate
FROM sales_external
WHERE SalesDate >= '2024-01-01';

-- 5. CREATE PERMANENT TABLE from external data (recommended for frequent queries)
CREATE TABLE sales_internal AS
SELECT
    SalesID,
    CustomerID,
    ProductName,
    SalesAmount,
    SalesDate
FROM sales_external
WHERE SalesDate >= '2024-01-01';

-- 6. CREATE CLUSTERED COLUMNSTORE INDEX for better performance
CREATE CLUSTERED COLUMNSTORE INDEX cci_sales
ON sales_internal;

-- 7. INSERT additional data
INSERT INTO sales_internal
VALUES
    (1001, 101, 'Laptop', 999.99, '2024-06-20'),
    (1002, 102, 'Mouse', 29.99, '2024-06-21'),
    (1003, 103, 'Keyboard', 79.99, '2024-06-21');

-- 8. AGGREGATION QUERIES
SELECT
    DATEPART(MONTH, SalesDate) AS Month,
    COUNT(*) AS TotalSales,
    SUM(SalesAmount) AS TotalRevenue,
    AVG(SalesAmount) AS AvgSalesAmount
FROM sales_internal
GROUP BY DATEPART(MONTH, SalesDate)
ORDER BY Month DESC;

-- 9. WINDOW FUNCTIONS
SELECT
    SalesID,
    CustomerID,
    SalesAmount,
    SUM(SalesAmount) OVER (PARTITION BY CustomerID ORDER BY SalesDate) AS RunningTotal,
    RANK() OVER (PARTITION BY DATEPART(MONTH, SalesDate) ORDER BY SalesAmount DESC) AS MonthlySalesRank
FROM sales_internal
ORDER BY SalesDate DESC;

-- 10. DROP EXTERNAL TABLE (cleanup)
-- DROP EXTERNAL TABLE sales_external;

-- 11. CREATE STAGING TABLE for data loading
CREATE TABLE stg_sales (
    SalesID INT NOT NULL,
    CustomerID INT NOT NULL,
    ProductName VARCHAR(100),
    SalesAmount DECIMAL(10,2),
    SalesDate DATE,
    LoadedAt DATETIME DEFAULT GETDATE()
);

-- 12. COPY command (modern way to load data from ADLS)
-- COPY INTO stg_sales (SalesID, CustomerID, ProductName, SalesAmount, SalesDate)
-- FROM 'https://storageaccount.dfs.core.windows.net/container-name/raw/sales/'
-- WITH (
--     FILE_TYPE = 'CSV',
--     CREDENTIAL = (IDENTITY = 'Shared Access Signature', SECRET = 'sv=...')
-- );

-- 13. CROSS DATABASE QUERY (if multiple databases exist)
SELECT
    s.SalesID,
    s.SalesAmount,
    c.CustomerName
FROM sales_internal s
INNER JOIN [database_name].dbo.customers c
ON s.CustomerID = c.CustomerID;

-- 14. EXPLAIN PLAN to view query execution
-- Run this to understand query optimization
EXPLAIN
SELECT
    SalesID,
    SUM(SalesAmount) as TotalAmount
FROM sales_internal
GROUP BY SalesID;

-- 15. VIEW CREATION for business logic encapsulation
CREATE VIEW vw_sales_summary AS
SELECT
    SalesID,
    CustomerID,
    ProductName,
    SalesAmount,
    YEAR(SalesDate) AS SalesYear,
    MONTH(SalesDate) AS SalesMonth,
    GETDATE() AS ViewGeneratedAt
FROM sales_internal
WHERE SalesDate >= DATEADD(YEAR, -1, GETDATE());

-- 16. QUERY the view
SELECT * FROM vw_sales_summary WHERE SalesYear = YEAR(GETDATE());
