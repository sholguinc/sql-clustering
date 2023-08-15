-- Delete all non-vegetation rows
DELETE FROM "Vegetation" WHERE z <> 20;


-- Clustering function
CREATE OR REPLACE FUNCTION perform_clustering(d_value INTEGER, zoom_level INTEGER) RETURNS VOID AS $$
DECLARE
    radius DECIMAL(18, 2) = 70;
    extent DECIMAL(18, 2) = 512;
    distance DECIMAL(18, 15);
    epsilon DECIMAL(18, 15);
BEGIN
    -- Create temporal initial data table
    CREATE TEMPORARY TABLE tmp_input_data AS
    SELECT
        id,
        ST_SetSRID(ST_MakePoint(lg, lt), 4326) AS geom,
        h
    FROM JustVegetationDelta;

    -- Clusters
    CREATE TEMPORARY TABLE tmp_clusters (LIKE "Vegetation" INCLUDING ALL);

    -- zoom and epsilon relationship
    distance := radius / (extent * POWER(2, zoom_level));
    epsilon := 150 * distance;

    -- Get clusters data
    WITH tmp_output_data AS (
        SELECT
            id,
            geom,
            ST_ClusterDBSCAN(geom, eps := epsilon, minpoints := 1) OVER () AS cluster_id,
            h
        FROM tmp_input_data
    )

    -- Insert clusters data
    INSERT INTO tmp_clusters (lg, lt, h, z, d)
    SELECT
        AVG(ST_X(ST_Centroid(geom))) AS lg,
        AVG(ST_Y(ST_Centroid(geom))) AS lt,
        MIN(h) AS h,
        zoom_level AS z,
        d_value AS d
    FROM tmp_output_data GROUP BY cluster_id ORDER BY cluster_id;

    -- Add clusters to vegetation
    INSERT INTO "Vegetation" SELECT * FROM tmp_clusters;

    -- Drop temporal table
    DROP TABLE tmp_input_data, tmp_clusters;
END;
$$ LANGUAGE plpgsql;


-- Iterate over distinct "zoom" values
CREATE OR REPLACE FUNCTION clustering_for_delta(d_value INTEGER) RETURNS VOID AS $$
DECLARE z_value INTEGER;
BEGIN
    FOR z_value IN REVERSE 19..1 LOOP
        -- Perform clustering for certain zoom value
        PERFORM perform_clustering(d_value, z_value);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Iterate over "delta time" values
DO $$
DECLARE
    d_value INTEGER;
BEGIN
    RAISE NOTICE 'Initializing clustering process...';

    -- Just vegetation table
    CREATE TABLE JustVegetation AS
    SELECT * FROM "Vegetation" WHERE z = 20;

    -- Loop over distinct "d" values
    FOR d_value IN (SELECT DISTINCT d FROM JustVegetation ORDER BY d) LOOP
        RAISE NOTICE 'Processing data for d = %...', d_value;

        -- Just vegetation delta table
        CREATE TABLE JustVegetationDelta AS
        SELECT * FROM JustVegetation WHERE d = d_value;

        -- Perform clustering for certain zoom value
        PERFORM clustering_for_delta(d_value);

        -- Drop just vegetation delta table
        DROP TABLE JustVegetationDelta;
    END LOOP;

    -- Drop just vegetation table
    DROP TABLE JustVegetation;

    RAISE NOTICE 'Finished clustering process.';
END $$;


-- Drop functions
DROP FUNCTION clustering_for_delta, perform_clustering;
