-- ============================================================================
-- Azure Synapse: DEDICATED SQL POOL - Advanced Patterns & Table Distributions
-- Purpose: Demonstration of distributed table types, data loading, partitioning
-- Status: Production-ready patterns for large-scale data warehousing
-- ============================================================================

-- ============================================================================
-- STEP 1: Setup for Dedicated SQL Pool
-- ============================================================================

-- Create Credential for ADLS access
CREATE DATABASE DEDICATED 
or create dedicated SQL pool if not already created



-- ============================================================================
-- STEP 2: Create External Data Source for Dedicated SQL Pool
-- Purpose: Establish connection to ADLS Gen2 for reading/writing data
-- ============================================================================

CREATE EXTERNAL DATA SOURCE adls_storage_dedicated
WITH (
    LOCATION = 'abfss://maybarch-adlsgen2@maybatchtrainingadls.dfs.core.windows.net/'
);

-- ============================================================================
-- STEP 3: Create External File Formats
-- Purpose: Define how to parse CSV and Parquet files from ADLS
-- ============================================================================

-- 3.1 CSV File Format
CREATE EXTERNAL FILE FORMAT csv_format_dedicated
WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS (
        FIELD_TERMINATOR = ',',
        STRING_DELIMITER = '"',
        FIRST_ROW = 2,
        ENCODING = 'UTF8'
    )
);

-- 3.2 Parquet File Format
CREATE EXTERNAL FILE FORMAT parquet_format_dedicated
WITH (
    FORMAT_TYPE = PARQUET
);

-- ============================================================================
-- STEP 4: Create External Table (Source Data from ADLS)
-- Purpose: Virtual table pointing to customers.csv in ADLS
-- Note: External tables in Dedicated pools work differently than Serverless
-- ============================================================================

CREATE EXTERNAL TABLE customers_external_dedicated (
    customer_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE
)
WITH (
    LOCATION = '/datasets/customers.csv',
    DATA_SOURCE = adls_storage_dedicated,
    FILE_FORMAT = csv_format_dedicated
);

-- ============================================================================
-- STEP 5: Create Staging Table (Temporary, No Distribution)
-- Purpose: Landing zone for raw data before transformation
-- Benefits:
--   - No indexing overhead
--   - Fast data ingestion
--   - Easy to truncate and reload
-- Distribution: HEAP (no distribution)
-- ============================================================================

CREATE TABLE stg_customer_data (
    customer_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE,
    loaded_at DATETIME2 DEFAULT '2026-06-29 00:00:00'
)
WITH (
    HEAP
);

-- ============================================================================
-- STEP 6: Load Data into Staging Table
-- Purpose: Import raw data from external table
-- Method: Simple INSERT INTO ... SELECT
-- ============================================================================


INSERT INTO stg_customer_data (customer_id, customer_name, email, phone, address, created_at)
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at
FROM customers_external_dedicated;

-- Verify load
SELECT COUNT(*) as Staging_Records FROM stg_customer_data;

-- ============================================================================
-- ============================================================================
-- DISTRIBUTION TYPE 1: ROUND_ROBIN DISTRIBUTION
-- ============================================================================
-- ============================================================================

-- Purpose: Data distributed evenly across all compute nodes
-- Best For:
--   - Staging tables
--   - Small reference data
--   - When no natural distribution key exists
--   - During initial data ingestion
-- Performance: Fast loads, slower queries (no co-location)
-- ============================================================================

CREATE TABLE customers_roundrobin (
    customer_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE,
    loaded_at DATETIME2 DEFAULT '2026-06-29 00:00:00',
    data_quality_flag VARCHAR(10) DEFAULT 'PASS'
)
WITH (
    DISTRIBUTION = ROUND_ROBIN,
    CLUSTERED COLUMNSTORE INDEX
);

-- Load data into ROUND_ROBIN table
INSERT INTO customers_roundrobin (customer_id, customer_name, email, phone, address, created_at)
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at
FROM stg_customer_data;

-- Verify ROUND_ROBIN table
SELECT
    'ROUND_ROBIN' as Distribution_Type,
    COUNT(*) as Total_Records,
    COUNT(DISTINCT customer_id) as Unique_Customers
FROM customers_roundrobin;

-- ============================================================================
-- ============================================================================
-- DISTRIBUTION TYPE 2: HASH DISTRIBUTION
-- ============================================================================
-- ============================================================================

-- Purpose: Data distributed based on hash of a column value
-- Distribution Key: customer_id (chosen for optimal distribution)
-- Best For:
--   - Large fact tables
--   - Frequent joins on the distribution key
--   - Co-location of related data
-- Performance: Faster queries (co-location), moderate load speed
-- ============================================================================

CREATE TABLE customers_hash (
    customer_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE,
    loaded_at DATETIME2 DEFAULT '2026-06-29 00:00:00',
    data_quality_flag VARCHAR(10) DEFAULT 'PASS'
)
WITH (
    DISTRIBUTION = HASH(customer_id),
    CLUSTERED COLUMNSTORE INDEX
);

-- Load data into HASH distributed table
INSERT INTO customers_hash (customer_id, customer_name, email, phone, address, created_at)
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at
FROM stg_customer_data;

-- Verify HASH distribution
SELECT
    'HASH' as Distribution_Type,
    COUNT(*) as Total_Records,
    COUNT(DISTINCT customer_id) as Unique_Customers
FROM customers_hash;

-- ============================================================================
-- ============================================================================
-- DISTRIBUTION TYPE 3: REPLICATE DISTRIBUTION
-- ============================================================================
-- ============================================================================

-- Purpose: Complete copy of table on every compute node
-- Best For:
--   - Small dimension tables
--   - Lookup tables (< 2GB)
--   - Tables used in joins with large fact tables
-- Performance: Fastest queries (no data movement), slower loads
-- Note: Increases storage but eliminates join shuffling
-- ============================================================================

CREATE TABLE customers_replicate (
    customer_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE,
    loaded_at DATETIME2 DEFAULT '2026-06-29 00:00:00',
    data_quality_flag VARCHAR(10) DEFAULT 'PASS'
)
WITH (
    DISTRIBUTION = REPLICATE,
    CLUSTERED COLUMNSTORE INDEX
);

-- Load data into REPLICATE distributed table
INSERT INTO customers_replicate (customer_id, customer_name, email, phone, address, created_at)
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at
FROM stg_customer_data;

-- Verify REPLICATE distribution
SELECT
    'REPLICATE' as Distribution_Type,
    COUNT(*) as Total_Records,
    COUNT(DISTINCT customer_id) as Unique_Customers
FROM customers_replicate;

-- ============================================================================
-- STEP 7: Compare All Three Distribution Types
-- Purpose: Show data in all three distributed tables
-- ============================================================================

SELECT 'ROUND_ROBIN' as Distribution_Type, customer_id, customer_name FROM customers_roundrobin UNION ALL
SELECT 'HASH' as Distribution_Type, customer_id, customer_name FROM customers_hash UNION ALL
SELECT 'REPLICATE' as Distribution_Type, customer_id, customer_name FROM customers_replicate
ORDER BY Distribution_Type, customer_id
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

-- ============================================================================
-- STEP 8: Create Partitioned Fact Table (Advanced Scenario)
-- Purpose: Large fact table with hash distribution AND date partitioning
-- Use Case: Sales transactions partitioned by date + distributed by customer
-- ============================================================================

CREATE TABLE fact_sales_partitioned_hash (
    sales_id INT NOT NULL,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    sales_amount DECIMAL(10,2),
    sales_date DATE NOT NULL,
    loaded_at DATETIME2 DEFAULT '2026-06-29 00:00:00'
)
WITH (
    DISTRIBUTION = HASH(customer_id),
    CLUSTERED COLUMNSTORE INDEX,
    PARTITION ( sales_date RANGE LEFT FOR VALUES (
        '2023-01-01',
        '2024-01-01',
        '2025-01-01',
        '2026-01-01'
    ))
);

-- ============================================================================
-- STEP 9: Create Statistics for Query Optimization
-- Purpose: Enable SQL optimizer to generate efficient query plans
-- Statistics: Created on frequently filtered/joined columns
-- Impact: Significant performance improvement for queries
-- ============================================================================

-- Statistics for customers_hash table
CREATE STATISTICS stat_customer_id_hash ON customers_hash(customer_id);
CREATE STATISTICS stat_created_date_hash ON customers_hash(created_at);
CREATE STATISTICS stat_email_hash ON customers_hash(email);

-- Statistics for fact table
CREATE STATISTICS stat_customer_sales ON fact_sales_partitioned_hash(customer_id);
CREATE STATISTICS stat_sales_date ON fact_sales_partitioned_hash(sales_date);

-- Update statistics after large loads
UPDATE STATISTICS customers_hash;
UPDATE STATISTICS customers_replicate;

-- ============================================================================
-- STEP 11: Data Quality Checks
-- Purpose: Validate data integrity across all tables
-- ============================================================================

-- Check null values
SELECT
    'customers_hash' as Table_Name,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) as Null_customer_id,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as Null_emails,
    SUM(CASE WHEN phone IS NULL THEN 1 ELSE 0 END) as Null_phones
FROM customers_hash
UNION ALL
SELECT
    'customers_replicate' as Table_Name,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) as Null_customer_id,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as Null_emails,
    SUM(CASE WHEN phone IS NULL THEN 1 ELSE 0 END) as Null_phones
FROM customers_replicate;

-- ============================================================================
-- STEP 12: Performance Comparison Queries
-- Purpose: Test query performance across distribution types
-- ============================================================================

-- Query 1: Simple count (tests distribution overhead)
SELECT COUNT(*) FROM customers_roundrobin;
SELECT COUNT(*) FROM customers_hash;
SELECT COUNT(*) FROM customers_replicate;

-- Query 2: Filtered query (tests column filtering)
SELECT customer_id, customer_name, email
FROM customers_hash
WHERE created_at >= '2022-06-01'
ORDER BY customer_id;

-- Query 3: Aggregation (tests distribution performance)
SELECT
    COUNT(*) as Total_Customers,
    COUNT(DISTINCT email) as Unique_Emails,
    YEAR(created_at) as Registration_Year
FROM customers_hash
GROUP BY YEAR(created_at);

-- ============================================================================
-- STEP 13: Create View for Unified Access
-- Purpose: Simplify access to best-performing table (HASH)
-- ============================================================================

CREATE VIEW vw_customers_optimized AS
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at,
    loaded_at,
    data_quality_flag
FROM customers_hash;

-- Query the view
SELECT TOP 10 * FROM vw_customers_optimized ORDER BY customer_id;

-- ============================================================================
-- STEP 14: Drop Staging Table (after successful load)
-- Purpose: Clean up temporary objects to free resources
-- Note: Only run after verifying all tables have correct data
-- ============================================================================

-- TRUNCATE TABLE stg_customer_data;
-- DROP TABLE stg_customer_data;

-- ============================================================================
-- SUMMARY: Distribution Type Comparison
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────┐
│ DISTRIBUTION TYPE COMPARISON                                            │
├──────────────┬──────────────┬──────────────┬────────────────────────────┤
│ Attribute    │ ROUND_ROBIN  │ HASH         │ REPLICATE                  │
├──────────────┼──────────────┼──────────────┼────────────────────────────┤
│ Storage      │ Normal       │ Normal       │ 3x (replicated per node)   │
│ Load Speed   │ Fastest      │ Medium       │ Slowest                    │
│ Query Speed  │ Slow         │ Fastest      │ Fastest                    │
│ Join Perf    │ Shuffle join │ Co-located   │ No shuffle                 │
│ Best For     │ Staging      │ Fact tables  │ Dimension tables           │
│ Size Limit   │ Unlimited    │ Unlimited    │ 2GB recommended max        │
│ Join Cost    │ High         │ Low          │ None                       │
└──────────────┴──────────────┴──────────────┴────────────────────────────┘

SELECTION CRITERIA:
─────────────────
• ROUND_ROBIN: Staging, temporary tables, unknown distribution key
• HASH: Large fact tables, frequent joins, natural distribution key exists
• REPLICATE: Small dimensions (<2GB), joined with large fact tables

PERFORMANCE IMPACT:
──────────────────
Query Optimization:
  - HASH distribution on join key → Eliminates shuffle joins
  - REPLICATE → Eliminates all join shuffles
  - ROUND_ROBIN → All joins require shuffle

Loading Performance:
  - ROUND_ROBIN: Fastest (parallel load, no hash computation)
  - HASH: Medium (hash key must be computed)
  - REPLICATE: Slowest (must replicate to all nodes)
*/

-- ============================================================================
-- ============================================================================
-- STEP 15: BULK DATA LOADING USING COPY STATEMENT (High-Performance Method)
-- ============================================================================
-- ============================================================================

/*
PURPOSE: Load bulk data from ADLS directly into Synapse managed tables
WHY COPY is better than INSERT INTO SELECT:
  - 3-5x faster than INSERT INTO SELECT
  - Optimized for distributed processing
  - Better resource management
  - Native support for various file formats (PARQUET, CSV, ORC)
  - Direct ADLS to Synapse without external tables
  - Supports automatic error handling and logging
*/

-- ============================================================================
-- STEP 15.1: Create Managed Table for COPY Loading (Parquet Format)
-- Purpose: Optimized table for high-performance bulk loading
-- Distribution: HASH on customer_id for better query performance
-- ============================================================================

CREATE TABLE customers_managed_copy_parquet (
    customer_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE NOT NULL,
    loaded_at DATETIME2 DEFAULT CAST(GETDATE() AS DATETIME2),
    load_batch_id INT
)
WITH (
    DISTRIBUTION = HASH(customer_id),
    CLUSTERED COLUMNSTORE INDEX,
    PARTITION (created_at RANGE LEFT FOR VALUES (
        '2020-01-01',
        '2022-01-01',
        '2024-01-01',
        '2026-01-01'
    ))
);

-- ============================================================================
-- STEP 15.2: COPY INTO - Load Parquet Data from ADLS (Managed Identity)
-- Purpose: High-performance bulk load from ADLS transformed_data location
-- Authentication: Managed Identity (recommended for Synapse)
-- File Format: Parquet (columnar, compressed)
-- Source: Customers data in parquet format from ADLS
-- ============================================================================

COPY INTO customers_managed_copy_parquet
    (customer_id, customer_name, email, phone, address, created_at, load_batch_id)
FROM 'https://maybatchtrainingadls.dfs.core.windows.net/maybarch-adlsgen2/transformed_data/customers/'
WITH (
    FILE_TYPE = 'PARQUET',
    CREDENTIAL = (IDENTITY = 'Managed Identity'),
    ERRORFILE = 'https://maybatchtrainingadls.dfs.core.windows.net/maybarch-adlsgen2/error_logs/customers_errors/',
    ERROR_RETENTION_DAYS = 30,
    ROWS_PER_FILE = 0,
    MAXERRORS = 10000
);

-- Verify COPY load
SELECT
    'COPY - Parquet Load' as Load_Method,
    COUNT(*) as Records_Loaded,
    COUNT(DISTINCT customer_id) as Unique_Customers,
    MIN(created_at) as Earliest_Date,
    MAX(created_at) as Latest_Date
FROM customers_managed_copy_parquet;

-- ============================================================================
-- STEP 15.3: Create Managed Table for CSV Data Loading
-- Purpose: Load raw CSV data directly from ADLS datasets folder
-- Distribution: ROUND_ROBIN (for staging)
-- ============================================================================

CREATE TABLE customers_managed_copy_csv (
    customer_id INT NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE,
    loaded_at DATETIME2 DEFAULT CAST(GETDATE() AS DATETIME2),
    load_batch_id INT
)
WITH (
    DISTRIBUTION = ROUND_ROBIN,
    HEAP
);

-- ============================================================================
-- STEP 15.4: COPY INTO - Load CSV Data from ADLS (Storage Account Key)
-- Purpose: Load raw customers.csv with explicit column mapping
-- Authentication: Storage Account Key (alternative to Managed Identity)
-- File Format: CSV
-- Source: Raw data in datasets folder
-- ============================================================================

COPY INTO customers_managed_copy_csv
    (customer_id, customer_name, email, phone, address, created_at)
FROM 'https://maybatchtrainingadls.dfs.core.windows.net/maybarch-adlsgen2/datasets/customers.csv'
WITH (
    FILE_TYPE = 'CSV',
    CREDENTIAL = (
        IDENTITY = 'Storage Account Key',
        SECRET = 'your-storage-account-key-here'
    ),
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    ERRORFILE = 'https://maybatchtrainingadls.dfs.core.windows.net/maybarch-adlsgen2/error_logs/customers_csv_errors/',
    ERROR_RETENTION_DAYS = 30,
    MAXERRORS = 5000
);

-- Verify CSV COPY load
SELECT
    'COPY - CSV Load' as Load_Method,
    COUNT(*) as Records_Loaded,
    COUNT(DISTINCT customer_id) as Unique_Customers,
    MIN(created_at) as Earliest_Date,
    MAX(created_at) as Latest_Date
FROM customers_managed_copy_csv;

-- ============================================================================
-- STEP 15.5: TEST SUITE - Data Quality Validation
-- ============================================================================

-- TEST 1: Row Count Comparison
-- Purpose: Verify all tables have consistent record counts
-- ============================================================================
PRINT '========== TEST 1: ROW COUNT COMPARISON ==========';
SELECT
    'customers_roundrobin' as Table_Name,
    COUNT(*) as Total_Rows
FROM customers_roundrobin
UNION ALL
SELECT
    'customers_hash' as Table_Name,
    COUNT(*) as Total_Rows
FROM customers_hash
UNION ALL
SELECT
    'customers_replicate' as Table_Name,
    COUNT(*) as Total_Rows
FROM customers_replicate
UNION ALL
SELECT
    'customers_managed_copy_parquet' as Table_Name,
    COUNT(*) as Total_Rows
FROM customers_managed_copy_parquet
UNION ALL
SELECT
    'customers_managed_copy_csv' as Table_Name,
    COUNT(*) as Total_Rows
FROM customers_managed_copy_csv
ORDER BY Table_Name;

-- TEST 2: NULL Value Check
-- Purpose: Identify any unexpected NULL values that indicate data quality issues
-- ============================================================================
PRINT '========== TEST 2: NULL VALUE CHECK ==========';
SELECT
    'customers_managed_copy_parquet' as Table_Name,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) as Null_customer_id,
    SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) as Null_customer_name,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as Null_email,
    SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) as Null_created_at
FROM customers_managed_copy_parquet
UNION ALL
SELECT
    'customers_managed_copy_csv' as Table_Name,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) as Null_customer_id,
    SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) as Null_customer_name,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as Null_email,
    SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) as Null_created_at
FROM customers_managed_copy_csv;

-- TEST 3: Duplicate Check
-- Purpose: Identify duplicate customer records
-- ============================================================================
PRINT '========== TEST 3: DUPLICATE CUSTOMER CHECK ==========';
SELECT
    'customers_managed_copy_parquet' as Table_Name,
    customer_id,
    COUNT(*) as Duplicate_Count
FROM customers_managed_copy_parquet
GROUP BY customer_id
HAVING COUNT(*) > 1
UNION ALL
SELECT
    'customers_managed_copy_csv' as Table_Name,
    customer_id,
    COUNT(*) as Duplicate_Count
FROM customers_managed_copy_csv
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- TEST 4: Data Type Validation
-- Purpose: Verify all columns have valid data types
-- ============================================================================
PRINT '========== TEST 4: DATA TYPE VALIDATION ==========';
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    created_at,
    SQL_VARIANT_PROPERTY(customer_id, 'BaseType') as customer_id_type,
    SQL_VARIANT_PROPERTY(created_at, 'BaseType') as created_at_type
FROM customers_managed_copy_parquet
UNION ALL
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    created_at,
    SQL_VARIANT_PROPERTY(customer_id, 'BaseType') as customer_id_type,
    SQL_VARIANT_PROPERTY(created_at, 'BaseType') as created_at_type
FROM customers_managed_copy_csv;

-- TEST 5: Date Range Validation
-- Purpose: Verify created_at dates are within expected range
-- ============================================================================
PRINT '========== TEST 5: DATE RANGE VALIDATION ==========';
SELECT
    'customers_managed_copy_parquet' as Table_Name,
    MIN(created_at) as Min_Date,
    MAX(created_at) as Max_Date,
    DATEDIFF(DAY, MIN(created_at), MAX(created_at)) as Date_Span_Days,
    COUNT(*) as Total_Records
FROM customers_managed_copy_parquet
WHERE created_at IS NOT NULL
UNION ALL
SELECT
    'customers_managed_copy_csv' as Table_Name,
    MIN(created_at) as Min_Date,
    MAX(created_at) as Max_Date,
    DATEDIFF(DAY, MIN(created_at), MAX(created_at)) as Date_Span_Days,
    COUNT(*) as Total_Records
FROM customers_managed_copy_csv
WHERE created_at IS NOT NULL;

-- TEST 6: Email Format Validation
-- Purpose: Check for valid email format (basic check)
-- ============================================================================
PRINT '========== TEST 6: EMAIL FORMAT VALIDATION ==========';
SELECT
    'customers_managed_copy_parquet' as Table_Name,
    COUNT(*) as Total_Records,
    SUM(CASE WHEN email LIKE '%@%' THEN 1 ELSE 0 END) as Valid_Email_Format,
    SUM(CASE WHEN email NOT LIKE '%@%' AND email IS NOT NULL THEN 1 ELSE 0 END) as Invalid_Email_Format,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as Null_Email
FROM customers_managed_copy_parquet
UNION ALL
SELECT
    'customers_managed_copy_csv' as Table_Name,
    COUNT(*) as Total_Records,
    SUM(CASE WHEN email LIKE '%@%' THEN 1 ELSE 0 END) as Valid_Email_Format,
    SUM(CASE WHEN email NOT LIKE '%@%' AND email IS NOT NULL THEN 1 ELSE 0 END) as Invalid_Email_Format,
    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) as Null_Email
FROM customers_managed_copy_csv;

-- TEST 7: Distribution Key Skew Check
-- Purpose: Verify hash distribution is balanced across nodes
-- ============================================================================
PRINT '========== TEST 7: DISTRIBUTION SKEW CHECK ==========';
SELECT
    'customers_managed_copy_parquet' as Table_Name,
    customer_id % 60 as Distribution_Bucket,
    COUNT(*) as Records_In_Bucket,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customers_managed_copy_parquet) AS DECIMAL(10,2)) as Percent_Of_Total
FROM customers_managed_copy_parquet
GROUP BY customer_id % 60
ORDER BY Records_In_Bucket DESC;

-- TEST 8: Comprehensive Summary Report
-- Purpose: Overall data quality score and summary
-- ============================================================================
PRINT '========== TEST 8: COMPREHENSIVE QUALITY SUMMARY ==========';
SELECT
    'Parquet Load' as Load_Source,
    COUNT(*) as Total_Records,
    COUNT(DISTINCT customer_id) as Unique_Records,
    CAST(100.0 * COUNT(DISTINCT customer_id) / COUNT(*) AS DECIMAL(10,2)) as Uniqueness_Percent,
    SUM(CASE WHEN customer_id IS NOT NULL
            AND customer_name IS NOT NULL
            AND created_at IS NOT NULL THEN 1 ELSE 0 END) as Complete_Records,
    CAST(100.0 * SUM(CASE WHEN customer_id IS NOT NULL
                          AND customer_name IS NOT NULL
                          AND created_at IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(10,2)) as Completeness_Percent
FROM customers_managed_copy_parquet
UNION ALL
SELECT
    'CSV Load' as Load_Source,
    COUNT(*) as Total_Records,
    COUNT(DISTINCT customer_id) as Unique_Records,
    CAST(100.0 * COUNT(DISTINCT customer_id) / COUNT(*) AS DECIMAL(10,2)) as Uniqueness_Percent,
    SUM(CASE WHEN customer_id IS NOT NULL
            AND customer_name IS NOT NULL
            AND created_at IS NOT NULL THEN 1 ELSE 0 END) as Complete_Records,
    CAST(100.0 * SUM(CASE WHEN customer_id IS NOT NULL
                          AND customer_name IS NOT NULL
                          AND created_at IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(10,2)) as Completeness_Percent
FROM customers_managed_copy_csv;

-- ============================================================================
-- STEP 15.6: Performance Comparison - COPY vs INSERT INTO SELECT
-- ============================================================================

PRINT '========== PERFORMANCE COMPARISON ==========';
/*
COPY Statement Benefits:
✓ 3-5x faster than INSERT INTO SELECT
✓ Better CPU and memory usage
✓ Supports parallel loading from ADLS
✓ Direct streaming to Synapse (no external table needed)
✓ Built-in error logging and retry logic
✓ Skips header rows automatically
✓ Supports multiple file formats

When to use COPY:
- Bulk data loading from data lake
- Initial data warehouse population
- High-volume ETL pipelines
- Minimal transformation needed

When to use INSERT INTO SELECT:
- Complex transformations required
- Need to filter/join data during load
- Integration with data pipeline orchestration
- Small-scale loads
*/

-- ============================================================================
-- KEY TAKEAWAYS FOR DEDICATED SQL POOLS
-- ============================================================================
/*
1. ALWAYS choose a distribution strategy based on query patterns
2. HASH on frequently joined columns
3. REPLICATE small reference tables
4. Use ROUND_ROBIN only for staging/temporary data
5. Create statistics after large data loads
6. Monitor distribution skew
7. Use partitioning for large tables (100GB+)
8. Test query plans before production deployment
9. Use COPY for bulk loading - 3-5x faster than INSERT INTO SELECT
10. Always run test suites after data loads to validate quality
11. Enable error logging in COPY for debugging
12. Use Managed Identity for authentication (more secure than keys)
*/
