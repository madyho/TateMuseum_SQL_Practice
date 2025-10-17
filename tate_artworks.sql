-- =============================================================
-- STAGE 1: TATE ARTWORKS TABLE SETUP AND IDEMPOTENT CLEANING (ETL)
-- This will set up the table with the matching columns for data.
-- =============================================================

-- 0. Create Base Table
CREATE TABLE IF NOT EXISTS tate_artworks (
    id BIGINT PRIMARY KEY,
    accession_number VARCHAR(10),
    artist TEXT,
    artistRole VARCHAR(50),
    artistId INTEGER,
    title TEXT,
    dateText TEXT,
    medium TEXT,
    creditLine TEXT,
    year VARCHAR(10),
    acquisitionYear INTEGER,
    dimensions TEXT,
    width TEXT,     
    height TEXT,     
    depth TEXT,      
    units VARCHAR(10),
    inscription TEXT,
    thumbnailCopyright TEXT,
    thumbnailUrl TEXT,
    url TEXT
);

-- 1. Create Cleaned Columns (Idempotent using DO blocks)
-- Uses dynamic SQL (PL/pgSQL) to safely add columns only if they don't exist,
-- preventing the "syntax error at IF NOT EXISTS" error.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tate_artworks' AND column_name = 'cleaned_width_mm') THEN
        ALTER TABLE tate_artworks ADD COLUMN cleaned_width_mm NUMERIC;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tate_artworks' AND column_name = 'cleaned_height_mm') THEN
        ALTER TABLE tate_artworks ADD COLUMN cleaned_height_mm NUMERIC;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tate_artworks' AND column_name = 'cleaned_depth_mm') THEN
        ALTER TABLE tate_artworks ADD COLUMN cleaned_depth_mm NUMERIC;
    END IF;
END
$$;

-- 2. Populate Cleaned Columns with data
-- Notes for Reference: This UPDATE is more robust than simple CAST, using REGEXP_REPLACE to remove
-- stray letters ('mm', 'cm') or symbols, and NULLIF to handle empty results.
-- The WHERE clause ensures we only update rows that haven't been cleaned yet (idempotent update).
UPDATE tate_artworks
SET
    cleaned_width_mm = NULLIF(
        REGEXP_REPLACE(LOWER(width), '[^0-9.]', '', 'g'), -- Strip non-numeric/non-decimal characters
        '' -- Convert resulting empty strings to NULL
    )::NUMERIC,

    cleaned_height_mm = NULLIF(
        REGEXP_REPLACE(LOWER(height), '[^0-9.]', '', 'g'),
        ''
    )::NUMERIC,

    cleaned_depth_mm = NULLIF(
        REGEXP_REPLACE(LOWER(depth), '[^0-9.]', '', 'g'),
        ''
    )::NUMERIC
WHERE
    -- Only process records that still have NULL values in the cleaned columns
    cleaned_width_mm IS NULL
    OR cleaned_height_mm IS NULL
    OR cleaned_depth_mm IS NULL;


-- 3. Validation Check: View the original and cleaned columns side-by-side.
SELECT
    width AS original_width,
    cleaned_width_mm,
    height AS original_height,
    cleaned_height_mm
FROM tate_artworks
WHERE cleaned_width_mm IS NOT NULL
LIMIT 10;

-- =============================================================
-- STAGE 2: ADVANCED ANALYTICAL QUERIES
-- Demonstrates using joins, aggregates, and calculations to find insights.
-- Note: These rely on the cleaned_width/height/depth columns being populated.
-- =============================================================

-- Query 1: Top 10 Most Represented Artists in the Collection
SELECT
    artist,
    COUNT(*) AS artwork_count
FROM tate_artworks
GROUP BY artist
ORDER BY artwork_count DESC
LIMIT 10;

-- Query 2: Acquisition Trend Over Time (Number of works acquired per year)
SELECT
    acquisitionYear,
    COUNT(*) AS total_acquired
FROM tate_artworks
WHERE acquisitionYear IS NOT NULL
GROUP BY acquisitionYear
ORDER BY acquisitionYear;

-- Query 3: Most Common Media and Materials Used
SELECT
    medium,
    COUNT(*) AS medium_count
FROM tate_artworks
GROUP BY medium
ORDER BY medium_count DESC
LIMIT 5;

-- Query 4: Find the 5 Largest 2D Artworks (based on cleaned data)
-- Calculates the area (Width x Height) for works where dimensions exist.
SELECT
    title,
    artist,
    medium,
    (cleaned_width_mm * cleaned_height_mm) AS area_sq_mm
FROM tate_artworks
-- Filter out non-numeric or null dimensions
WHERE cleaned_width_mm IS NOT NULL
  AND cleaned_height_mm IS NOT NULL
ORDER BY area_sq_mm DESC
LIMIT 5;

-- Query 5: Average Width of Artworks Created in the 19th Century (1801-1900)
-- This query uses pattern matching on the original 'year' field to identify the century.
SELECT
    AVG(cleaned_width_mm) AS avg_width_19th_century
FROM tate_artworks
-- Use the 'year' field (VARCHAR) and pattern matching
WHERE year LIKE '18%'
  AND cleaned_width_mm IS NOT NULL;
