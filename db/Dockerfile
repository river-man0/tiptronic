FROM docker.io/postgis/postgis:16-3.4

# The base image only ships the server-side extension; the `postgis` package
# adds the client utilities (shp2pgsql, pgsql2shp) used to load shapefiles.
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgis \
    && rm -rf /var/lib/apt/lists/*
