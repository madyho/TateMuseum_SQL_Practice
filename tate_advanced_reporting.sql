-- =============================================================
-- STAGE 4: ADVANCED REPORTING QUERIES
-- Showcases CTEs, Window Functions, and Conditional Logic for complex analysis.
-- =============================================================

-- Query 1: Find the Largest Artwork Acquired in Each Decade
-- Identifies decade-by-decade acquisition strategies related to size.
WITH ArtworkArea AS (
    -- 1. Calculate Area and determine the decade of acquisition
    SELECT
        title,
        artist,
        (cleaned_width_mm * cleaned_height_mm) AS area_sq_mm,
        acquisitionYear,
        -- Extract the decade from the acquisitionYear
        FLOOR(acquisitionYear / 10) * 10 AS acquisition_decade
    FROM tate_artworks
    WHERE cleaned_width_mm IS NOT NULL
      AND cleaned_height_mm IS NOT NULL
      AND acquisitionYear IS NOT NULL
      AND acquisitionYear > 1800
),
RankedArea AS (
    -- 2. Rank artworks within each decade based on size
    SELECT
        *,
        RANK() OVER (PARTITION BY acquisition_decade ORDER BY area_sq_mm DESC) AS rank_in_decade
    FROM ArtworkArea
)
-- 3. Select only the largest (Rank 1) artwork from each decade
SELECT
    acquisition_decade,
    title,
    artist,
    ROUND(area_sq_mm / 1000000, 2) AS area_sq_m -- Convert mm^2 to m^2 for readability
FROM RankedArea
WHERE rank_in_decade = 1
ORDER BY acquisition_decade DESC;


-- Query 2: Acquisition Analysis by Era (Historic vs. Modern)
-- Quantifies the collection's focus on historic versus modern art and tracks recent acquisitions.
SELECT
    -- Define the era based on the original 'year' field
    CASE
        WHEN CAST(year AS INTEGER) < 1900 THEN 'Historic (Pre-1900)'
        WHEN CAST(year AS INTEGER) >= 1900 THEN 'Modern (1900+)'
        ELSE 'Unknown Era'
    END AS art_era,
    -- Use COUNT and FILTER to get conditional aggregates
    COUNT(*) AS total_artworks_in_era,
    -- Count works acquired after the year 2000 for this era
    COUNT(*) FILTER (WHERE acquisitionYear >= 2000) AS acquired_after_2000,
    -- Calculate the percentage of works acquired after 2000
    ROUND(CAST(COUNT(*) FILTER (WHERE acquisitionYear >= 2000) AS NUMERIC) * 100 / COUNT(*), 2) AS percent_acquired_recently
FROM tate_artworks
WHERE year ~ '^[0-9]+$' -- Filter out non-numeric entries
GROUP BY art_era
ORDER BY art_era DESC;


-- Query 3: Analyze Title Length Trends
-- Provides insight into how textual metadata has changed over time.
WITH TitleStats AS (
    -- 1. Calculate title length and decade of creation
    SELECT
        LENGTH(title) AS title_length,
        FLOOR(CAST(year AS INTEGER) / 10) * 10 AS creation_decade
    FROM tate_artworks
    WHERE year ~ '^[0-9]+$' -- Ensure 'year' is numeric for CAST
      AND title IS NOT NULL
      AND CAST(year AS INTEGER) > 1700
)
-- 2. Aggregate the results
SELECT
    creation_decade,
    COUNT(*) AS works_in_decade,
    -- Calculate the average title length for all works in that decade
    ROUND(AVG(title_length), 2) AS avg_title_length_chars
FROM TitleStats
GROUP BY creation_decade
ORDER BY creation_decade DESC;