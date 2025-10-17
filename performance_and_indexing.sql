-- =============================================================
-- STAGE 3: PERFORMANCE OPTIMIZATION (INDEXING)
-- Speeds up common lookups and aggregations.
-- =============================================================

-- Index on 'artist' to speed up GROUP BY / COUNT operations (Query 1).
CREATE INDEX idx_tate_artworks_artist
ON tate_artworks (artist);

-- Index on 'acquisitionYear' to speed up time series and trend analysis (Query 2).
CREATE INDEX idx_tate_artworks_acquisition_year
ON tate_artworks (acquisitionYear);

-- Unique index on 'accession_number' for fast, primary lookups.
CREATE UNIQUE INDEX idx_tate_artworks_accession_number
ON tate_artworks (accession_number);

-- Index on the cleaned width column to speed up dimension-based queries.
CREATE INDEX idx_tate_artworks_cleaned_width
ON tate_artworks (cleaned_width_mm);