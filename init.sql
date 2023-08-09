-- Connect to the database
\c sql_clustering;

-- Create the table
CREATE TABLE "Vegetation" (
    id SERIAL PRIMARY KEY,
    lg FLOAT CHECK (lg >= -180.0 AND lg <= 180.0) NOT NULL,
    lt FLOAT CHECK (lt >= -90.0 AND lt <= 90.0) NOT NULL,
    h FLOAT NOT NULL,
    z INTEGER NOT NULL DEFAULT 20,
    d INTEGER NOT NULL DEFAULT 1
);

-- Create index
CREATE INDEX idx_vegetation_d_z ON "Vegetation" (d, z);

-- Postgis
CREATE EXTENSION IF NOT EXISTS postgis;
