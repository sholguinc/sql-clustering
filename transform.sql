-- -- Transform Vegetation
-- RAISE NOTICE 'Initializing clustering process...';
--
-- DO $$
-- DECLARE
--     d_value INTEGER;
-- BEGIN
--     -- Loop over distinct "d" values
--     FOR d_value IN (SELECT DISTINCT d FROM "Vegetation") LOOP
--         -- Create a temporary table for each d
--         EXECUTE 'CREATE TEMPORARY TABLE tmp_vegetation_' || d_value || ' AS ' ||
--                 'SELECT * FROM "Vegetation" WHERE d = ' || d_value;
--
--         -- Clustering for a certain delta
--         RAISE NOTICE 'Processing data for d = %...', d_value;
--         EXECUTE 'SELECT * FROM tmp_group_' || d_value;
--
--         -- Drop temporal vegetation table
--         EXECUTE 'DROP TABLE IF EXISTS tmp_vegetation_' || d_value;
--     END LOOP;
-- END $$;
--
-- RAISE NOTICE 'Finished clustering process.';
--
-- -- Clustering for certain delta
-- CREATE OR REPLACE FUNCTION clustering(d_value, custom_table_type[])
-- RETURNS SETOF custom_table_type AS $$
-- DECLARE
--     row custom_table_type;
-- BEGIN
--     FOREACH row IN ARRAY input_table
--     LOOP
--         -- Process the row here and potentially modify its values
--         -- For this example, we're just returning the same rows
--         RETURN NEXT row;
--     END LOOP;
--     RETURN;
-- END;
-- $$ LANGUAGE plpgsql;

-- Clustering function
CREATE OR REPLACE FUNCTION perform_clustering(zoom_value INTEGER) RETURNS VOID AS $$
DECLARE
BEGIN
    RAISE NOTICE 'Processing data for z = %...', zoom_value;

    -- Create temporal initial data table
    CREATE TEMPORARY TABLE tmp_input_data AS
    SELECT
        id,
        ST_SetSRID(ST_MakePoint(lg, lt), 4326) AS geom,
        h
    FROM JustVegetation;

    -- Clusters
    CREATE TEMPORARY TABLE tmp_clusters (LIKE "Vegetation" INCLUDING ALL);

    -- Get clusters data
    WITH tmp_output_data AS (
        SELECT
            id,
            geom,
            ST_ClusterDBSCAN(geom, eps := 1 / zoom_value, minpoints := 2) OVER () AS cluster_id,
            h
        FROM tmp_input_data
    )

    -- Insert clusters data
    INSERT INTO tmp_clusters (lg, lt, h, z, d)
    SELECT
        AVG(ST_X(ST_Centroid(geom))) AS lg,
        AVG(ST_Y(ST_Centroid(geom))) AS lt,
        MIN(h) AS h,
        zoom_value AS z,
        1 AS d
    FROM tmp_output_data GROUP BY cluster_id ORDER BY cluster_id;

    -- Add clusters to vegetation
    INSERT INTO "Vegetation" SELECT * FROM tmp_clusters;

    -- Drop temporal table
    DROP TABLE tmp_input_data, tmp_clusters;
END;
$$ LANGUAGE plpgsql;


-- Clustering
DO $$
DECLARE z_value INTEGER;
BEGIN
    -- Iterate over distinct "zoom" values
    FOR z_value IN REVERSE 19..1 LOOP

        -- Just vegetation table
        CREATE TABLE JustVegetation AS
        SELECT * FROM "Vegetation" WHERE z = 20;

        -- Perform clustering for certain zoom value
        PERFORM perform_clustering(z_value);

        -- Drop just vegetation table
        DROP TABLE JustVegetation;
    END LOOP;
END $$;
