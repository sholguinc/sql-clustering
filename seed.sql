-- Create temporal table
CREATE TEMPORARY TABLE tmp_vegetation (
    "LON" FLOAT,
    "LAT" FLOAT,
    "veg_height" FLOAT,
    "alt_cat" FLOAT
);

-- Import data from the CSV into the temporary table
COPY tmp_vegetation ("LON", "LAT", "veg_height", "alt_cat") FROM PROGRAM 'cut -d "," -f 3,4,2,6 /docker-entrypoint-initdb.d/seed.csv' WITH (FORMAT CSV, HEADER);

-- Add a new column "h"
ALTER TABLE tmp_vegetation ADD COLUMN "height_diff" FLOAT;
UPDATE tmp_vegetation SET "height_diff" = alt_cat - veg_height;

-- Insert data
INSERT INTO "Vegetation" (lg, lt, h) SELECT "LON" AS lg, "LAT" AS lt, "height_diff" AS h FROM tmp_vegetation;

-- Drop temporal table
DROP TABLE tmp_vegetation
