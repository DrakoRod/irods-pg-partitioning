# iRODS PostgreSQL Quarterly Partitioning

## Overview

This implementation introduces PostgreSQL range partitioning for the following iRODS catalog tables:

- `public.r_coll_main`
- `public.r_data_main`

Both tables are partitioned by the `create_ts` column using quarterly date ranges.

The implementation uses the following SQL scripts:

| Script | Purpose |
|---|---|
| `create_quarterly_partition.sql` | Creates the reusable PostgreSQL function used to create quarterly partitions |
| `r_coll_main_partitioning.sql` | Creates and migrates the partitioned version of `r_coll_main` |
| `r_data_main_partitioning.sql` | Creates and migrates the partitioned version of `r_data_main` |

The partitioning strategy is based on the timestamp represented by the iRODS `create_ts` column.

Because `create_ts` is stored as a character value, the partition key converts the value to a PostgreSQL timestamp using:

```sql
to_timestamp(create_ts::bigint)
```

The partition key also handles `NULL` and empty values:

```sql
CASE
    WHEN create_ts IS NULL
         OR btrim(create_ts) = ''
    THEN NULL
    ELSE to_timestamp(create_ts::bigint)
END
```

## Objectives

The objectives of this implementation are:

- Divide the iRODS catalog tables into smaller quarterly partitions.
- Improve the manageability of large catalog tables.
- Allow PostgreSQL to use partition pruning when queries include the partition key.
- Reduce the amount of data scanned by date-based queries.
- Simplify future maintenance activities.
- Provide a reusable function for creating new quarterly partitions.

---

## Partition Naming Convention

Quarterly partitions are created using the following naming convention:

```
<parent_table>_<year>_q<quarter>
```

Examples:

```
r_coll_main_part_2024_q1
r_coll_main_part_2024_q2
r_data_main_part_2025_q3
r_data_main_part_2026_q4
```

The temporary parent tables use the `_part` suffix during the migration:

```
r_coll_main_part
r_data_main_part
```

After the data migration is completed, the original tables are renamed as backups and the partitioned tables receive the original names.

Example:

```
r_coll_main
    ↓
r_coll_main_backup

r_coll_main_part
    ↓
r_coll_main
```

The same process is used for `r_data_main`

---

## Partition Ranges

The implementation creates one partition for each calendar quarter.

| Quarter | Start Date | End Date                              |
|---------|------------|---------------------------------------|
| Q1      | January 1  | April 1                               |
| Q2      | April 1    | July 1                                |
| Q3      | July 1     | October 1                             |
| Q4      | October 1  | January 1 of the following year       |


PostgreSQL partition ranges use an inclusive lower boundary and an exclusive upper boundary.

For example, the partition for Q1 2025 is created using:

```sql
FOR VALUES FROM ('2025-01-01') TO ('2025-04-01')
```

This partition includes timestamps greater than or equal to:

```
2025-01-01 00:00:00
```

and less than

```
2025-04-01 00:00:00
```

---

## Prerequisites

Before implementing the partitioning scripts, verify the following requirements.

### PostgreSQL Version

The PostgreSQL version must support declarative partitioning.

PostgreSQL 11 or later is recommended.

Verify the PostgreSQL version:

```sql
SELECT version();
```

### Database Access

The implementation must be performed by a database user with sufficient privileges to:

- Create tables.
- Create functions.
- Create indexes.
- Insert data.
- Rename tables.
-Change table ownership.

The scripts assign ownership to the following database role:

```
irods
```

Verify that the role exists:

```sql
SELECT rolname
FROM pg_roles
WHERE rolname = 'irods';
```

### iRODS Maintenance Window

The final migration includes table rename operations:

```sql
ALTER TABLE public.r_coll_main
RENAME TO r_coll_main_backup;

ALTER TABLE public.r_coll_main_part
RENAME TO r_coll_main;
```

and

```sql
ALTER TABLE public.r_data_main
RENAME TO r_data_main_backup;

ALTER TABLE public.r_data_main_part
RENAME TO r_data_main;
```

These operations should be executed during a planned maintenance window.

The iRODS application should be stopped, or database writes should be prevented, before starting the final migration.

Running the migration while iRODS is actively modifying the catalog may result in:

- Missing records in the partitioned tables.
- Inconsistent data between the original and partitioned tables.
- Lock contention.
- Application errors during the table rename.

---

## Important Pre-Implementation Checks

Before executing the scripts, collect information about the current tables.

### Review Table Sizes

```sql
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM pg_class
WHERE oid IN (
    'public.r_coll_main'::regclass,
    'public.r_data_main'::regclass
);
```

### Review Row Counts

```sql
SELECT
    'r_coll_main' AS table_name,
    count(*) AS row_count
FROM public.r_coll_main

UNION ALL

SELECT
    'r_data_main' AS table_name,
    count(*) AS row_count
FROM public.r_data_main;
```

Save the results because they will be used to validate the migration.

### Review `create_ts` Values

Check for NULL or empty values:

```sql
SELECT
    count(*) FILTER (
        WHERE create_ts IS NULL
           OR btrim(create_ts) = ''
    ) AS null_or_empty_create_ts,
    count(*) AS total_rows
FROM public.r_coll_main;
```

Repeat the validation for `r_data_main`:

```sql
SELECT
    count(*) FILTER (
        WHERE create_ts IS NULL
           OR btrim(create_ts) = ''
    ) AS null_or_empty_create_ts,
    count(*) AS total_rows
FROM public.r_data_main;
```

### Validate Timestamp Format

The scripts assume that non-empty `create_ts` values can be converted to a PostgreSQL `bigint`.

Review invalid values before executing the migration:

```sql
SELECT
    create_ts
FROM public.r_coll_main
WHERE create_ts IS NOT NULL
  AND btrim(create_ts) <> ''
  AND btrim(create_ts) !~ '^[0-9]+$'
LIMIT 100;
```

Run the same validation for `r_data_main`:

```sql
SELECT
    create_ts
FROM public.r_data_main
WHERE create_ts IS NOT NULL
  AND btrim(create_ts) <> ''
  AND btrim(create_ts) !~ '^[0-9]+$'
LIMIT 100;
```

If invalid values are returned, they must be corrected or handled before the migration.

## Review Existing Constraints and Indexes

The provided scripts define the table columns but do not recreate all existing constraints, indexes, foreign keys, triggers, permissions, or grants.

Before the migration, review the current objects associated with both tables.

### Review Constraints

```sql
SELECT
    conname,
    contype,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.r_coll_main'::regclass;
```
```sql
SELECT
    conname,
    contype,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.r_data_main'::regclass; 
```

### Review Existing Indexes

```sql
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
      'r_coll_main',
      'r_data_main'
  )
ORDER BY tablename, indexname;
```

### Review Triggers

```sql
SELECT
    event_object_table,
    trigger_name,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN (
      'r_coll_main',
      'r_data_main'
  );
```

Any required database objects should be recreated on the partitioned tables before the final cutover.

--- 

## Implementation Order

The scripts should be executed in the following order:

1. Create the quarterly partition function.
2. Implement partitioning for `r_coll_main`.
3. Validate the `r_coll_main` migration.
4. Implement partitioning for `r_data_main`.
5. Validate the `r_data_main` migration.
6. Perform the final table rename operations.
7. Validate the iRODS application.

The implementation should first be tested in a development or staging environment using a copy of the production catalog.

---

## Step 1: Create the Quarterly Partition Function

Execute:

```sql
psql \
    -h postgres.example.com \
    -p 5432 \
    -U postgres \
    -d ICAT \
    -f create_quarterly_partition.sql
```

The script creates the following function:

```sql
create_quarterly_partition(
    parent_table TEXT,
    p_year INTEGER,
    p_quarter INTEGER,
    user_owner TEXT
)
```

The function performs the following operations:

1. Calculates the start date for the requested quarter.
2. Calculates the end date for the requested quarter.
3. Creates the partition if it does not already exist.
4. Assigns ownership to the specified database role.
5. Displays a notice containing the partition name and date range.

Example:

```sql
SELECT create_quarterly_partition(
    'r_coll_main_part',
    2026,
    3,
    'irods'
);
```

Expected partition name:

```text
r_coll_main_part_2026_q3
```
Expected partition range:

```text
FROM 2026-07-01
TO   2026-10-01
```
Verify that the function exists:

```sql
SELECT
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name = 'create_quarterly_partition';
```
---

## Step 2: Implement `r_coll_main` Partitioning

Execute:

```bash
psql \
    -h <database-host> \
    -p <database-port> \
    -U <database-user> \
    -d <database-name> \
    -f r_coll_main_partitioning.sql
```
The script performs the following operations:

1. Creates the temporary partitioned table:
```
public.r_coll_main_part
```
2. Configures range partitioning using the converted `create_ts` value.
3. Creates the default partition:
```
public.r_coll_main_part_default
```
4. Creates quarterly partitions from 2020 through 2026.
5. Creates indexes associated with the partitioning timestamp expression.
6. Copies data from:
```
public.r_coll_main
```
7. Renames the original table:
```
public.r_coll_main
```
to:
```
public.r_coll_main_backup
```
8. Renames the partitioned table:
```
public.r_coll_main_part
```
to:
```
public.r_coll_main
```

### Important

The final rename commands should be reviewed before executing the entire script.

For a controlled migration, it is recommended to separate the script into the following phases:

#### Phase A: Create the partitioned structure

Execute:

- Partitioned parent table creation.
- Default partition creation.
- Quarterly partition creation.
- Index creation.

#### Phase B: Copy and validate the data

Execute:

```sql
INSERT INTO public.r_coll_main_part
SELECT *
FROM public.r_coll_main;
```

Validate row counts and partition distribution.

#### Phase C: Perform the final cutover

After stopping iRODS or preventing writes:

```sql
ALTER TABLE public.r_coll_main
RENAME TO r_coll_main_backup;

ALTER TABLE public.r_coll_main_part
RENAME TO r_coll_main;
```

---

## Step 3: Validate `r_coll_main`
### Compare Row Counts

Before the final table rename:

```sql
SELECT
    'original' AS source,
    count(*) AS row_count
FROM public.r_coll_main

UNION ALL

SELECT
    'partitioned' AS source,
    count(*) AS row_count
FROM public.r_coll_main_part;
```
The row counts must match.

After the final rename:
```sql
SELECT
    'backup' AS source,
    count(*) AS row_count
FROM public.r_coll_main_backup

UNION ALL

SELECT
    'partitioned' AS source,
    count(*) AS row_count
FROM public.r_coll_main;
```

### Review Partition Distribution

```sql
SELECT
    tableoid::regclass AS partition_name,
    count(*) AS row_count
FROM public.r_coll_main
GROUP BY tableoid
ORDER BY partition_name;
```
Expected results include quarterly partitions such as:

```
r_coll_main_part_2020_q1
r_coll_main_part_2020_q2
r_coll_main_part_2020_q3
r_coll_main_part_2020_q4
...
r_coll_main_part_2026_q4
r_coll_main_part_default
```

#### Verify Partition Configuration

```sql
SELECT
    parent.relname AS parent_table,
    child.relname AS partition_name,
    pg_get_expr(
        child.relpartbound,
        child.oid
    ) AS partition_definition
FROM pg_inherits
JOIN pg_class parent
    ON pg_inherits.inhparent = parent.oid
JOIN pg_class child
    ON pg_inherits.inhrelid = child.oid
WHERE parent.relname = 'r_coll_main'
ORDER BY child.relname;
```
---
## Step 4: Implement r_data_main Partitioning

Execute:

```bash
psql \
    -h <database-host> \
    -p <database-port> \
    -U <database-user> \
    -d <database-name> \
    -f r_data_main_partitioning.sql
```

The script performs the following operations:

1. Creates the temporary partitioned table:
```
public.r_data_main_part
```
2. Configures range partitioning using the converted create_ts value.
3. Creates the default partition:
```
public.r_data_main_part_default
```
4. Creates quarterly partitions from 2020 through 2026.
5. Creates indexes associated with the partitioning timestamp expression.
6. Copies data from:
```
public.r_data_main
```
to:
```
public.r_data_main_part
```
7. Renames the original table:
```
public.r_data_main
```
to:
```
public.r_data_main_backup
```
8. Renames the partitioned table:
```
public.r_data_main_part
```
to:
```
public.r_data_main
```
As with `r_coll_main`, it is recommended to separate the table creation, data migration, validation, and final cutover operations.

---

## Step 5: Validate `r_data_main`
### Compare Row Counts

Before the final table rename:

```sql
SELECT
    'original' AS source,
    count(*) AS row_count
FROM public.r_data_main

UNION ALL

SELECT
    'partitioned' AS source,
    count(*) AS row_count
FROM public.r_data_main_part;
```

After the final rename: 

```sql
SELECT
    'backup' AS source,
    count(*) AS row_count
FROM public.r_data_main_backup

UNION ALL

SELECT
    'partitioned' AS source,
    count(*) AS row_count
FROM public.r_data_main;
```

#### Review Partition Distribution

```sql
SELECT
    tableoid::regclass AS partition_name,
    count(*) AS row_count
FROM public.r_data_main
GROUP BY tableoid
ORDER BY partition_name;
```

### Verify Partition Configuration

```sql
SELECT
    parent.relname AS parent_table,
    child.relname AS partition_name,
    pg_get_expr(
        child.relpartbound,
        child.oid
    ) AS partition_definition
FROM pg_inherits
JOIN pg_class parent
    ON pg_inherits.inhparent = parent.oid
JOIN pg_class child
    ON pg_inherits.inhrelid = child.oid
WHERE parent.relname = 'r_data_main'
ORDER BY child.relname;
```

---

## Step 6: Validate the iRODS Application

After both tables have been migrated:

1. Start the iRODS services.
2. Verify that the iRODS server starts successfully.
3. Test catalog read operations.
4. Test collection creation.
5. Test data object registration.
6. Test data object upload.
7. Test data object retrieval.
8. Test metadata operations.
9. Review the iRODS server logs.
10. Monitor PostgreSQL logs for errors.

Example validation commands:

```bash
ils
```

```bash
ipwd
```
```bash
imkdir partitioning_test
```
```bash
iput <test-file>
```
```bash
ils -L
```

Remove the test objects after validation.

--- 

## Post-Migration Validation
### Verify the New Tables

```sql
SELECT
    schemaname,
    tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
      'r_coll_main',
      'r_coll_main_backup',
      'r_data_main',
      'r_data_main_backup'
  )
ORDER BY tablename;
```

Excpeted tables:
```
r_coll_main
r_coll_main_backup
r_data_main
r_data_main_backup
```

Verify Table Ownership
```sql
SELECT
    c.relname AS table_name,
    r.rolname AS owner
FROM pg_class c
JOIN pg_roles r
    ON c.relowner = r.oid
WHERE c.relname IN (
    'r_coll_main',
    'r_data_main'
);
```
Expected owner: 
```bash
irods
```

### Verify Partitioned Tables

```sql
SELECT
    relname,
    relkind
FROM pg_class
WHERE relname IN (
    'r_coll_main',
    'r_data_main'
);
```
The parent tables should be partitioned tables.

---

## Creating Future Partitions

New partitions should be created before the beginning of the corresponding quarter.

Example: create Q1 2027 partitions:

```sql
SELECT create_quarterly_partition(
    'r_coll_main',
    2027,
    1,
    'irods'
);
```
```sql
SELECT create_quarterly_partition(
    'r_data_main',
    2027,
    1,
    'irods'
);
```

Because the final parent table names are changed from:
```
r_coll_main_part
r_data_main_part
```
to:
```
r_coll_main
r_data_main
```
future partition creation must use the final parent table names.

For example:
```sql
SELECT create_quarterly_partition(
    'r_coll_main',
    2027,
    2,
    'irods'
);
```
Do not use `r_coll_main_part` after the final rename because that parent table name no longer exists.

---

# Recommended Future Partition Schedule

Create future partitions before they are required.

## Example schedule:

| Partition | Recommended Creation Time |
|-----------|---------------------------|
| 2027 Q1   | December 2026             |
| 2027 Q2   | March 2027                |
| 2027 Q3   | June 2027                 |
| 2027 Q4   | September 2027            |

The partition creation process can be automated using:

- cron
- PostgreSQL scheduling extensions
- An infrastructure automation pipeline
- A database maintenance job

---

## Index Considerations

The scripts create indexes using the following expression:
```
to_timestamp(create_ts::bigint)
```
The indexes are created on the partitioned parent tables.

PostgreSQL may create corresponding indexes on the child partitions depending on the PostgreSQL version and the partitioned-index behavior.

After implementation, verify the indexes using:
```sql
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND (
      tablename LIKE 'r_coll_main%'
      OR tablename LIKE 'r_data_main%'
  )
ORDER BY tablename, indexname;
```
Additional indexes may be required for iRODS catalog queries.

Before removing or modifying existing indexes, review:

- iRODS query patterns.
- Existing query execution plans.
- Foreign key requirements.
- Application performance.
- PostgreSQL index usage statistics.

---

## Partition Pruning Validation

Partition pruning is most effective when queries use the partition key.

Example:
```
EXPLAIN ANALYZE
SELECT *
FROM public.r_data_main
WHERE to_timestamp(create_ts::bigint)
      >= TIMESTAMP '2026-01-01'
  AND to_timestamp(create_ts::bigint)
      < TIMESTAMP '2026-04-01';
```
Review the execution plan and verify that PostgreSQL accesses only the required quarterly partition.

---

## Default Partition Monitoring

Rows with a `NULL` or empty `create_ts` value are routed to the default partition.

Review the default partitions regularly:
```sql
SELECT
    count(*) AS default_partition_rows
FROM public.r_coll_main_part_default;
```
```sql
SELECT
    count(*) AS default_partition_rows
FROM public.r_data_main_part_default;
```

After the parent tables are renamed, verify the actual default partition names because child partition names are not automatically changed when the parent table is renamed.

---

## Rollback Procedure

The original tables are preserved as:
```
r_coll_main_backup
r_data_main_backup
```
Do not drop these tables until the implementation has been validated and approved.

If a rollback is required, stop iRODS and rename the tables.

Example for `r_coll_main`:
```sql
ALTER TABLE public.r_coll_main
RENAME TO r_coll_main_partitioned_failed;

ALTER TABLE public.r_coll_main_backup
RENAME TO r_coll_main;
```

Example for r_data_main:
```sql
ALTER TABLE public.r_data_main
RENAME TO r_data_main_partitioned_failed;

ALTER TABLE public.r_data_main_backup
RENAME TO r_data_main;
```

After the rollback:

1. Verify that the original table names are restored.
2. Verify table ownership.
3. Start iRODS.
4. Test catalog operations.
5. Review PostgreSQL and iRODS logs.

Do not drop the partitioned tables until the rollback has been validated.

---

## Important Implementation Notes
### 1. Test Before Production

The implementation should first be executed in a development or staging environment using a representative copy of the iRODS catalog.

The following should be measured:

- Partition creation time.
- Data migration time.
- Disk space usage.
- Index creation time.
- Lock behavior.
- Query performance.
-iRODS application behavior.

### 2. Verify Disk Capacity

The migration temporarily stores both the original and partitioned versions of the tables.

Additional disk capacity is required for:

- The partitioned table data.
- New indexes.
- Existing backup tables.
- PostgreSQL temporary files.
- WAL generated by the data copy.

Verify available disk capacity before starting.

### 3. The Data Copy Generates WAL

The following operations can generate a significant amount of PostgreSQL WAL:

```sql
INSERT INTO public.r_coll_main_part
SELECT *
FROM public.r_coll_main;
```
```sql
INSERT INTO public.r_data_main_part
SELECT *
FROM public.r_data_main;
```

Monitor:

- WAL disk usage.
- Replication lag.
- Archive status.
- Database storage usage.

### 4. Run During a Maintenance Window

The final table rename must be coordinated with the iRODS application.

Stop iRODS or prevent catalog writes before performing the final cutover.

### 5. Review Constraints and Dependencies

The provided scripts focus on table structure, partition creation, indexes, data migration, and table renaming.

Before production implementation, verify and recreate any required:

- Primary keys.
- Unique constraints.
- Foreign keys.
- Check constraints.
- Triggers.
- Permissions.
- Grants.
- Comments.
- Custom indexes.
- Application-specific database objects.

### 6. Validate the Script Before Execution

Review the SQL scripts in a non-production environment before execution.

In particular, verify:

- The PostgreSQL version.
- The actual iRODS schema.
- The current table definitions.
- Existing indexes and constraints.
- The range of create_ts values.
- The required quarterly partitions.
- The database owner role.

---


