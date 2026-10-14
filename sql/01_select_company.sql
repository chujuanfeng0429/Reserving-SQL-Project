-- =====================================================================
-- 01_select_company.sql
-- Purpose: Screen the 157 companies down to a small set of candidates
--          with clean data, then choose one company for the project.
-- Funnel:  157 companies -> 137 (complete 10x10 data)
--                        -> 95  (all paid values > 0, premium > 0)
--                        -> 15  (cumulative paid never decreases)
-- Run order: cand -> mono -> cand2 (cand2 depends on both).
-- Note: tables are created without DROP IF EXISTS, so re-running a
--       CREATE TABLE raises "already exists"; run DROP TABLE <name>; first.
-- =====================================================================

-- Step 1: Candidate table with basic data-quality filters.
CREATE TABLE cand as
select grcode, grname,
       count(*)      as n_rows,                 -- should be 100 (10 AY x 10 lags)
       min(cumpaidloss) as min_paid,           -- smallest cumulative paid value
       min(earnedpremnet) as min_prem,         -- smallest net earned premium
       -- average of lag-1 premium = one premium value per accident year
       avg (case when developmentlag = 1 then earnedpremnet end) as avg_prem
from raw
group by grcode, grname
having count(*) = 100                           -- complete data
     and min(cumpaidloss) > 0                   -- strictly positive: also excludes zeros
     and min(earnedpremnet)>0;                  -- every year has positive premium

-- Check: companies remaining (expected: 95).
SELECT COUNT(*) FROM cand;


-- Step 2: Flag companies whose cumulative paid ever decreases.
-- Cumulative paid should only increase; a decrease usually means
-- salvage/subrogation recoveries or a data adjustment, and it would
-- produce an age-to-age factor below 1.
CREATE TABLE mono as
with x as (
  select grcode, accidentyear, developmentlag,
       -- window function: this lag's cumulative paid minus the previous lag's,
       -- computed separately for each company and accident year
       cumpaidloss - LAG(cumpaidloss) over (
              partition by grcode, accidentyear order by developmentlag) as inc
  from raw)
select grcode, count(*) filter (where inc<0) as n_decrease   -- number of decreases
from x
group by grcode;


-- Step 3: Keep only companies with no decreases.
create table cand2 as
select c.*
from cand c join mono m using (grcode)
where m.n_decrease = 0;

-- Check: companies remaining (expected: 15).
SELECT count(*) from cand2;

-- Rank remaining companies by size (premium in $ thousands).
select grcode, grname, avg_prem
from cand2
order by avg_prem DESC;


-- Step 4: Keep mid-sized companies (2nd and 3rd quartile by premium).
-- Very large groups tend to be too smooth; very small ones too volatile.
SELECT * FROM (
  select*, ntile(4) over (order by avg_prem) as q from cand2
) WHERE q IN (2,3)
ORDER BY avg_prem;


-- Step 5: Paid loss ratio development of the shortlisted companies
-- (long format). Accident year 1998 only: all 10 lags fall in the upper
-- triangle (calendar year <= 2007), so no future information is used.
-- paid_to_prem = cumulative paid / net earned premium.
select grcode, developmentlag,
       cumpaidloss * 1.0 / earnedpremnet as paid_to_prem
FROM raw
WHERE accidentyear = 1998
  AND grcode IN (19020, 6408, 40568, 21172, 26433)
order by grcode, developmentlag;


-- Step 6: Same comparison in wide format (one column per company),
-- ready to chart in Excel.
-- Note: the finalist company is GRCODE 21172 (alias corrected to c21172).
SELECT developmentlag,
    max(case when grcode = 6408 then cumpaidloss *1.0/ earnedpremnet END) as c6408,
    MAX(case when grcode= 19020 then cumpaidloss*1.0/earnedpremnet END) as c19020,
    MAX(case when grcode= 21172 then cumpaidloss*1.0/earnedpremnet END) as c21172,
    MAX(case when grcode=26433 then cumpaidloss*1.0/earnedpremnet END) AS c26433,
    MAX(case when grcode= 40568 then cumpaidloss*1.0/ earnedpremnet END) AS c40568
FROM raw
where accidentyear =1998
group by developmentlag
order by developmentlag;


-- Step 7: Premium stability by accident year for the two finalists.
-- Lag 1 gives exactly one premium value per accident year.
Select GRCODE, ACCIDENTYEAR, earnedpremnet
FROM raw
WHERE developmentlag = 1 and grcode in (21172, 26433)
order by GRCODE, ACCIDENTYEAR;


-- Step 8: Loss ratios at lags 1, 5 and 10 for each accident year.
-- WARNING (look-ahead bias): lag 5 for AY 2004-2007 and lag 10 for
-- AY 1999-2007 fall in the lower triangle (calendar year > 2007), i.e.
-- information not known at the valuation date. Lag 1 is safe.
-- Disclose this in the README limitations; do not base decisions on it.
SELECT grcode, accidentyear,
   MAX(case when developmentlag= 1 then cumpaidloss * 1.0/ earnedpremnet END) AS lag1,
   MAX(case when developmentlag=5 then cumpaidloss*1.0/ earnedpremnet end) as lag5,
   MAX(case when developmentlag=10 then cumpaidloss *1.0/ earnedpremnet end) as lag10
FROM raw
where grcode in (21172, 26433)
group by grcode, accidentyear
order by grcode, accidentyear;


-- Step 9: Confirm the chosen company passed every filter.
-- Selected: GRCODE 26433 (Harco Natl Ins Co). Expected: 1 row.
select * from cand2 where grcode =26433;
