-- =============================================================
-- STAGE 1: TABLE CREATION AND DATA LOADING
-- NOTE: Table created with INTEGER columns as per your existing setup.
-- =============================================================

-- Table name remains 'artist' as per your existing structure.
CREATE TABLE IF NOT EXISTS artist (
    id INTEGER PRIMARY KEY,
    name TEXT,
    gender VARCHAR(10),
    dates TEXT,
    -- COLUMN TYPE ADJUSTED: These columns are INTEGER in your database.
    "yearOfBirth" INTEGER,
    "yearOfDeath" INTEGER,
    -- ADDED COLUMNS: Based on your schema image.
    "placeOfBirth" TEXT,
    "placeOfDeath" TEXT,
    nationalities TEXT,
    wikipediaUrl TEXT,
    url TEXT
);

-- Command to load the data from the Tate's GitHub repository:
-- (Uncomment and run this in your psql terminal, ensuring you match your exact table name)
-- \COPY artist FROM 'https://raw.githubusercontent.com/tategallery/collection/refs/heads/master/artist_data.csv' WITH (FORMAT CSV, HEADER TRUE);


-- =============================================================
-- STAGE 2: ROBUST DATA CLEANING (IDEMPOTENT)
-- Since the source is INTEGER, cleaning focuses on converting '0' (Unknown) to NULL.
-- =============================================================

-- 1. CLEANING: Birth Year (using yearOfBirth)
DO $$
BEGIN
    -- Check against the 'artist' table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        -- Corrected to match the column name shown in your schema image
        WHERE table_name = 'artist' AND column_name = 'cleaned_birth_year'
    ) THEN
        -- If it doesn't exist, create it
        ALTER TABLE artist ADD COLUMN cleaned_birth_year INTEGER;
    END IF;
END $$;

UPDATE artist
-- Use double quotes to reference the case-sensitive column, and NULLIF(0) for unknown values.
SET cleaned_birth_year = NULLIF("yearOfBirth", 0)
WHERE cleaned_birth_year IS NULL;


-- 2. CLEANING: Death Year (using yearOfDeath)
DO $$
BEGIN
    -- Check against the 'artist' table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        -- Assumed consistent naming with underscores
        WHERE table_name = 'artist' AND column_name = 'cleaned_death_year'
    ) THEN
        -- If it doesn't exist, create it
        ALTER TABLE artist ADD COLUMN cleaned_death_year INTEGER;
    END IF;
END $$;

UPDATE artist
-- Use double quotes to reference the case-sensitive column, and NULLIF(0) for unknown values.
SET cleaned_death_year = NULLIF("yearOfDeath", 0)
WHERE cleaned_death_year IS NULL;


-- 3. Validation Check: Compare raw data to cleaned data for the first 10 rows
SELECT
    -- FIX APPLIED: Surrounding the case-sensitive column names with double quotes (" ")
    "name",
    "yearOfBirth" AS raw_birth,
    cleaned_birth_year,
    "yearOfDeath" AS raw_death,
    cleaned_death_year
FROM artist
LIMIT 10;

-- =============================================================
-- END OF SETUP AND CLEANING
-- =============================================================

-- =============================================================
-- PORTFOLIO ANALYTICAL QUERIES ON ARTIST DEMOGRAPHICS
-- These queries leverage the cleaned INTEGER year columns (cleaned_birth_year, etc.)
-- to extract meaningful insights about the Tate's represented artists.
-- =============================================================

-- Query 1: Average Lifespan of Artists (A key derived metric)
-- Calculates the average age at death for all artists with known birth and death years.
SELECT
    -- Calculate lifespan for each artist first, then average the results.
    AVG(cleaned_death_year - cleaned_birth_year) AS average_lifespan_years
FROM artist
WHERE
    cleaned_birth_year IS NOT NULL AND cleaned_death_year IS NOT NULL
    -- Exclude impossible lifespans (e.g., birthYear > deathYear)
    AND (cleaned_death_year - cleaned_birth_year) > 0;

-- Query 2: Artist Birth Count by Century (Using Conditional Logic/CASE)
-- Demonstrates the use of CASE statements to bucket numerical data into historical categories.
SELECT
    CASE
        WHEN cleaned_birth_year BETWEEN 1700 AND 1799 THEN '18th Century'
        WHEN cleaned_birth_year BETWEEN 1800 AND 1899 THEN '19th Century'
        WHEN cleaned_birth_year BETWEEN 1900 AND 1999 THEN '20th Century'
        ELSE 'Other/Unknown'
    END AS birth_century,
    COUNT(id) AS total_artists
FROM artist
GROUP BY 1 -- Group by the calculated century
ORDER BY 2 DESC;

-- Query 3: Gender Distribution and Representation (Using Ratios/Window Functions)
-- Calculates the raw count and the percentage share of the total for each gender.
WITH GenderCounts AS (
    SELECT
        gender,
        COUNT(id) AS artist_count
    FROM artist
    WHERE gender IS NOT NULL AND gender != ''
    GROUP BY gender
)
SELECT
    gender,
    artist_count,
    -- Calculate the percentage share using a window function for the total count
    ROUND(
        (artist_count * 100.0) / SUM(artist_count) OVER (), 2
    ) AS percentage_share
FROM GenderCounts
ORDER BY artist_count DESC;

-- Query 4: Top 5 Longest Lived Artists
-- Finds the artists with the longest lifespan, demonstrating derivation of new metrics.
SELECT
    "name",
    -- Use COALESCE to provide a placeholder if placeOfDeath is NULL for reporting clarity
    COALESCE("placeOfDeath", 'Unknown') AS place_of_death,
    (cleaned_death_year - cleaned_birth_year) AS lifespan_years
FROM artist
WHERE
    cleaned_birth_year IS NOT NULL AND cleaned_death_year IS NOT NULL
ORDER BY lifespan_years DESC
LIMIT 5;

-- Query 5: Analysis of Top 5 Places of Birth (Alternative to Nationality)
-- Examines the geographic origins of the artists using the available "placeOfBirth" column.
SELECT
    -- Use TRIM to remove any leading/trailing spaces from the text field before grouping.
    TRIM("placeOfBirth") AS birth_location,
    COUNT(id) AS artist_count
FROM artist
WHERE "placeOfBirth" IS NOT NULL AND "placeOfBirth" != ''
GROUP BY 1
ORDER BY artist_count DESC
LIMIT 5;
