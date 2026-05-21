# Azure SQL Databases

A family of fully managed relational database services on Microsoft Azure built on the SQL Server engine — no infrastructure to manage, always patched, and backed by a 99.99% SLA.

---

## Types

| Type | Description |
|---|---|
| **Azure SQL Database** | Fully managed single database or elastic pool. Best for modern cloud-native apps. |
| **Hyperscale** | Variant of SQL Database that scales up to 128 TB with fast snapshot backups and read replicas. |
| **Elastic Pool** | Shared vCore/DTU pool across multiple databases — cost-efficient for SaaS multi-tenant apps. |
| **SQL Managed Instance** | Full SQL Server engine in a VNet — near 100% on-prem compatibility for lift-and-shift migrations. |
| **Instance Pools** | Pre-provisioned compute hosting multiple small Managed Instances — lower cost per instance. |
| **SQL Server on Azure VMs** | Full IaaS — SQL Server running inside an Azure VM with complete OS and engine control. |

---

## Use Cases

- **New cloud apps** → Azure SQL Database (Single DB, serverless)
- **Multi-tenant SaaS** → Elastic Pool
- **Very large databases (> 4 TB)** → Hyperscale
- **Lift-and-shift from on-premises** → SQL Managed Instance
- **Many small SQL instances** → Instance Pools
- **Legacy SQL versions / full OS control** → SQL Server on Azure VMs

---

## Files in this Folder

| File | Description |
|---|---|
| `Azure SQL CRUD.sql` | T-SQL practice script — schema creation, dummy data, CRUD, complex queries, window functions, PIVOT, MERGE, JSON |
