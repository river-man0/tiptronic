# tiptronic

Arctic vector tiles from PostGIS, served on a custom **EPSG:3573** (WGS 84 /
North Pole LAEA Canada) tiling scheme.

```
┌────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│  PostGIS   │ ──► │  BBOX tile       │ ──► │  OpenLayers viewer  │
│  (pgdata   │     │  server          │     │  (static HTML,      │
│   volume)  │     │  + tile cache    │     │   served by BBOX)   │
└────────────┘     └──────────────────┘     └─────────────────────┘
```

- **PostGIS** (`postgis/postgis:16-3.4` + `shp2pgsql`) with a persistent named
  volume (`pgdata`). Load any data you like; port `5432` is published to the
  host.
- **[BBOX](https://www.bbox.earth/)** renders Mapbox Vector Tiles straight from
  PostGIS on a custom polar tile grid and caches every rendered tile in the
  persistent `tilecache` volume, so tiles are only generated once.
- **OpenLayers** static viewer with a matching EPSG:3573 projection/tile grid.

## The EPSG:3573 tiling scheme

`bbox/grids/EPSG3573Quad.json` is an OGC Two-Dimensional Tile Matrix Set
(generated with [morecantile](https://developmentseed.org/morecantile/)),
quadratic and centered on the North Pole:

- extent `[-9009964.761, -9009964.761, 9009964.761, 9009964.761]` — the grid
  edge is the equator ring, so the scheme covers the whole northern hemisphere
- zoom 0 = one 256 px tile, doubling per level, 17 levels (0–16)
- source data in EPSG:4326 is reprojected to EPSG:3573 by BBOX/PostGIS at
  render time

## Quick start

Requires Podman with `podman compose` (podman-compose or the docker-compose
provider).

**1. Start the stack**

```sh
podman compose up -d --build
```

**2. Get the OSM land polygons**

Download the *complete, WGS 84* land polygons from
[osmdata.openstreetmap.de](https://osmdata.openstreetmap.de/data/land-polygons.html)
and unzip into `data/`:

```sh
curl -LO https://osmdata.openstreetmap.de/download/land-polygons-complete-4326.zip
unzip land-polygons-complete-4326.zip -d data/
```

**3. Load `land_polygons.shp` into PostGIS**

```sh
podman compose exec db sh -c \
  'shp2pgsql -s 4326 -I -D -g geom /data/land-polygons-complete-4326/land_polygons.shp public.land_polygons | psql -q -U gis -d gis'
podman compose exec db psql -U gis -d gis -c 'ANALYZE land_polygons;'
```

**4. Open the viewer**

<http://localhost:8080/viewer/index.html>

The first visit renders tiles from the database (the planet-wide land polygons
make low zooms slow the first time); after that they come straight from the
cache.

## Endpoints

| URL | What |
| --- | --- |
| `http://localhost:8080/viewer/index.html` | OpenLayers viewer |
| `http://localhost:8080/xyz/land/{z}/{x}/{y}.pbf` | vector tiles on the EPSG:3573 grid |
| `http://localhost:8080/xyz/land.json` | TileJSON metadata |
| `localhost:5432`, db/user/password `gis` | PostGIS |

## Loading your own data

Put files in `data/` (mounted read-only at `/data` in the db container) and
load them with `shp2pgsql` as above, or connect to `localhost:5432` with
ogr2ogr/QGIS. Then add a `[[tileset.postgis.layer]]` (or a new `[[tileset]]`)
in `bbox/bbox.toml`, set `srid` to your data's SRID — BBOX reprojects to the
grid CRS automatically — and restart: `podman compose restart bbox`.

## Cache management

Tiles are cached on first request. To pre-render (seed) low zooms:

```sh
podman compose exec bbox bbox-server seed --tileset=land --maxzoom=6
```

After changing data or style-relevant config, clear the cache:

```sh
podman compose down bbox && podman volume rm tiptronic_tilecache && podman compose up -d bbox
```
