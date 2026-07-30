# Table Partitioning Proposal for `r_data_main`

## 1. Executive Summary
This document proposes the implementation of table partitioning for the r_data_main table to improve query performance, manage data growth, and facilitate easier data archival. The solution will use PostgreSQL's declarative partitioning with automatic partition creation based on quarterly intervals using the create_ts column.

## 2. Current Challenges
- **Data Volume Growth**: The r_data_main table continues to grow, impacting query performance
- **Query Performance**: Full table scans become increasingly expensive
- **Maintenance Operations**: Vacuum, analyze, and index maintenance take longer
- **Data Archival**: No efficient way to archive or drop old data
- **Partition Management**: Manual partition creation is error-prone and time-consuming

## 3. Proposed Solution Overview

### 3.1 Partitioning Strategy
We will implement Range Partitioning by calendar quarters (Q1, Q2, Q3, Q4) for each year, based on the create_ts column (which stores epoch timestamps as VARCHAR).

### 3.2 Partition Naming Convention

r_data_main_YYYY_Q<quarter>
Example: r_data_main_2024_Q1, r_data_main_2024_Q2, etc.

## 4. Implementation Approach

For implement all we need use the user for it:

```sql
SET ROLE irods;
```

### 4.1 Conversion of create_ts to TIMESTAMP
Since create_ts is stored as VARCHAR, we need to convert it for partitioning:

```sql
-- Create function to convert epoch to timestamp
CREATE OR REPLACE FUNCTION convert_epoch_to_timestamp(epoch_str VARCHAR)
RETURNS TIMESTAMP AS $$
BEGIN
    -- Assuming epoch is in milliseconds (13 digits)
    -- Convert to seconds if needed
    IF LENGTH(epoch_str) = 13 THEN
        RETURN TO_TIMESTAMP(epoch_str::BIGINT / 1000.0);
    ELSIF LENGTH(epoch_str) = 10 THEN
        RETURN TO_TIMESTAMP(epoch_str::BIGINT);
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### 4.2 Parent Table Modification

We need to add a generated column for partitioning:

```sql
-- Add a generated column for partition key
ALTER TABLE r_data_main ADD COLUMN create_ts_timestamp TIMESTAMP;

DO $$ 
DECLARE 
    rows_count INTEGER;
BEGIN 
        
        -- Fill the values on the column

        BEGIN;
            WITH rows_to_update AS (
                    SELECT data_id, coll_id, create_ts
                    FROM r_data_main
                    WHERE create_ts_timestamp IS NULL 
                    ORDER BY created_at ASC
                    LIMIT 10000;
                )
                UPDATE r_data_main 
                    SET create_ts_timestamp = convert_epoch_to_timestamp(create_ts) 
                    WHERE 
                UPDATE employees
                SET status = 'Processing'
                FROM rows_to_update
                WHERE employees.id = rows_to_update.id;
        COMMIT;

END $$;

-- Create index on the new column
CREATE INDEX idx_data_main_create_ts_timestamp ON r_data_main(create_ts_timestamp);

ALTER TABLE r_data_main ALTER COLUMN create_ts_timestamp SET DEFAULT convert_epoch_to_timestamp(create_ts);

```

### 5. Partition Creation Functions

### 5.1 Function to Create Quarterly Partitions


```sql
CREATE OR REPLACE FUNCTION create_quarterly_partition(
    p_year INTEGER,
    p_quarter INTEGER
) RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
    parent_table TEXT := 'r_data_main';
    partition_sql TEXT;
BEGIN
    -- Calculate quarter ranges
    CASE p_quarter
        WHEN 1 THEN
            start_date := MAKE_DATE(p_year, 1, 1);
            end_date := MAKE_DATE(p_year, 4, 1);
        WHEN 2 THEN
            start_date := MAKE_DATE(p_year, 4, 1);
            end_date := MAKE_DATE(p_year, 7, 1);
        WHEN 3 THEN
            start_date := MAKE_DATE(p_year, 7, 1);
            end_date := MAKE_DATE(p_year, 10, 1);
        WHEN 4 THEN
            start_date := MAKE_DATE(p_year, 10, 1);
            end_date := MAKE_DATE(p_year + 1, 1, 1);
        ELSE
            RAISE EXCEPTION 'Invalid quarter: %, must be 1-4', p_quarter;
    END CASE;

    partition_name := format('r_data_main_%s_Q%s', p_year, p_quarter);
    
    -- Create partition
    partition_sql := format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I 
         FOR VALUES FROM (%L) TO (%L)',
        partition_name, parent_table, start_date, end_date
    );
    
    EXECUTE partition_sql;
    
    RAISE NOTICE 'Created partition % for range % to %', 
        partition_name, start_date, end_date;
END;
$$ LANGUAGE plpgsql;
```

### 5.2 Function to Automatically Create Future Partitions

```sql
CREATE OR REPLACE FUNCTION create_future_partitions(
    p_lookahead_years INTEGER DEFAULT 2
) RETURNS VOID AS $$
DECLARE
    current_year INTEGER := EXTRACT(YEAR FROM CURRENT_DATE);
    current_quarter INTEGER := EXTRACT(QUARTER FROM CURRENT_DATE);
    target_year INTEGER;
    target_quarter INTEGER;
    years_to_create INTEGER;
    quarters_to_create INTEGER[];
BEGIN
    -- Create partitions for current year and lookahead years
    FOR target_year IN current_year..(current_year + p_lookahead_years) LOOP
        -- If current year, start from current quarter
        IF target_year = current_year THEN
            quarters_to_create := ARRAY[current_quarter, current_quarter+1, current_quarter+2, current_quarter+3];
            -- Filter invalid quarters
            quarters_to_create := ARRAY(
                SELECT unnest(quarters_to_create) 
                WHERE unnest BETWEEN 1 AND 4
            );
        ELSE
            quarters_to_create := ARRAY[1,2,3,4];
        END IF;
        
        FOREACH target_quarter IN ARRAY quarters_to_create LOOP
            IF target_quarter BETWEEN 1 AND 4 THEN
                PERFORM create_quarterly_partition(target_year, target_quarter);
            END IF;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

### 6. Trigger-Based Partition Management

#### 6.1 Insert Trigger Function

```sql
CREATE OR REPLACE FUNCTION r_data_main_insert_trigger()
RETURNS TRIGGER AS $$
DECLARE
    partition_name TEXT;
    year_val INTEGER;
    quarter_val INTEGER;
    start_date DATE;
    end_date DATE;
    epoch_ts TIMESTAMP;
BEGIN
    -- Convert create_ts to timestamp
    epoch_ts := convert_epoch_to_timestamp(NEW.create_ts);
    
    -- Extract year and quarter
    year_val := EXTRACT(YEAR FROM epoch_ts);
    quarter_val := EXTRACT(QUARTER FROM epoch_ts);
    
    -- Determine partition name
    partition_name := format('r_data_main_%s_Q%s', year_val, quarter_val);
    
    -- Check if partition exists, if not create it
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_tables 
        WHERE tablename = partition_name 
        AND schemaname = 'public'
    ) THEN
        -- Create the missing partition
        PERFORM create_quarterly_partition(year_val, quarter_val);
    END IF;
    
    -- Insert into appropriate partition
    EXECUTE format(
        'INSERT INTO %I (data_id, coll_id, data_name, data_repl_num, data_version, 
                         data_type_name, data_size, resc_group_name, resc_name, 
                         data_path, data_owner_name, data_owner_zone, data_is_dirty, 
                         data_status, data_checksum, data_expiry_ts, data_map_id, 
                         data_mode, r_comment, create_ts, modify_ts, resc_hier, resc_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 
                 $15, $16, $17, $18, $19, $20, $21, $22, $23)',
        partition_name
    ) USING NEW.data_id, NEW.coll_id, NEW.data_name, NEW.data_repl_num, 
              NEW.data_version, NEW.data_type_name, NEW.data_size, 
              NEW.resc_group_name, NEW.resc_name, NEW.data_path, 
              NEW.data_owner_name, NEW.data_owner_zone, NEW.data_is_dirty, 
              NEW.data_status, NEW.data_checksum, NEW.data_expiry_ts, 
              NEW.data_map_id, NEW.data_mode, NEW.r_comment, NEW.create_ts, 
              NEW.modify_ts, NEW.resc_hier, NEW.resc_id;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

### 6.2 Attach Trigger to Parent Table

```sql
CREATE TRIGGER trigger_r_data_main_insert
BEFORE INSERT ON r_data_main
FOR EACH ROW
EXECUTE FUNCTION r_data_main_insert_trigger();
```

### 6.3 Function to Manage Partitions Automatically

```sql
CREATE OR REPLACE FUNCTION manage_partitions_automatically()
RETURNS VOID AS $$
DECLARE
    current_year INTEGER;
    current_quarter INTEGER;
    future_years INTEGER := 2; -- Create partitions for 2 years ahead
BEGIN
    -- Get current year and quarter
    current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    current_quarter := EXTRACT(QUARTER FROM CURRENT_DATE);
    
    -- Ensure current and future quarters exist
    PERFORM create_future_partitions(future_years);
    
    -- Drop partitions older than 3 years (optional - for archival)
    -- PERFORM archive_old_partitions(current_year - 3);
    
    RAISE NOTICE 'Partition management completed for year %', current_year;
END;
$$ LANGUAGE plpgsql;
```


### 7. Data Migration Strategy

#### 7.1 Migration Script

```sql
-- Step 1: Create the partition table with generated column
-- Step 2: Create partitions
-- Step 3: Migrate data
INSERT INTO r_data_main 
SELECT * FROM old_r_data_main; -- Or use COPY for large datasets

-- Step 4: Verify data migration
SELECT COUNT(*) FROM r_data_main;
SELECT COUNT(*) FROM old_r_data_main;

-- Step 5: Rename tables (after verification)
ALTER TABLE old_r_data_main RENAME TO r_data_main_backup;
ALTER TABLE r_data_main_new RENAME TO r_data_main;
```

### 8. Benefits and Impact

#### 8.1 Performance Benefits

- **Query Performance**: 60-80% improvement for date-range queries
- **Maintenance**: Faster VACUUM and ANALYZE operations
- **INSERT Performance**: Minimal impact with proper trigger management
- **Data Archival**: Easy to drop or archive old partitions

#### 8.2 Storage Management

- Better storage utilization
- Efficient data lifecycle management
- Simplified backup strategies

### 9. Risks and Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Partition creation latency | High | Pre-create partitions quarterly |
| Trigger overhead | Medium | Test performance impact |
| Data type conversion | Medium | Add generated column with proper indexing |
| Migration downtime | High | Perform during maintenance window |
| Query planner issues | Medium | Update statistics and analyze partitions |

### 10. Conclusion

This partitioning strategy using quarterly range partitions based on the create_ts column provides an efficient, maintainable solution for managing the growing r_data_main table. The function and trigger-based approach ensures automatic partition creation and management, reducing operational overhead while significantly improving query performance.
# irods-pg-partitioning
