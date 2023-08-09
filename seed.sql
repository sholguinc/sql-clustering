CREATE OR REPLACE FUNCTION seed_vegetation_data(index INT, csv_path TEXT) RETURNS VOID AS $$
BEGIN
    -- Create temporal table
    CREATE TEMPORARY TABLE tmp_vegetation (
        "LON" FLOAT,
        "LAT" FLOAT,
        "veg_height" FLOAT,
        "alt_cat" FLOAT
    );

    -- Import data from the CSV into the temporary table
    EXECUTE format('COPY tmp_vegetation ("LON", "LAT", "veg_height", "alt_cat") FROM PROGRAM ''cut -d "," -f 3,4,2,6 %s'' WITH (FORMAT CSV, HEADER)', csv_path);

    -- Add a new column "h"
    ALTER TABLE tmp_vegetation ADD COLUMN "height_diff" FLOAT;
    UPDATE tmp_vegetation SET "height_diff" = alt_cat - veg_height;

    -- Add a new column "d"
    ALTER TABLE tmp_vegetation ADD COLUMN "delta_time" INTEGER;
    UPDATE tmp_vegetation SET "delta_time" = index;

    -- Insert data
    INSERT INTO "Vegetation" (lg, lt, h, d) SELECT "LON" AS lg, "LAT" AS lt, "height_diff" AS h, "delta_time" AS d FROM tmp_vegetation;

    -- Drop temporal table
    DROP TABLE tmp_vegetation;
END;
$$ LANGUAGE plpgsql;


-- Seed data
DO $$
DECLARE
    csv_files TEXT[] := ARRAY['seed_total_1.csv', 'seed_total_2.csv'];
    csv_name TEXT;
    csv_path TEXT;
    index INT;
BEGIN
    -- Iterate over each file
    FOR index IN 1..array_length(csv_files, 1) LOOP
        csv_name := csv_files[index];
        csv_path := '/data/' || csv_name;

        RAISE NOTICE 'Seeding data for d = %.', index;
        PERFORM seed_vegetation_data(index, csv_path);
    END LOOP;
END $$;


-- Drop function
DROP FUNCTION seed_vegetation_data;
