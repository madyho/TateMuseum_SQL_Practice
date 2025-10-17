-- =============================================================
-- STRATEGIC BUSINESS REPORTS: DIVERSITY AND RISK MANAGEMENT
-- These queries analyze the collection based on the business goals of
-- diversity assessment and concentration risk identification.
--
-- ACTION: Queries explicitly JOIN the 'tate_artworks' table
-- (artwork volume) with the 'artist' table (demographics) using artistId = id.
-- =============================================================

-- Query 1: Collection Diversity Assessment (Artwork Volume by Gender)
-- Goal: Quantify the collection's diversity by the volume of *artworks* associated
-- with each gender, highlighting representation gaps.
---------------------------------------------------------------------------------
WITH ArtworkVolumeByGender AS (
    -- 1. Count the total number of artworks for each distinct gender
    SELECT
        COALESCE(T2.gender, 'Unknown') AS gender_group, -- COALESCE returns the first non-null expression in a list of arguments.
        COUNT(T1.id) AS artwork_count
    FROM tate_artworks T1
    -- JOIN to access the 'gender' column from the 'artist' table (T2)
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


-- Query 2: High-Risk Artist Concentration Report
-- Goal: Identify the top artists who represent the highest concentration of risk.
-- Risk = High Volume of Works (conservation load) + Long Lifespan (complex estates/historical depth).
---------------------------------------------------------------------------------
SELECT
    T2.name AS artist_name,
    -- Calculate the artist's lifespan using the cleaned data from the 'artist' table
    (T2.cleaned_death_year - T2.cleaned_birth_year) AS artist_lifespan_years,
    COUNT(T1.id) AS total_artworks_in_collection
FROM tate_artworks T1
-- JOIN to access the 'name' and cleaned year columns from the 'artist' table (T2)
INNER JOIN artist T2 ON T1.artistId = T2.id
WHERE
    -- Must have known lifespan for risk calculation
    T2.cleaned_birth_year IS NOT NULL
    AND T2.cleaned_death_year IS NOT NULL
    AND (T2.cleaned_death_year - T2.cleaned_birth_year) > 0 -- Ensure valid lifespan
GROUP BY
    T2.name,
    T2.cleaned_birth_year,
    T2.cleaned_death_year
-- Order by artwork volume (most concentrated) and then by lifespan (highest risk complexity)
ORDER BY
    total_artworks_in_collection DESC,
    artist_lifespan_years DESC
LIMIT 10;
