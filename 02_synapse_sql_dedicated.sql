-- ============================================================================
-- Synapse SQL: Advanced Patterns (Incremental Loads, Partitioning, SCD Type 2)
-- ============================================================================

-- 1. CREATE STAGING TABLE with metadata columns
CREATE TABLE stg_customer_data (
    CustomerID INT,
    CustomerName VARCHAR(100),
    Email VARCHAR(100),
    Country VARCHAR(50),
    LoadDate DATE DEFAULT CAST(GETDATE() AS DATE),
    SourceHash BINARY(16),
    LoadedAt DATETIME2 DEFAULT GETDATE()
)
WITH (
    HEAP
);

-- 2. CREATE PARTITIONED TABLE for large datasets
CREATE TABLE fact_sales_partitioned (
    SalesID INT NOT NULL,
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    SalesAmount DECIMAL(10,2),
    SalesDate DATE NOT NULL,
    LoadedAt DATETIME2 DEFAULT GETDATE()
)
WITH (
    DISTRIBUTION = HASH(CustomerID),
    CLUSTERED COLUMNSTORE INDEX
)
PARTITION BY RANGE LEFT FOR VALUES (
    '2023-01-01',
    '2024-01-01',
    '2025-01-01',
    '2026-01-01'
);

-- 3. MERGE statement for incremental load (SCD Type 2)
MERGE INTO dim_customer AS Target
USING stg_customer_data AS Source
ON Target.CustomerID = Source.CustomerID
-- Update existing records when data changes
WHEN MATCHED AND Target.SourceHash != Source.SourceHash THEN
    UPDATE SET
        CustomerName = Source.CustomerName,
        Email = Source.Email,
        Country = Source.Country,
        UpdatedAt = GETDATE(),
        IsActive = 1
-- Insert new records
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CustomerID, CustomerName, Email, Country, IsActive, CreatedAt, UpdatedAt)
    VALUES (Source.CustomerID, Source.CustomerName, Source.Email, Source.Country, 1, GETDATE(), GETDATE())
-- Mark records as inactive if they don't exist in source
WHEN NOT MATCHED BY SOURCE AND Target.IsActive = 1 THEN
    UPDATE SET IsActive = 0, UpdatedAt = GETDATE();

-- 4. COMPUTE HASH for change detection
WITH source_data AS (
    SELECT
        CustomerID,
        CustomerName,
        Email,
        Country,
        HASHBYTES('MD5', CONCAT(CustomerName, Email, Country)) AS SourceHash
    FROM stg_customer_data
)
SELECT * FROM source_data;

-- 5. INCREMENTAL LOAD PATTERN (only process new/changed data)
DECLARE @LastLoadDate DATETIME2 = (SELECT MAX(LoadedAt) FROM fact_sales_partitioned);

INSERT INTO fact_sales_partitioned (SalesID, CustomerID, ProductID, SalesAmount, SalesDate)
SELECT
    SalesID,
    CustomerID,
    ProductID,
    SalesAmount,
    SalesDate
FROM sales_external
WHERE SalesDate > CAST(@LastLoadDate AS DATE)
AND SalesDate <= CAST(GETDATE() AS DATE);

-- 6. CREATE STATISTICS for query optimization
CREATE STATISTICS stat_sales_date ON fact_sales_partitioned(SalesDate);
CREATE STATISTICS stat_customer_id ON fact_sales_partitioned(CustomerID);

-- 7. UPDATE STATISTICS (run after large loads)
UPDATE STATISTICS fact_sales_partitioned (stat_sales_date);

-- 8. IDENTITY COLUMN for auto-incrementing primary key
CREATE TABLE audit_log (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TableName VARCHAR(100),
    OperationType VARCHAR(10),
    RowsAffected INT,
    ExecutedAt DATETIME2 DEFAULT GETDATE()
);

-- 9. INSERT with OUTPUT clause to capture generated IDs
INSERT INTO audit_log (TableName, OperationType, RowsAffected)
OUTPUT INSERTED.AuditID, INSERTED.ExecutedAt
VALUES ('fact_sales_partitioned', 'INSERT', @@ROWCOUNT);

-- 10. STORED PROCEDURE for modular data loading
CREATE PROCEDURE sp_load_sales_data
    @LoadDate DATE,
    @PartitionValue DATE
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO stg_sales (SalesID, CustomerID, ProductName, SalesAmount, SalesDate)
        SELECT
            SalesID,
            CustomerID,
            ProductName,
            SalesAmount,
            SalesDate
        FROM sales_external
        WHERE CAST(SalesDate AS DATE) = @LoadDate;

        INSERT INTO fact_sales_partitioned (SalesID, CustomerID, ProductID, SalesAmount, SalesDate)
        SELECT
            s.SalesID,
            s.CustomerID,
            p.ProductID,
            s.SalesAmount,
            s.SalesDate
        FROM stg_sales s
        LEFT JOIN dim_product p ON s.ProductName = p.ProductName;

        COMMIT TRANSACTION;
        PRINT 'Data load completed successfully';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error occurred: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;

-- 11. EXECUTE stored procedure
-- EXEC sp_load_sales_data @LoadDate = '2024-06-21', @PartitionValue = '2024-01-01';

-- 12. ROLE-BASED ACCESS CONTROL
CREATE ROLE data_analyst;
GRANT SELECT ON SCHEMA::dbo TO data_analyst;
-- GRANT SELECT ON fact_sales_partitioned TO data_analyst;

-- 13. DYNAMIC SQL for flexible queries
DECLARE @TableName NVARCHAR(100) = 'fact_sales_partitioned';
DECLARE @Query NVARCHAR(MAX) = 'SELECT TOP 10 * FROM ' + @TableName + ' ORDER BY SalesDate DESC';
EXEC sp_executesql @Query;

-- 14. TEMPORARY TABLE (session-scoped)
CREATE TABLE #temp_sales (
    SalesID INT,
    SalesAmount DECIMAL(10,2),
    CalculatedPercent DECIMAL(5,2)
);

INSERT INTO #temp_sales
SELECT
    SalesID,
    SalesAmount,
    ROUND(SalesAmount * 100 / SUM(SalesAmount) OVER (), 2) AS CalculatedPercent
FROM fact_sales_partitioned;

SELECT * FROM #temp_sales;

-- 15. BEST PRACTICES: Query with query hints
SELECT TOP 100
    SalesID,
    CustomerID,
    SalesAmount
FROM fact_sales_partitioned
WHERE SalesDate >= '2024-01-01'
OPTION (RECOMPILE);

-- 16. TRUNCATE + LOAD pattern (for full refresh)
-- TRUNCATE TABLE stg_customer_data;
-- INSERT INTO stg_customer_data (...)
-- SELECT ... FROM sales_external;
