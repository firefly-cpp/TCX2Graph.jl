using JSON
using Dates
using Printf
using Statistics

export plot_property_graph

"""
plot_property_graph(graph, all_gps_data; out_dir="./example_data/all_plots/leaflet_viewer",
                    simplify_tolerance_m=0.0, quantize_decimals=5, min_points=2,
                    export_point_properties=false, properties_whitelist=nothing,
                    sample_rate=1, max_points_per_file=10000)

Generate per-file GeoJSON LineString files and a compact Leaflet index.html that dynamically loads them.
- graph: graph object (kept for API compatibility).
- all_gps_data: Dict{Int, Dict{String,Any}} mapping vertex index -> trackpoint properties (must include "latitude" and "longitude", ideally "file_name").
- simplify_tolerance_m: simplification epsilon in meters (Douglas–Peucker). 0.0 disables simplification.
- quantize_decimals: number of decimals to round coordinates for size reduction.
- min_points: skip paths with fewer than this many points after simplification.
- export_point_properties: optionally export per-point GeoJSON with a properties whitelist.
- properties_whitelist: Vector{String} listing which properties to include for per-point export (default small set).
- sample_rate: keep every N-th point when exporting per-point properties.
- max_points_per_file: cap points per-file for per-point exports.
Returns path to created index.html.
"""
function plot_property_graph(graph, all_gps_data; out_dir::String = "./example_data/all_plots/leaflet_viewer",
                             simplify_tolerance_m::Float64 = 0.0,
                             quantize_decimals::Int = 5, min_points::Int = 2,
                             export_point_properties::Bool = false,
                             properties_whitelist::Union{Nothing, Vector{String}} = nothing,
                             sample_rate::Int = 1,
                             max_points_per_file::Int = 10000)

    mkpath(out_dir)
    geo_dir = joinpath(out_dir, "geojson")
    mkpath(geo_dir)

    grouped = Dict{String, Vector{Tuple{Float64,Float64}}}()
    grouped_indices = Dict{String, Vector{Int}}()
    vertex_indices = sort(collect(keys(all_gps_data)))
    for idx in vertex_indices
        pt = all_gps_data[idx]
        if !haskey(pt, "latitude") || !haskey(pt, "longitude")
            continue
        end
        lat = pt["latitude"]
        lon = pt["longitude"]
        if lat === missing || lon === missing || !(isa(lat, Number) && isa(lon, Number))
            continue
        end
        fname = haskey(pt, "file_name") ? String(pt["file_name"]) : "unknown"
        push!(get!(grouped, fname, Vector{Tuple{Float64,Float64}}()), (lon, lat))
        push!(get!(grouped_indices, fname, Vector{Int}()), idx)
    end

    if isempty(grouped)
        error("No geospatial data found in all_gps_data.")
    end

    sanitize_filename(s::String) = replace(s, r"[^\w\.\-]" => "_")[1:min(end, 80)]

    function quantize_coord(coord::Tuple{Float64,Float64})
        return (round(coord[1], digits=quantize_decimals), round(coord[2], digits=quantize_decimals))
    end

    geo_files = Vector{Tuple{String,String}}()
    extent = (minlon=Inf, minlat=Inf, maxlon=-Inf, maxlat=-Inf)

    for (fname, coords) in grouped
        orig_coords = coords
        orig_indices = grouped_indices[fname]

        if simplify_tolerance_m > 0.0 && length(orig_coords) >= 2
            mean_lat = mean([c[2] for c in orig_coords])
            mean_lat_rad = deg2rad(mean_lat)
            scale_x = cos(mean_lat_rad) * 111000.0
            scale_y = 111000.0

            meter_points = [(c[1]*scale_x, c[2]*scale_y) for c in orig_coords]
            simplified_meters = douglas_peucker(meter_points, simplify_tolerance_m)

            simplified_coords = [(p[1]/scale_x, p[2]/scale_y) for p in simplified_meters]
            simplified_indices = Int[]
            for sp in simplified_meters
                idx = findfirst(p -> isapprox(p[1], sp[1]; atol=1e-3) && isapprox(p[2], sp[2]; atol=1e-3), meter_points)
                if isnothing(idx)
                    continue
                end
                push!(simplified_indices, orig_indices[idx])
            end
        else
            simplified_coords = orig_coords
            simplified_indices = orig_indices
        end

        if length(simplified_coords) < min_points
            continue
        end

        grouped_indices[fname] = simplified_indices
        qcoords = [quantize_coord(c) for c in simplified_coords]

        for (lon, lat) in qcoords
             extent = (minlon=min(extent.minlon, lon), minlat=min(extent.minlat, lat),
                       maxlon=max(extent.maxlon, lon), maxlat=max(extent.maxlat, lat))
        end

        feature = Dict(
            "type" => "Feature",
            "properties" => Dict("file_name" => fname, "num_points" => length(qcoords)),
            "geometry" => Dict("type" => "LineString", "coordinates" => [ [c[1], c[2]] for c in qcoords ])
        )
        fc = Dict("type" => "FeatureCollection", "features" => [feature])

        fname_safe = sanitize_filename(fname)
        geo_path = joinpath(geo_dir, "$(fname_safe).geojson")
        open(geo_path, "w") do io
            JSON.print(io, fc)
        end
        push!(geo_files, ( "$(fname_safe).geojson", fname ))
    end

    if isempty(geo_files)
        error("No geojson files written (all paths too short?).")
    end

    center_lon = (extent.minlon + extent.maxlon) / 2
    center_lat = (extent.minlat + extent.maxlat) / 2
    html_path = joinpath(out_dir, "index.html")

    html = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>TCX2Graph Leaflet Viewer</title>
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
      <style> html, body, #map { height: 100%; margin: 0; padding: 0; } </style>
    </head>
    <body>
      <div id="map"></div>
      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <script>
        const map = L.map('map').setView([$(center_lat), $(center_lon)], 13);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; OpenStreetMap contributors'
        }).addTo(map);

        function styleByIndex(i) {
            const colors = ['#1f77b4','#ff7f0e','#2ca02c','#d62728','#9467bd','#8c564b','#e377c2','#7f7f7f','#bcbd22','#17becf'];
            return { color: colors[i % colors.length], weight: 3, opacity: 0.8 };
        }
    """

    for (i, (fname, orig)) in enumerate(geo_files)
        js_orig = replace(orig, "'" => "\\'")
        html *= """
        fetch('geojson/$(fname)')
         .then(r => r.json())
         .then(data => {
            const layer = L.geoJSON(data, {
                style: () => styleByIndex($(i)),
                onEachFeature: function (feature, layer) {
                    const props = feature.properties || {};
                    const info = 'File: ' + (props.file_name || '$(js_orig)') + '<br>Points: ' + (props.num_points || '');
                    layer.bindPopup(info);
                }
            }).addTo(map);
        }).catch(e => console.warn('Failed to load geojson $(fname)', e));
        """
    end

    html *= """
      </script>
    </body>
    </html>
    """

    open(html_path, "w") do io
        write(io, html)
    end

    if export_point_properties
        default_whitelist = ["time","altitude","distance","heart_rate","cadence","speed","watts","file_name"]
        props_whitelist = properties_whitelist === nothing ? default_whitelist : properties_whitelist

        points_index = Vector{Dict{String,Any}}()

        for (fname, idxs) in grouped_indices
            sampled_idxs = idxs[1:sample_rate:end]
            if length(sampled_idxs) > max_points_per_file
                keep = Int(max_points_per_file)
                step = max(1, Int(ceil(length(sampled_idxs) / keep)))
                sampled_idxs = sampled_idxs[1:step:end][1:keep]
            end

            features = Vector{Any}()

            minlon = Inf; minlat = Inf; maxlon = -Inf; maxlat = -Inf

            for v_idx in sampled_idxs
                tp = all_gps_data[v_idx]
                if tp["latitude"] === missing || tp["longitude"] === missing continue end
                props = Dict{String, Any}()
                for k in props_whitelist
                    if haskey(tp, k)
                        props[k] = tp[k]
                    end
                end
                props["vertex_index"] = v_idx

                lon = tp["longitude"]; lat = tp["latitude"]
                minlon = min(minlon, lon); minlat = min(minlat, lat)
                maxlon = max(maxlon, lon); maxlat = max(maxlat, lat)

                push!(features, Dict(
                    "type" => "Feature",
                    "properties" => props,
                    "geometry" => Dict("type" => "Point", "coordinates" => [ lon, lat ])
                ))
            end

            if isempty(features)
                continue
            end

            fc = Dict("type" => "FeatureCollection", "features" => features)
            fname_safe = replace(fname, r"[^\w\.\-]" => "_")[1:min(end,80)]
            points_path = joinpath(geo_dir, "$(fname_safe)_points.geojson")
            open(points_path, "w") do io
                JSON.print(io, fc)
            end

            push!(points_index, Dict(
                "points_file" => "$(fname_safe)_points.geojson",
                "file_name" => fname,
                "bbox" => [minlon, minlat, maxlon, maxlat],
                "num_points" => length(features)
            ))
        end

        index_path = joinpath(geo_dir, "points_index.json")
        open(index_path, "w") do io
            JSON.print(io, points_index)
        end

        println("Wrote per-point geojson files (sample_rate=$(sample_rate), max_per_file=$(max_points_per_file)) to: $geo_dir")
        println("Wrote points index: $index_path")
    end

    html *= """
      <script>
        // Lazy-load per-point GeoJSONs only at high zoom and only for files overlapping the current map view.
        const geoDir = 'geojson/';
        const POINTS_INDEX_URL = geoDir + 'points_index.json';
        const POINTS_MIN_ZOOM = 16; // only start loading points at or above this zoom
        const loadedPointLayers = {}; // cache loaded layers by filename

        function bboxIntersects(bounds, bbox) {
            // bounds: Leaflet LatLngBounds; bbox: [minlon,minlat,maxlon,maxlat]
            const [minlon, minlat, maxlon, maxlat] = bbox;
            return !(maxlon < bounds.getWest() || minlon > bounds.getEast() || maxlat < bounds.getSouth() || minlat > bounds.getNorth());
        }

        function addPointGeoJSON(fileEntry, mapBounds) {
            const file = fileEntry.points_file;
            if (loadedPointLayers[file]) return; // already loaded

            fetch(geoDir + file)
              .then(r => r.json())
              .then(data => {
                // Filter features to current bounds (ensures on-screen features only)
                const layer = L.geoJSON(data, {
                  filter: function(feature) {
                    if (!feature || !feature.geometry || feature.geometry.type !== 'Point') return false;
                    const [lon, lat] = feature.geometry.coordinates;
                    return lat >= mapBounds.getSouth() && lat <= mapBounds.getNorth() &&
                           lon >= mapBounds.getWest() && lon <= mapBounds.getEast();
                  },
                  pointToLayer: function (feature, latlng) {
                    return L.circleMarker(latlng, {radius: 5, color: '#222', fillColor: '#fff', fillOpacity: 0.8, weight: 1});
                  },
                  onEachFeature: function (feature, layer) {
                    layer.on('click', function(e) {
                      const props = feature.properties || {};
                      let html = '<b>Trackpoint Metadata</b><br><table>';
                      for (const k in props) {
                        html += '<tr><td style="font-weight:bold;">' + k + '</td><td>' + props[k] + '</td></tr>';
                      }
                      html += '</table>';
                      layer.bindPopup(html).openPopup();
                    });
                  }
                }).addTo(map);
                loadedPointLayers[file] = layer;
              })
              .catch(e => {
                // ignore missing or failed fetches
                console.warn('Failed to load point file', file, e);
              });
        }

        function removeAllPointLayers() {
            for (const f in loadedPointLayers) {
                try { map.removeLayer(loadedPointLayers[f]); } catch(e) {}
            }
            for (const f in loadedPointLayers) delete loadedPointLayers[f];
        }

        // Decide which point files to load given current zoom and bounds
        function updateVisiblePointFiles(pointsIndex) {
            const zoom = map.getZoom();
            if (zoom < POINTS_MIN_ZOOM) {
                // remove all if zoomed out
                removeAllPointLayers();
                return;
            }
            const bounds = map.getBounds();

            // Load only entries whose bbox intersects current view
            for (const entry of pointsIndex) {
                if (bboxIntersects(bounds, entry.bbox)) {
                    addPointGeoJSON(entry, bounds);
                } else {
                    // if previously loaded but now out of view, remove it to save memory
                    const fname = entry.points_file;
                    if (loadedPointLayers[fname]) {
                        try { map.removeLayer(loadedPointLayers[fname]); } catch(e) {}
                        delete loadedPointLayers[fname];
                    }
                }
            }
        }

        // Fetch the points index once, then react to map events
        fetch(POINTS_INDEX_URL)
          .then(r => r.json())
          .then(pointsIndex => {
            // Initial attempt
            updateVisiblePointFiles(pointsIndex);
            // Update on view changes
            map.on('moveend zoomend', () => updateVisiblePointFiles(pointsIndex));
        }).catch(e => {
            console.warn('Failed to load points index', e);
        });
      </script>
    """

    html *= """
      </script>
    </body>
    </html>
    """

    open(html_path, "w") do io
        write(io, html)
    end

    println("Wrote $(length(geo_files)) geojson files.")

    return html_path
end
