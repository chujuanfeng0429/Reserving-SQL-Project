-- =====================================================================
-- 03_factors.sql
-- Purpose: Compute age-to-age (ATA) development factors from the upper
--          triangle, and the volume-weighted average factor for each lag.
-- Depends on: view tri (see 02_triangles.sql)
-- Concept: ATA factor = cumulative paid at lag k+1 / cumulative paid at
--          lag k for the same accident year. Averaging the factors across
--          accident years gives the factor used to project unpaid cells.
-- =====================================================================

-- Step 1: Individual age-to-age factors using a self-join.
-- a = current lag, b = next lag of the same accident year.
-- "dev" in this view means the factor goes FROM this lag to dev + 1.
-- "* 1.0" prevents integer division.
CREATE view ata as
select a.ay, a.dev,
       b.paid*1.0/ a.paid as ata
FROM tri a
JOIN tri b ON a.ay=b.ay AND  b.dev=a.dev +1;

-- Check: row count (expected: 45 = 9+8+...+1).
SELECT COUNT(*) FROM ata;


-- Step 2: Average factors by development lag.
-- f_vw     = volume-weighted average (sum of next-lag paid / sum of
--            current-lag paid); larger accident years get more weight.
-- f_simple = simple average of the individual factors, for comparison.
-- n_obs    = number of accident years used for each factor.
-- The join keeps only accident years that have BOTH lags, so the
-- denominator never includes a cell without a next-period value.
CREATE VIEW f AS
SELECT a.dev,
       SUM(b.paid)*1.0/ sum(a.paid) AS f_vw,
       AVG(b.paid*1.0/a.paid)       AS f_simple,
       COUNT(*)                     AS n_obs
FROM tri a
JOIN tri b ON a.ay=b.ay and b.dev=a.dev +1
GROUP BY a.dev;

-- Check: 9 rows; n_obs = 9, 8, ..., 1; f_vw at dev = 1 is about 2.174.
SELECT *FROM f order by dev;


-- Step 3: ATA factors in triangle layout, for diagnostics.
-- Read each column top to bottom: is the factor stable across accident
-- years? Any trend or outlier? (A rising 1->2 or 2->3 factor suggests
-- slower early payments in recent accident years.)
SELECT ay,
  MAX(CASE WHEN dev = 1 THEN ata END) AS f1_2,
  MAX(CASE WHEN dev = 2 THEN ata END) AS f2_3,
  MAX(CASE WHEN dev = 3 THEN ata END) AS f3_4,
  MAX(CASE WHEN dev = 4 THEN ata END) AS f4_5,
  MAX(CASE WHEN dev = 5 THEN ata END) AS f5_6,
  MAX(CASE WHEN dev = 6 THEN ata END) AS f6_7,
  MAX(CASE WHEN dev = 7 THEN ata END) AS f7_8,
  MAX(CASE WHEN dev = 8 THEN ata END) AS f8_9,
  MAX(CASE WHEN dev = 9 THEN ata END) AS f9_10
FROM ata
GROUP BY ay
ORDER BY ay;


-- Step 4: Same individual factors rewritten with the LAG window function.
-- LAG(paid) returns the previous lag's value within the same accident year
-- (PARTITION BY ay, ORDER BY dev). The first lag of each year has no
-- previous row, so its ratio is NULL and is filtered out.
-- "dev" here is the LATER lag, so from_dev = dev - 1 is where the factor
-- starts. The result should match the "ata" view exactly (45 rows).
-- Self-join: intuitive and supports weighted averages.
-- LAG: shorter and reads the table only once.
SELECT ay, dev -1 as from_dev, ata
FROM (
    select ay, dev,
           paid *1.0 / lag(paid) over (partition by ay order by dev) as ata from tri)
where ata is not NULL order by ay, from_dev;
