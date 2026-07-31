--
-- Name: r_data_main; Type: TABLE; Schema: public; Owner: irods
--

CREATE TABLE public.r_data_main (
    data_id bigint NOT NULL,
    coll_id bigint NOT NULL,
    data_name character varying(1000) NOT NULL,
    data_repl_num integer NOT NULL,
    data_version character varying(250) DEFAULT '0'::character varying,
    data_type_name character varying(250) NOT NULL,
    data_size bigint NOT NULL,
    resc_group_name character varying(250),
    resc_name character varying(250) NOT NULL,
    data_path character varying(2700) NOT NULL,
    data_owner_name character varying(250) NOT NULL,
    data_owner_zone character varying(250) NOT NULL,
    data_is_dirty integer DEFAULT 0,
    data_status character varying(250),
    data_checksum character varying(1000),
    data_expiry_ts character varying(32),
    data_map_id bigint DEFAULT 0,
    data_mode character varying(32),
    r_comment character varying(1000),
    create_ts character varying(32),
    modify_ts character varying(32),
    resc_hier character varying(1000),
    resc_id bigint,
    create_ts_timestamp timestamp without time zone
);


ALTER TABLE public.r_data_main OWNER TO irods;

----------------------------
-- r_data_main_part
----------------------------

CREATE TABLE public.r_data_main_part (
    data_id bigint NOT NULL,
    coll_id bigint NOT NULL,
    data_name character varying(1000) NOT NULL,
    data_repl_num integer NOT NULL,
    data_version character varying(250) DEFAULT '0'::character varying,
    data_type_name character varying(250) NOT NULL,
    data_size bigint NOT NULL,
    resc_group_name character varying(250),
    resc_name character varying(250) NOT NULL,
    data_path character varying(2700) NOT NULL,
    data_owner_name character varying(250) NOT NULL,
    data_owner_zone character varying(250) NOT NULL,
    data_is_dirty integer DEFAULT 0,
    data_status character varying(250),
    data_checksum character varying(1000),
    data_expiry_ts character varying(32),
    data_map_id bigint DEFAULT 0,
    data_mode character varying(32),
    r_comment character varying(1000),
    create_ts character varying(32),
    modify_ts character varying(32),
    resc_hier character varying(1000),
    resc_id bigint,
    create_ts_timestamp timestamp without time zone
)
PARTITION BY RANGE (
    (
        CASE
            WHEN create_ts IS NULL
                 OR btrim(create_ts) = ''
            THEN NULL

            ELSE to_timestamp(create_ts::bigint)
        END
    )
);

ALTER TABLE public.r_data_main_part
OWNER TO irods;


-- Review since we need create the partition for each quarter, we can create a function to do that.

SELECT extract(year from to_timestamp(create_ts::bigint)) AS year,
       extract(quarter from to_timestamp(create_ts::bigint)) AS quarter,
       count(*) AS record_count
FROM public.r_data_main
GROUP BY year, quarter;


-- default partition
CREATE TABLE public.r_data_main_part_default
    PARTITION OF public.r_data_main_part
    DEFAULT;

-- Function to create quarterly partitions
CREATE OR REPLACE FUNCTION create_quarterly_partition(
    parent_table TEXT,
    p_year INTEGER,
    p_quarter INTEGER
) RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
    --parent_table TEXT := 'r_data_main_part';
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

    partition_name := format('r_data_main_part_%s_Q%s', p_year, p_quarter);
    
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


SELECT create_quarterly_partition('r_data_main_part', 2020, 1);
SELECT create_quarterly_partition('r_data_main_part', 2020, 2);
SELECT create_quarterly_partition('r_data_main_part', 2020, 3);
SELECT create_quarterly_partition('r_data_main_part', 2020, 4);
SELECT create_quarterly_partition('r_data_main_part', 2021, 1);
SELECT create_quarterly_partition('r_data_main_part', 2021, 2);
SELECT create_quarterly_partition('r_data_main_part', 2021, 3);
SELECT create_quarterly_partition('r_data_main_part', 2021, 4);
SELECT create_quarterly_partition('r_data_main_part', 2022, 1);
SELECT create_quarterly_partition('r_data_main_part', 2022, 2);
SELECT create_quarterly_partition('r_data_main_part', 2022, 3);
SELECT create_quarterly_partition('r_data_main_part', 2022, 4);
SELECT create_quarterly_partition('r_data_main_part', 2023, 1);
SELECT create_quarterly_partition('r_data_main_part', 2023, 2);
SELECT create_quarterly_partition('r_data_main_part', 2023, 3);
SELECT create_quarterly_partition('r_data_main_part', 2023, 4);
SELECT create_quarterly_partition('r_data_main_part', 2024, 1);
SELECT create_quarterly_partition('r_data_main_part', 2024, 2);
SELECT create_quarterly_partition('r_data_main_part', 2024, 3);
SELECT create_quarterly_partition('r_data_main_part', 2024, 4);
SELECT create_quarterly_partition('r_data_main_part', 2025, 1);
SELECT create_quarterly_partition('r_data_main_part', 2025, 2);
SELECT create_quarterly_partition('r_data_main_part', 2025, 3);
SELECT create_quarterly_partition('r_data_main_part', 2025, 4);
SELECT create_quarterly_partition('r_data_main_part', 2026, 1);
SELECT create_quarterly_partition('r_data_main_part', 2026, 2);
SELECT create_quarterly_partition('r_data_main_part', 2026, 3);
SELECT create_quarterly_partition('r_data_main_part', 2026, 4);



-- Review indexes if with this format is enought.
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2020_Q1 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2020_Q2 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2020_Q3 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2020_Q4 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2021_Q1 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2021_Q2 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2021_Q3 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2021_Q4 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2022_Q1 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2022_Q2 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2022_Q3 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2023_Q1 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2023_Q2 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2023_Q3 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2023_Q4 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2024_Q1 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2024_Q2 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2024_Q3 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2024_Q4 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2025_Q1 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2025_Q2 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2025_Q3 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2025_Q4 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2026_Q1 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2026_Q2 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2026_Q3 ON public.r_data_main_part (create_ts);
CREATE INDEX IF NOT EXISTS idx_r_data_main_part_create_ts_2026_Q4 ON public.r_data_main_part (create_ts);



-- Resinsert data from r_coll_main to r_data_main_part
INSERT INTO public.r_data_main_part SELECT * FROM public.r_data_main;



\o explain_analyze_r_data_main_part.sql
\timing

-- Test:

