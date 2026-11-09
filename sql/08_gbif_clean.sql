-- 08_gbif_clean.sql: jellyfish (class Scyphozoa) records from GBIF, iNaturalist research-grade, 2019-2025, Puget Sound box.
-- Date = GBIF-interpreted year/month/day fields (checked against eventDate below). Observer names are not stored.
CREATE OR REPLACE TABLE gbif_jelly AS
SELECT key, year, month, day,
       try(make_date(year, month, day)) AS obs_date,
       decimalLatitude AS lat, decimalLongitude AS lon, coordinateUncertaintyInMeters AS coord_unc_m,
       taxonRank, taxonomicStatus,
       coalesce(species, '(not identified to species)') AS species,
       license, issues, CAST(eventDate AS DATE) AS event_date_utc
FROM raw_gbif_jelly
QUALIFY row_number() OVER (PARTITION BY key ORDER BY key) = 1;

-- Analysis set: has a full valid date within 2019-2025 and valid coordinates inside the box.
CREATE OR REPLACE TABLE gbif_jelly_valid AS
SELECT * FROM gbif_jelly
WHERE obs_date IS NOT NULL AND year BETWEEN 2019 AND 2025
  AND lat BETWEEN -90 AND 90 AND lon BETWEEN -180 AND 180
  AND lat BETWEEN 47.0 AND 48.5 AND lon BETWEEN -123.2 AND -122.2;

CREATE OR REPLACE TABLE dq_gbif_jellyfish AS
SELECT 'rows downloaded' AS check_name, count(*) AS n_records, '' AS detail FROM raw_gbif_jelly
UNION ALL SELECT 'duplicate keys removed', (SELECT count(*) FROM raw_gbif_jelly) - (SELECT count(*) FROM gbif_jelly), ''
UNION ALL SELECT 'missing or invalid date', count(*), '' FROM gbif_jelly WHERE obs_date IS NULL
UNION ALL SELECT 'missing coordinates', count(*), '' FROM gbif_jelly WHERE lat IS NULL OR lon IS NULL
UNION ALL SELECT 'outside box or 2019-2025 (dropped from analysis)', (SELECT count(*) FROM gbif_jelly) - (SELECT count(*) FROM gbif_jelly_valid), ''
UNION ALL SELECT 'coordinate uncertainty missing', count(*), '' FROM gbif_jelly WHERE coord_unc_m IS NULL
UNION ALL SELECT 'coordinate uncertainty > 5000 m (kept; my screen)', count(*), '' FROM gbif_jelly WHERE coord_unc_m > 5000
UNION ALL SELECT 'GBIF date differs from eventDate UTC date', count(*), '' FROM gbif_jelly WHERE event_date_utc <> obs_date
UNION ALL SELECT 'not identified to species rank', count(*), '' FROM gbif_jelly WHERE taxonRank <> 'SPECIES'
UNION ALL SELECT 'taxonomic status not ACCEPTED', count(*), '' FROM gbif_jelly WHERE taxonomicStatus <> 'ACCEPTED'
UNION ALL SELECT 'licence: ' || CASE WHEN license LIKE '%/by-nc/%' THEN 'CC BY-NC' WHEN license LIKE '%/by/%' THEN 'CC BY' WHEN license LIKE '%/zero/%' THEN 'CC0' ELSE coalesce(license, 'missing') END, count(*), '' FROM gbif_jelly GROUP BY 1
UNION ALL SELECT 'species: ' || species, count(*), '' FROM gbif_jelly GROUP BY species;
COPY (SELECT * FROM dq_gbif_jellyfish ORDER BY check_name) TO 'outputs/dq_gbif_jellyfish.csv' (HEADER);
