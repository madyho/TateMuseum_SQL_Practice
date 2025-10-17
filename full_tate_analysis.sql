-- =================================================================
-- FULL TATE COLLECTION ANALYSIS PROJECT SCRIPT
-- Executes the entire data pipeline sequentially:
-- 1. Setup (CREATE TABLES)
-- 2. Data Loading (Bulk \COPY)
-- 3. Data Cleaning and Transformation (UPDATE/NULLIF)
-- 4. Performance Optimization (CREATE INDEX)
-- 5. Strategic Reporting (SELECT Queries)
-- =================================================================

-- -----------------------------------------------------------------
-- STAGE 1: SETUP & DATA LOADING (ARTIST TABLE)
-- -----------------------------------------------------------------

-- Drop tables if they exist to allow for clean re-runs
DROP TABLE IF EXISTS tate_artworks;
DROP TABLE IF EXISTS artist;

-- 1.1 Create the Artist table structure
CREATE TABLE artist (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255),
    gender VARCHAR(50),
    dates VARCHAR(255),
    yearOfBirth INTEGER,
    yearOfDeath INTEGER,
    placeOfBirth VARCHAR(255),
    placeOfDeath VARCHAR(255),
    url VARCHAR(512),
    nationalities VARCHAR(255),
    -- Cleaned columns for safe calculations
    cleaned_birth_year INTEGER,
    cleaned_death_year INTEGER
);

-- 1.2 Bulk Load Artist Data
-- NOTE: In a real psql client environment, you would run this command:
-- \COPY artist (id, name, gender, dates, yearOfBirth, yearOfDeath, placeOfBirth, placeOfDeath, url, nationalities) FROM 'path/to/artist_data.csv' WITH (FORMAT CSV, HEADER TRUE);
-- For this demonstration, we assume data is loaded or we rely on a placeholder file.

-- -----------------------------------------------------------------
-- STAGE 2: SETUP & DATA LOADING (ARTWORK TABLE)
-- -----------------------------------------------------------------

-- 2.1 Create the Artwork table structure
CREATE TABLE tate_artworks (
    id INTEGER PRIMARY KEY,
    accession_number VARCHAR(50),
    artistId INTEGER REFERENCES artist(id), -- Foreign Key link to artist table
    title VARCHAR(512),
    medium TEXT,
    creditLine TEXT,
    year VARCHAR(10),
    acquisitionYear INTEGER,
    dimensions TEXT,
    width VARCHAR(50),
    height VARCHAR(50),
    depth VARCHAR(50),
    -- Cleaned numeric columns for analysis
    cleaned_width_mm NUMERIC,
    cleaned_height_mm NUMERIC,
    cleaned_depth_mm NUMERIC
);

-- 2.2 Bulk Load Artwork Data
-- NOTE: In a real psql client environment, you would run this command:
-- \COPY tate_artworks (...) FROM 'path/to/artwork_data.csv' WITH (FORMAT CSV, HEADER TRUE);

-- -----------------------------------------------------------------
-- STAGE 3: DATA CLEANING AND TRANSFORMATION
-- -----------------------------------------------------------------

-- 3.1 Clean Artist Birth/Death Years
-- Convert 0s (used to indicate unknown dates in the raw file) to NULL for accurate math.
-- This is critical for all lifespan calculations.
UPDATE artist
SET
    cleaned_birth_year = NULLIF(yearOfBirth, 0),
    cleaned_death_year = NULLIF(yearOfDeath, 0);


-- 3.2 Clean Artwork Dimensions
-- Use Regular Expressions (REGEXP_REPLACE) to extract numerical values from the 'dimensions' text field.
UPDATE tate_artworks
SET
    cleaned_width_mm = CAST(NULLIF(REGEXP_REPLACE(width, '[^0-9.]', '', 'g'), '') AS NUMERIC),
    cleaned_height_mm = CAST(NULLIF(REGEXP_REPLACE(height, '[^0-9.]', '', 'g'), '') AS NUMERIC),
    cleaned_depth_mm = CAST(NULLIF(REGEXP_REPLACE(depth, '[^0-9.]', '', 'g'), '') AS NUMERIC)
WHERE
    width IS NOT NULL OR height IS NOT NULL OR depth IS NOT NULL;


-- -----------------------------------------------------------------
-- STAGE 4: PERFORMANCE OPTIMIZATION
-- -----------------------------------------------------------------

-- Index frequently used columns for faster JOINs and WHERE clauses
CREATE INDEX idx_artworks_artistId ON tate_artworks (artistId);
CREATE INDEX idx_artworks_medium ON tate_artworks (medium);
CREATE INDEX idx_artworks_acquisitionYear ON tate_artworks (acquisitionYear);


-- -----------------------------------------------------------------
-- STAGE 5: STRATEGIC REPORTING (JOINED QUERIES)
-- These reports answer the core business questions (Diversity & Risk).
-- -----------------------------------------------------------------

-- REPORT 5.1: Collection Diversity Assessment (Artwork Volume by Gender)
-- Goal: Quantify the collection's diversity by the volume of *artworks* associated
-- with each gender, using COALESCE to capture "Unknown" gender records.
WITH ArtworkVolumeByGender AS (
    -- 1. Count the total number of artworks for each distinct gender
    SELECT
        -- Use COALESCE to handle NULL gender records gracefully
        COALESCE(T2.gender, 'Unknown') AS gender_group,
        COUNT(T1.id) AS artwork_count
    FROM tate_artworks T1
    INNER JOIN artist T2 ON T1.artistId = T2.id
    WHERE T2.gender IS NOT NULL AND TRIM(T2.gender) != ''
    GROUP BY gender_group
),
TotalWorks AS (
    -- 2. Calculate the grand total of artworks for percentage calculation
    SELECT SUM(artwork_count) AS grand_total FROM ArtworkVolumeByGender
)
SELECT
    avg.gender_group,
    avg.artwork_count,
    -- Calculate percentage using the grand total from the CTE
    ROUND(
        (avg.artwork_count * 100.0) / total.grand_total, 2
    ) AS percentage_of_collection
FROM ArtworkVolumeByGender avg, TotalWorks total
ORDER BY artwork_count DESC;


-- REPORT 5.2: High-Risk Artist Concentration Report
-- Goal: Identify the top artists who represent the highest concentration of risk.
-- Risk = High Volume of Works (conservation load) + Long Lifespan (historical complexity).
---------------------------------------------------------------------------------
SELECT
    T2.name AS artist_name,
    (T2.cleaned_death_year - T2.cleaned_birth_year) AS artist_lifespan_years,
    COUNT(T1.id) AS total_artworks_in_collection
FROM tate_artworks T1
INNER JOIN artist T2 ON T1.artistId = T2.id
WHERE
    T2.cleaned_birth_year IS NOT NULL
    AND T2.cleaned_death_year IS NOT NULL
    AND (T2.cleaned_death_year - T2.cleaned_birth_year) > 0 -- Ensure valid lifespan
GROUP BY
    T2.name,
    T2.cleaned_birth_year,
    T2.cleaned_death_year
ORDER BY
    total_artworks_in_collection DESC,
    artist_lifespan_years DESC
LIMIT 10;

-- -----------------------------------------------------------------
-- STAGE 6: ADVANCED REPORTING (NEW STRATEGIC QUERIES)
-- -----------------------------------------------------------------

-- REPORT 6.1: Active Artist Risk Flag (High Volume, Still Alive)
-- Goal: Identify living artists (death year IS NULL) with substantial representation.
-------------------------------------------------------------------------------------------
SELECT
    T2.name AS artist_name,
    COUNT(T1.id) AS total_artworks_in_collection
FROM tate_artworks T1
INNER JOIN artist T2 ON T1.artistId = T2.id
WHERE
    T2.cleaned_death_year IS NULL -- The artist is presumed alive
    AND T2.cleaned_birth_year IS NOT NULL
GROUP BY
    T2.name
HAVING
    COUNT(T1.id) >= 50 -- Filter to show only artists with high concentration
ORDER BY
    total_artworks_in_collection DESC;

-- REPORT 6.2: Nationalities Underrepresented in the Collection (Acquisition Target Gaps)
-- Goal: Identify nationalities with low representation to target for future acquisitions.
-------------------------------------------------------------------------------------------
WITH NationalityCounts AS (
    SELECT
        TRIM(nationalities) AS nation,
        COUNT(id) AS artist_count
    FROM artist
    WHERE nationalities IS NOT NULL AND nationalities != ''
    GROUP BY 1
)
SELECT
    nation,
    artist_count,
    ROUND(
        (artist_count * 100.0) / SUM(artist_count) OVER (), 3
    ) AS percentage_share
FROM NationalityCounts
WHERE artist_count < 5 -- Filter for nationalities with fewer than 5 represented artists
ORDER BY artist_count DESC, nation ASC;
