-- =====================================================================
-- 00_load.sql
-- Purpose: Load the CAS Schedule P commercial auto dataset into DuckDB
--          and run basic sanity checks.
-- Data:    CAS Loss Reserving Data Pulled From NAIC Schedule P
--          (commercial auto; accident years 1998-2007, 10 development lags)
-- Note:    Run ONE statement at a time (select it, then Ctrl+Enter),
--          or run the whole script with Alt+X.
-- =====================================================================

-- Step 1: Import the CSV into a table called raw.
-- Replace the path with the location of the file on your own computer.
-- Tip: DuckDB normally expects single quotes around text strings
-- (double quotes are for column names). The double quotes below worked
-- in this setup, but single quotes are the safer choice.
CREATE TABLE raw as
select * from read_csv_auto("C:\Users\Felicity\OneDrive\Desktop\Commercial Auto Data Set .csv");

-- Step 2: Inspect column names and data types (basis for the data dictionary).
describe raw;

-- Step 3: Look at the first 10 rows.
-- One row = one company x accident year x development lag.
SELECT * FROM raw LIMIT 10;

-- Step 4: Check the range of years covered.
-- Expected: accident years 1998-2007, calendar (development) years 1998-2016.
-- The valuation date for this project is the end of 2007.
select min(accidentyear), max(accidentyear),
       min(developmentyear), max(developmentyear)
from raw;

-- Step 5: How many companies have how many rows?
-- A complete company has 10 accident years x 10 lags = 100 rows.
-- Expected: 137 companies with 100 rows; the remaining 20 are incomplete.
SELECT n_rows, COUNT (*) as n_companies
FROM (SELECT  grcode, count(*) as n_rows FROM  raw group by grcode)
group by n_rows
order by n_rows;

-- Step 6: Total number of distinct companies (expected: 157).
select count(distinct grcode) from raw;

-- Step 7: List the companies that do NOT have 100 rows.
-- These are excluded later because their data is incomplete.
SELECT grcode, grname, COUNT (*) as n_rows
FROM raw
GROUP by grcode, grname
HAVING count(*) <> 100
order by n_rows;
