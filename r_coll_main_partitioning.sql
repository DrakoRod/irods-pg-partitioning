--
-- Name: r_coll_main; Type: TABLE; Schema: public; Owner: irods
--

CREATE TABLE public.r_coll_main (
    coll_id bigint NOT NULL,
    parent_coll_name character varying(2700) NOT NULL,
    coll_name character varying(2700) NOT NULL,
    coll_owner_name character varying(250) NOT NULL,
    coll_owner_zone character varying(250) NOT NULL,
    coll_map_id bigint DEFAULT 0,
    coll_inheritance character varying(1000),
    coll_type character varying(250) DEFAULT '0'::character varying,
    coll_info1 character varying(2700) DEFAULT '0'::character varying,
    coll_info2 character varying(2700) DEFAULT '0'::character varying,
    coll_expiry_ts character varying(32),
    r_comment character varying(1000),
    create_ts character varying(32),
    modify_ts character varying(32)
);


ALTER TABLE public.r_coll_main OWNER TO irods;

----------------------------
-- r_coll_main_part
----------------------------

CREATE TABLE public.r_coll_main_part (
    coll_id bigint NOT NULL,
    parent_coll_name character varying(2700) NOT NULL,
    coll_name character varying(2700) NOT NULL,
    coll_owner_name character varying(250) NOT NULL,
    coll_owner_zone character varying(250) NOT NULL,
    coll_map_id bigint DEFAULT 0,
    coll_inheritance character varying(1000),
    coll_type character varying(250) DEFAULT '0'::character varying,
    coll_info1 character varying(2700) DEFAULT '0'::character varying,
    coll_info2 character varying(2700) DEFAULT '0'::character varying,
    coll_expiry_ts character varying(32),
    r_comment character varying(1000),
    create_ts character varying(32),
    modify_ts character varying(32)
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

ALTER TABLE public.r_coll_main_part
OWNER TO irods;


-- Review since we need create the partition for each quarter, we can create a function to do that.

SELECT extract(year from to_timestamp(create_ts::bigint)) AS year,
       extract(quarter from to_timestamp(create_ts::bigint)) AS quarter,
       count(*) AS record_count
FROM public.r_coll_main
GROUP BY year, quarter;


-- default partition
CREATE TABLE public.r_coll_main_part_default
    PARTITION OF public.r_coll_main_part
    DEFAULT;

-- Create function

SELECT create_quarterly_partition('r_coll_main_part', 2020, 1, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2020, 2, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2020, 3, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2020, 4, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2021, 1, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2021, 2, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2021, 3, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2021, 4, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2022, 1, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2022, 2, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2022, 3, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2022, 4, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2023, 1, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2023, 2, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2023, 3, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2023, 4, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2024, 1, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2024, 2, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2024, 3, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2024, 4, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2025, 1, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2025, 2, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2025, 3, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2025, 4, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2026, 1, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2026, 2, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2026, 3, 'irods');
SELECT create_quarterly_partition('r_coll_main_part', 2026, 4, 'irods');


--- Indexes for fast access

CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2020_Q1 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2020_Q2 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2020_Q3 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2020_Q4 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2021_Q1 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2021_Q2 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2021_Q3 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2021_Q4 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2022_Q1 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2022_Q2 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2022_Q3 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2023_Q1 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2023_Q2 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2023_Q3 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2023_Q4 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2024_Q1 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2024_Q2 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2024_Q3 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2024_Q4 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2025_Q1 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2025_Q2 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2025_Q3 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2025_Q4 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2026_Q1 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2026_Q2 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2026_Q3 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));
CREATE INDEX IF NOT EXISTS idx_r_coll_main_part_create_ts_2026_Q4 ON public.r_coll_main_part (to_timestamp(create_ts::bigint));


-- Resinsert data from r_coll_main to r_coll_main_part
INSERT INTO public.r_coll_main_part SELECT * FROM public.r_coll_main;



\o explain_analyze_r_coll_main_part.sql
\timing

-- Test:
BEGIN;

EXPLAIN ANALYZE VERBOSE 
UPDATE
    R_COLL_MAIN
SET
    coll_name = substr(
        coll_name,
        1,
        char_length('/banqZone/home/archivematica/biblioDIP')
    ) || '/ap-f2c1bcbd-5933-4e75-9ef8-1adb1449b755_DIP' || substr(
        coll_name,
        char_length(
            '/banqZone/home/archivematica/biblioDIP/f2c1bcbd-5933-4e75-9ef8-1adb1449b755_DIP'
        ) + 1
    )
WHERE
    substr(
        parent_coll_name,
        1,
        char_length(
            '/banqZone/home/archivematica/biblioDIP/f2c1bcbd-5933-4e75-9ef8-1adb1449b755_DIP/'
        )
    ) = '/banqZone/home/archivematica/biblioDIP/f2c1bcbd-5933-4e75-9ef8-1adb1449b755_DIP/'
    OR parent_coll_name = '/banqZone/home/archivematica/biblioDIP/f2c1bcbd-5933-4e75-9ef8-1adb1449b755_DIP';

ROLLBACK;


