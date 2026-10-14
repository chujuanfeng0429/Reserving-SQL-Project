-- =====================================================================
-- 02_triangles.sql
-- Purpose: Build the loss triangle for the selected company
--          (GRCODE 26433, Harco Natl Ins Co) as of the 2007 valuation date.
-- Key idea: calendar year = accidentyear + developmentlag - 1.
--           Keeping calendar year <= 2007 gives the UPPER triangle (55 cells),
--           i.e. information known at the valuation date.
--           Calendar years 2008-2016 form the LOWER triangle, reserved for
--           back-testing only.
-- =====================================================================

-- Step 1: Upper triangle in long format (one row per accident year x lag).
CREATE view tri as
select accidentyear as ay,                  -- accident year
       developmentlag as dev,               -- development lag (1-10); "dev" is used
                                            -- instead of "lag" because LAG is a SQL function
       cumpaidloss    as paid,              -- cumulative paid loss
       incurredlosses - bulkloss as case_inc  -- case incurred = paid + case reserves
from raw
where grcode = 26433
   and accidentyear + developmentlag -1 <=2007;   -- upper triangle only


-- Check: row count (expected: 55 = 10+9+...+1).
select count(*) from tri;


-- Step 2: Net earned premium by accident year.
-- Premium is the same at every lag, so lag 1 gives one value per year.
CREATE view prem as
SELECT accidentyear as ay, earnedpremnet as prem
from raw
where grcode = 26433 and developmentlag =1;


-- Check: row count (expected: 10).
select COUNT (*) FROM prem;


-- Step 3: Pivot the long table into the classic triangle shape.
-- CASE WHEN turns each development lag into its own column;
-- MAX() picks the single value in each cell.
-- Expected: 10 rows; AY 1998 has 10 values, AY 2007 only d1;
-- NULLs in the bottom-right corner; each row increases left to right.
SELECT ay,
MAX(case when dev=1 then paid END) as d1,
MAX(case when dev=2 then paid END) as d2,
MAX(case when dev=3 then paid END) as d3,
MAX(case when dev=4 then paid END) as d4,
MAX(case when dev=5 then paid END) as d5,
MAX(case when dev=6 then paid END) as d6,
MAX(case when dev=7 then paid END) as d7,
MAX(case when dev=8 then paid END) as d8,
MAX(case when dev=9 then paid END) as d9,
MAX(case when dev=10 then paid END) as d10
from tri
group by ay
order by ay;


-- Step 4: Reasonableness check against the company's posted reserve.
-- from_triangle = sum of (incurred - paid) on the latest diagonal
-- (calendar year 2007). posted = reserve booked by the company.
-- Result: 85,508 vs 91,061 (about 6.5% lower); possible reasons include a
-- different basis, or the posted figure covering accident years before 1998.
select sum(incurredlosses - cumpaidloss) as from_triangle,
       MAX(postedreserves2007)           as posted
from raw
where grcode = 26433
  AND accidentyear + developmentlag -1 =2007;   -- latest diagonal only
