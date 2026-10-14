-- =====================================================================
-- 05_chain_ladder.sql
-- Purpose: First estimate of ultimate losses and reserves using the
--          paid chain-ladder method, and comparison with the posted reserve.
-- Depends on: views tri, prem (02_triangles.sql) and cdf (04_cdf.sql).
-- Method:  Ultimate loss = latest cumulative paid x CDF.
--          Unpaid loss (reserve estimate) = ultimate - paid.
-- =====================================================================

-- Step 1: Latest diagonal of the triangle.
-- Calendar year 2007 (ay + dev - 1 = 2007) gives one cell per accident
-- year: how much has been paid to date at the valuation date.
CREATE VIEW latest AS
SELECT ay, dev, paid
FROM tri
WHERE ay + dev - 1 = 2007;

-- Check: row count (expected: 10).
SELECT COUNT(*) FROM latest;


-- Step 2: Chain-ladder ultimate loss and reserve by accident year.
-- Each accident year is matched to the CDF of the development lag it is
-- currently at (JOIN cdf ON c.dev = l.dev), and to its earned premium.
CREATE VIEW cl AS
SELECT l.ay, l.dev, l.paid, p.prem, c.cdf,
       l.paid * c.cdf               AS ult_cl,      -- ultimate loss
       l.paid * c.cdf - l.paid      AS unpaid_cl,   -- unpaid loss (reserve estimate)
       l.paid * c.cdf / p.prem      AS lr_cl,       -- ultimate loss ratio
       1 - 1.0 / c.cdf              AS pct_unpaid   -- % of ultimate still unpaid
                                                    -- (used by Bornhuetter-Ferguson later)
FROM latest l
JOIN cdf  c ON c.dev = l.dev
JOIN prem p ON p.ay  = l.ay;

-- Review: one row per accident year.
SELECT * FROM cl ORDER BY ay;


-- Step 3: Total reserve versus the company's posted reserve.
-- Result: paid 226,277; ultimate 302,752; chain-ladder reserve 76,475;
-- posted reserve 91,061 (chain-ladder is about 16% lower).
-- Amounts are in thousands of dollars (confirm in CAS documentation).
SELECT SUM(paid)       AS total_paid,
       SUM(ult_cl)     AS total_ult,
       SUM(unpaid_cl)  AS cl_reserve,
       (SELECT MAX(postedreserves2007) FROM raw WHERE grcode = 26433) AS posted
FROM cl;
