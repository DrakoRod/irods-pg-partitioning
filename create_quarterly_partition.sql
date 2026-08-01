---------
--- Function: create_quarterly_partition
--------- 
CREATE OR REPLACE FUNCTION create_quarterly_partition(
    parent_table TEXT,
    p_year INTEGER,
    p_quarter INTEGER,
    user_owner TEXT
) RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
    --parent_table TEXT := 'r_data_main_part';
    partition_sql TEXT;
    sql_owner TEXT;
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

    partition_name := format('%s_%s_q%s', parent_table, p_year, p_quarter);
    
    -- Create partition
    partition_sql := format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I 
         FOR VALUES FROM (%L) TO (%L)',
        partition_name, parent_table, start_date, end_date
    );
    
    EXECUTE partition_sql;    

    sql_owner := format(
        'ALTER TABLE %I OWNER TO %I;', partition_name, parent_table
    );

    EXECUTE sql_owner;
    
    RAISE NOTICE 'Created partition % for range % to %', 
        partition_name, start_date, end_date;
END;
$$ LANGUAGE plpgsql;
