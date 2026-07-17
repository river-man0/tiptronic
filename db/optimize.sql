-- Turn the raw `land_polygons` load into a fast tile source.
--
-- Two problems with the raw OSM land polygons on a per-tile query:
--   1. A few rows hold enormous multipolygons (an entire continent's coastline
--      as one geometry). Their bounding box covers most of the map, so the GiST
--      index returns them for nearly every tile and the planner falls back to a
--      sequential scan -- a single low-zoom tile took ~6.8 s in testing.
--   2. Those same giant geometries are re-clipped by ST_AsMvtGeom on every tile.
--
-- ST_Subdivide chops every polygon into pieces of at most 256 vertices. Small
-- pieces have tight bounding boxes, so the spatial index becomes selective
-- (high-zoom tiles drop to sub-millisecond) and each tile only clips the little
-- pieces it actually overlaps (the same low-zoom tile fell to ~0.2 s: ~35x).
--
-- This also does the northern-hemisphere filter the EPSG:3573 grid needs, so it
-- replaces the separate "DELETE ... WHERE ST_YMax(geom) <= 0" step: polygons
-- lying entirely south of the equator are dropped here.
--
-- Idempotent: re-run any time after (re)loading `land_polygons`.

DROP TABLE IF EXISTS land_polygons_opt;

CREATE TABLE land_polygons_opt AS
SELECT row_number() OVER () AS gid,
       ST_Subdivide(geom, 256)::geometry(Polygon, 4326) AS geom
FROM land_polygons
WHERE ST_YMax(geom) > 0;   -- keep only geometry reaching the northern hemisphere

-- Spatial index, then physically order rows to match it for read locality.
CREATE INDEX land_polygons_opt_geom_idx ON land_polygons_opt USING gist (geom);
CLUSTER land_polygons_opt USING land_polygons_opt_geom_idx;

ANALYZE land_polygons_opt;
