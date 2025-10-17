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