-- =====================================================================
-- 04_cdf.sql
-- Purpose: Turn the average age-to-age factors into cumulative development
--          factors (CDF) and set the tail factor assumption.
-- Depends on: view f (see 03_factors.sql).
-- Concepts:
--   CDF         = factor needed to develop cumulative paid at a given lag
--                 to its ultimate value; the product of all age-to-age
--                 factors from that lag to the last lag.
--   Tail factor = expected development beyond lag 10, which cannot be
--                 observed in the data and must be assumed.
-- =====================================================================

-- Step 1: Tail factor parameter table.
-- Assumed to be 1.00 because the 8->9 and 9->10 factors are about 1.000
-- and the oldest accident year is flat after lag 8. This rests on a single
-- accident year, so sensitivity should be tested later, e.g.:
--   UPDATE tail_param SET tail_f = 1.02;
-- (the cdf view below is recalculated automatically).
CREATE table tail_param as select 1.00 as tail_f;


-- Step 2: Cumulative development factors.
-- ff stacks the volume-weighted factors for lags 1-9 (from view f) with the
-- tail factor, which is treated as the factor for lag 10.
-- SQL has no product function, so the product is computed as
-- EXP(SUM(LN(fac))), because ln(a*b) = ln(a) + ln(b). This requires every
-- factor to be positive.
-- The window is ordered by dev DESC and accumulates from the last lag back
-- to the current row, so each row's CDF = product of its factor and all
-- later factors.
CREATE VIEW cdf AS
WITH ff AS (
  SELECT dev, CAST(f_vw AS DOUBLE) AS fac FROM f
  UNION ALL
  SELECT 10 AS dev, CAST(tail_f AS DOUBLE) AS fac FROM tail_param
)
SELECT dev,
       EXP(SUM(LN(fac)) OVER (ORDER BY dev DESC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS cdf
FROM ff;

-- Check: 10 rows. Expected CDFs: dev 10 and 9 = 1.000, dev 8 = 1.0008,
-- dev 5 = 1.0789, dev 1 = 4.7424.
-- Reading: AY 2007 is at lag 1, so its ultimate is about 4.74 times its
-- paid to date.
select * from cdf order by dev;
