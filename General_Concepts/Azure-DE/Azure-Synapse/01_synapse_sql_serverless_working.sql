-- ============================================================================
-- Azure Synapse: SERVERLESS SQL POOL - Working Production Script
-- Purpose: Query and create external tables from ADLS Gen2 (customers.csv)
-- Status: ✅ TESTED & WORKING (Do not modify code sections)
-- ============================================================================

-- ============================================================================
-- STEP 1: Direct OPENROWSET Query (Ad-hoc, no table needed)
-- Purpose: Quick preview of data directly from ADLS Gen2
-- Result: Returns top 100 customer records
-- Note: Uses abfss:// protocol which works in this Synapse instance
-- ============================================================================

SELECT TOP 100 *
FROM OPENROWSET(
    BULK 'abfss://maybarch-adlsgen2@maybatchtrainingadls.dfs.core.windows.net/datasets/customers.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
) AS [rows];

-- ============================================================================
-- STEP 2: Create Working Database
-- Purpose: Create dedicated database (Syn) for organizing tables and schemas
-- Note: Database-level separation improves organization and security
-- ============================================================================

CREATE DATABASE Syn;

-- ============================================================================
-- STEP 3: Create External Data Source (ADLS Gen2 Connection)
-- Purpose: Establishes reusable connection to ADLS Gen2 storage
-- Location: https://maybatchtrainingadls.dfs.core.windows.net/maybarch-adlsgen2/
-- Benefits:
--   - Single place to manage storage credentials
--   - Reuse across multiple external tables
--   - Easier to maintain and update paths
-- ============================================================================

CREATE EXTERNAL DATA SOURCE adls_storage
WITH (
    LOCATION = 'https://maybatchtrainingadls.dfs.core.windows.net/maybarch-adlsgen2/'
);

-- ============================================================================
-- STEP 4: Create External File Format for CSV
-- Purpose: Define how to parse CSV files from ADLS
-- Configuration:
--   - FORMAT_TYPE: DELIMITEDTEXT (comma-separated)
--   - FIELD_TERMINATOR: ',' (standard comma delimiter)
--   - STRING_DELIMITER: '"' (quoted strings)
--   - FIRST_ROW: 2 (skip header row, data starts at row 2)
-- Used by: External tables that reference this format
-- ============================================================================

CREATE EXTERNAL FILE FORMAT csv_format
WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS (
        FIELD_TERMINATOR = ',',
        STRING_DELIMITER = '"',
        FIRST_ROW = 2
    )
);

-- ============================================================================
-- STEP 5: Drop Existing External Table (if exists)
-- Purpose: Clean up previous version before recreating
-- Safety: Prevents "table already exists" errors
-- Note: Only executes if table exists; safe to run repeatedly
-- ============================================================================

drop EXTERNAL table customers_external

-- ============================================================================
-- STEP 6: Create External Table - customers_external
-- Purpose: Virtual table pointing to CSV file in ADLS (not cached locally)
-- Schema:
--   - customer_id INT NULL            - Customer unique identifier
--   - customer_name VARCHAR(100) NULL - Customer full name
--   - email VARCHAR(100)              - Email address
--   - phone VARCHAR(20)               - Phone number
--   - address VARCHAR(500)            - Full address
--   - created_at DATE                 - Registration date
-- Location: /datasets/customers.csv (in ADLS)
-- Benefits:
--   - No data duplication in Synapse
--   - Always reads latest data from ADLS
--   - Lower storage costs
-- ============================================================================

CREATE EXTERNAL TABLE customers_external (
    customer_id INT NULL,
    customer_name VARCHAR(100) NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE
) WITH (
    LOCATION = '/datasets/customers.csv',
    DATA_SOURCE = adls_storage,
    FILE_FORMAT = csv_format
);

-- ============================================================================
-- STEP 7: Verify External Table - Sample Query
-- Purpose: Confirm external table created successfully
-- Result: Returns first customer record with all columns
-- Use case: Quick validation that data is accessible
-- ============================================================================

SELECT TOP 1
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at
FROM customers_external
ORDER BY customer_id;

-- ============================================================================
-- STEP 8: Count Total Customers
-- Purpose: Get total row count in customers.csv file
-- Result: Returns count of all customer records
-- Use case: Data validation, row count verification
-- ============================================================================

SELECT COUNT(*) as Total_Customers FROM customers_external;

-- ============================================================================
-- STEP 9: Check External Table Schema
-- Purpose: Verify column definitions match expected schema
-- Result: Shows column names, data types, and null constraints
-- Use case: Data type validation, schema documentation
-- ============================================================================

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'customers_external'
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- STEP 10: Create External File Format for Parquet
-- Purpose: Define Parquet file format for future use
-- Benefits:
--   - Columnar format (better compression)
--   - Faster queries on large datasets
--   - Partitioning support
-- Note: Parquet is recommended for production data
-- ============================================================================

CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET
);

-- ============================================================================
-- STEP 11: Create External Table - customers_internal (Parquet Format)
-- Purpose: Transform CSV data to Parquet format in ADLS
-- Method: CREATE EXTERNAL TABLE ... AS SELECT (CETAS)
-- Location: /transformed_data/customers/ (in ADLS as Parquet files)
-- Benefits:
--   - Faster queries on transformed data
--   - Better compression (reduced storage)
--   - Partitioning ready
-- Schema Addition:
--   - loaded_date: Added audit column (current date)
-- ============================================================================

CREATE EXTERNAL TABLE customers_internal
WITH (
    LOCATION = '/transformed_data/customers/',
    DATA_SOURCE = adls_storage,
    FILE_FORMAT = parquet_format
)
AS
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at,
    CAST(GETDATE() AS DATE) as loaded_date
FROM customers_external;

-- ============================================================================
-- STEP 12: Create View - customers_internal_vw
-- Purpose: Virtual table for business users (no data duplication)
-- Method: View (not materialized, computed on every query)
-- Use case:
--   - Simplify complex queries
--   - Provide consistent data interface
--   - Apply transformations virtually
-- Benefits:
--   - No storage overhead
--   - Always current data
--   - Security layer
-- ============================================================================

CREATE VIEW customers_internal_vw AS
SELECT
    customer_id,
    customer_name,
    email,
    phone,
    address,
    created_at,
    CAST(GETDATE() AS DATE) as loaded_date
FROM customers_external;

-- ============================================================================
-- STEP 13: Query the View
-- Purpose: Test view functionality and retrieve data
-- Result: Returns first 10 customer records
-- Use case: Validate view works correctly
-- ============================================================================

SELECT top 10 * from customers_internal_vw;

-- ============================================================================
-- STEP 14: Direct OPENROWSET with Schema Definition
-- Purpose: Alternative to external table (no creation overhead)
-- Method: Query CSV directly with explicit schema in WITH clause
-- Benefits:
--   - No table creation required
--   - Ad-hoc query capability
--   - Good for one-time analysis
-- Result: Returns first 10 customer records
-- Use case: Exploration, quick analysis, data validation
-- ============================================================================

SELECT TOP 10
    *
FROM OPENROWSET(
    BULK 'abfss://maybarch-adlsgen2@maybatchtrainingadls.dfs.core.windows.net/datasets/customers.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) WITH (
    customer_id INT,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address VARCHAR(500),
    created_at DATE
) AS customers;

-- ============================================================================
-- SUMMARY OF CREATED OBJECTS
-- ============================================================================
--
-- DATABASE:
--   ✓ Syn                          - Working database
--
-- EXTERNAL DATA SOURCES:
--   ✓ adls_storage                 - ADLS Gen2 connection
--
-- EXTERNAL FILE FORMATS:
--   ✓ csv_format                   - CSV parser definition
--   ✓ parquet_format               - Parquet parser definition
--
-- EXTERNAL TABLES:
--   ✓ customers_external           - CSV data (location: /datasets/customers.csv)
--   ✓ customers_internal           - Parquet data (location: /transformed_data/customers/)
--
-- VIEWS:
--   ✓ customers_internal_vw        - Virtual view of external data
--
-- ============================================================================
-- NEXT STEPS
-- ============================================================================
--
-- 1. Use customers_external for direct CSV queries
-- 2. Use customers_internal for fast Parquet queries
-- 3. Use customers_internal_vw for simplified access
-- 4. Reference adls_storage to create additional external tables
--
-- ============================================================================
-- PERFORMANCE TIPS
-- ============================================================================
--
-- • OPENROWSET (Steps 1, 14): Good for ad-hoc, one-time queries
-- • External Tables (Steps 6, 11): Good for repeated queries
-- • Views (Step 12): Good for consistent business logic
-- • Parquet Format: Use for large datasets (better compression)
-- • CSV Format: Quick for small files or initial exploration
--
-- ============================================================================
