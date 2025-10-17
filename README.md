# 🖼️ Tate Collection Analysis: Risk & Diversity (PostgreSQL)

[](https://www.google.com/search?q=https://github.com/your-username/your-repo-name)
[](https://www.google.com/search?q=LICENSE)

This project uses **PostgreSQL** to analyze public artist metadata from the Tate Gallery, focusing on two strategic areas for collection management: **demographic diversity** and **longevity-based risk assessment**.

-----

## 💡 Key Project Goals

This analysis provides data-driven answers to support future collection strategy:

1.  **Quantify Diversity:** Calculate the exact percentage share of the collection by gender to identify parity gaps.
2.  **Assess Collection Risk:** Determine the average artistic lifespan and identify artists whose long lives and historical importance make them priority candidates for conservation planning and documentation.
3.  **Cleanse Data:** Implement robust data cleaning strategies using SQL (`NULLIF`) to handle common data errors (like using `0` for unknown dates) and ensure statistical accuracy.

-----

## 🛠️ Requirements

To run this project, you need:

  * **PostgreSQL:** Version 10 or newer.
  * **PSQL Client:** Access to the `psql` command-line utility for executing scripts and bulk loading data.

-----

## 🚀 Installation & Setup

Follow these steps directly in your terminal/PSQL client to prepare the database.

### 1\. Setup and Cleaning Script

Execute the main script. This script handles:

  * Table creation (`artist`).
  * Adding new, safe integer columns (`cleaned_birth_year`, `cleaned_death_year`).
  * Running the initial data cleanup using `NULLIF("yearOfBirth", 0)`.

<!-- end list -->

```bash
psql -d your_database_name -f tate_artists_portfolio_script.sql
```

### 2\. Bulk Data Load

Use the `\COPY` command to import the CSV data directly from the raw source URL.

```bash
\COPY artist FROM 'https://raw.githubusercontent.com/tategallery/collection/refs/heads/master/artist_data.csv' WITH (FORMAT CSV, HEADER TRUE);
```

-----

## 🔎 Core Analysis Examples

These are the primary queries used to extract insights, utilizing advanced PostgreSQL features like **Window Functions** (`SUM() OVER()`).

### Query A: Calculate Diversity Parity

Calculates the exact percentage share for each gender identity found in the dataset.

```sql
WITH GenderCounts AS (
    -- Count the number of artists for each distinct gender
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
    -- Calculate percentage using a Window Function
    ROUND(
        (artist_count * 100.0) / SUM(artist_count) OVER (), 2
    ) AS percentage_share
FROM GenderCounts
ORDER BY artist_count DESC;
```

### Query B: Calculate Average Lifespan (Risk Assessment)

Identifies the mean lifespan across all artists with complete birth and death dates, crucial for benchmarking risk factors.

```sql
SELECT
    AVG(cleaned_death_year - cleaned_birth_year) AS average_lifespan_years
FROM artist
WHERE
    cleaned_birth_year IS NOT NULL AND cleaned_death_year IS NOT NULL
    AND (cleaned_death_year - cleaned_birth_year) > 0;
```

-----

## 🤝 Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'feat: Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

-----

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

-----

## 🗺️ Roadmap

  * **Visualization Integration:** Add a Python script to export results and generate charts using Matplotlib or Seaborn.
  * **Geo-analysis:** Incorporate world data to map artist birth locations and highlight geographic underrepresentation.

-----
