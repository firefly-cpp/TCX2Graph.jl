using TCXReader
using Overpass
using JSON
using Dates
using HTTP

export read_tcx_gps_points, create_proper_polyline, query_overpass_polyline, assign_road_features!, find_closest_road_features

# Set your Overpass endpoint to your local instance
# Overpass.set_endpoint("http://100.109.162.39:12345/api/")
Overpass.set_endpoint("https://overpass-api.de/api/")

"""
    read_tcx_gps_points(tcx_file_path::String, add_features::Bool) -> Vector{Dict{String, Any}}

Reads GPS trackpoints from a TCX file and extracts additional properties such as time, altitude, distance, heart rate, cadence, speed, and power (watts).
Optionally queries Overpass for additional road surface information in batches.

# Arguments
- `tcx_file_path::String`: The file path to the TCX file to be processed.
- `add_features::Bool`: Whether to query Overpass for additional features (road surface).

# Returns
- `Vector{Dict{String, Any}}`: A vector of dictionaries, where each dictionary represents a GPS trackpoint and contains the following properties:
    - `latitude`: Latitude of the GPS point.
    - `longitude`: Longitude of the GPS point.
    - `time`: Timestamp of the trackpoint.
    - `altitude`: Altitude in meters (if available, otherwise `missing`).
    - `distance`: Distance in meters (if available, otherwise `missing`).
    - `heart_rate`: Heart rate in beats per minute (if available, otherwise `missing`).
    - `cadence`: Cadence in revolutions per minute (if available, otherwise `missing`).
    - `speed`: Speed in meters per second (if available, otherwise `missing`).
    - `watts`: Power output in watts (if available, otherwise `missing`).
    - `surface`: The type of surface (if queried from Overpass, otherwise `missing`).
    - `smoothness`: The smoothness of the surface (if queried from Overpass, otherwise `missing`).
    - `width`: The width of the road (if queried from Overpass, otherwise `missing`).
    - `lit`: Whether the road is lit (if queried from Overpass, otherwise `missing`).
    - `maxspeed`: The maximum speed limit (if queried from Overpass, otherwise `missing`).
    - `incline`: The incline of the road (if queried from Overpass, otherwise `missing`).
    - `barrier`: The type of barrier on the road (if queried from Overpass, otherwise `missing`).
    - `crossing`: The type of crossing on the road (if queried from Overpass, otherwise `missing`).
    - `landuse`: The land use type (if queried from Overpass, otherwise `missing`).
    - `lane_markings`: The type of lane markings (if queried from Overpass, otherwise `missing`).

# Details
This function processes the given TCX file by extracting relevant data from each GPS trackpoint. If specific properties (such as altitude, heart rate, or power) are not available for a given trackpoint, they are marked as `missing`. The result is a vector of dictionaries, where each dictionary represents a single trackpoint with its associated properties.

The function groups trackpoints into batches for querying the Overpass API. If none of the trackpoints in a batch have a `surface` feature, the batch is marked as `missing` for `surface`.
"""
function read_tcx_gps_points(tcx_file_path::String, add_features::Bool)
    author, activities = TCXReader.loadTCXFile(tcx_file_path)
    trackpoints = Vector{Dict{String, Any}}()

    # Extract trackpoints
    for activity in activities
        for lap in activity.laps
            for trackpoint in lap.trackPoints
                if !isnothing(trackpoint.latitude) && !isnothing(trackpoint.longitude)
                    properties = Dict(
                        "latitude" => get_or_missing(trackpoint.latitude),
                        "longitude" => get_or_missing(trackpoint.longitude),
                        "time" => trackpoint.time,
                        "altitude" => get_or_missing(trackpoint.altitude_meters),
                        "distance" => get_or_missing(trackpoint.distance_meters),
                        "heart_rate" => get_or_missing(trackpoint.heart_rate_bpm),
                        "cadence" => get_or_missing(trackpoint.cadence),
                        "speed" => get_or_missing(trackpoint.speed),
                        "watts" => get_or_missing(trackpoint.watts),
                        "file_name" => basename(tcx_file_path)
                    )
                    push!(trackpoints, properties)
                end
            end
        end
    end

    polyline = create_proper_polyline(trackpoints)
    if isnothing(polyline)
        println("Skipping TCX file $tcx_file_path: No valid GPS points.")
        return nothing  # Return an empty array to signal skipping this file
    end

    if add_features
        assign_road_features!(trackpoints, query_overpass_polyline(polyline))
        enrich_with_weather!(trackpoints)
    else
        for tp in trackpoints
          tp["highway"] = missing
          tp["cycleway"] = missing
          tp["bicycle"] = missing
          tp["surface"] = missing
          tp["smoothness"] = missing
          tp["width"] = missing
          tp["lit"] = missing
          tp["maxspeed"] = missing
          tp["incline"] = missing
          tp["barrier"] = missing
          tp["crossing"] = missing
          tp["landuse"] = missing
          tp["lane_markings"] = missing
        end
    end

    # Print enriched trackpoints (first 5 for brevity)
    #= println("First 5 enriched trackpoints:")
    for tp in trackpoints[1:min(5, length(trackpoints))]
        println(tp)
    end =#

    # Print just first 1 trackpoint
    println("First trackpoint:")
    println(trackpoints[1])

    return trackpoints
end

function get_or_missing(value)
    isnothing(value) ? missing : value
end

"""
    create_proper_polyline(trackpoints::Vector{Dict{String, Any}}, epsilon::Float64 = 0.0001) -> String

Creates a proper polyline from trackpoints and simplifies it using the Douglas-Peucker algorithm.

# Arguments
- `trackpoints::Vector{Dict{String, Any}}`: A vector of trackpoints.
- `epsilon::Float64`: The epsilon value for the Douglas-Peucker algorithm.

# Returns
- `String`: A string representation of the simplified polyline.
"""
function create_proper_polyline(trackpoints::Vector{Dict{String, Any}}, epsilon::Float64 = 0.001)::String

    coords = [(tp["latitude"], tp["longitude"]) for tp in trackpoints
                  if !(ismissing(tp["latitude"]) || ismissing(tp["longitude"]))]

    if length(coords) < 2
        println("Skipping TCX file: Not enough valid coordinates for Douglas-Peucker simplification.")
        return ""
    end

    simplified_coords = douglas_peucker(coords, epsilon)

    return join(["$(lat) $(lon)" for (lat, lon) in simplified_coords], " ")
end

"""
    query_overpass_polyline(polyline::String) -> Vector{Any}

Queries the Overpass API with the given polyline and returns the result.
"""
function query_overpass_polyline(polyline::String)
    try
        query = """
        [out:json][timeout:90];
        (
            way["highway"](poly:"$polyline");
            way["cycleway"](poly:"$polyline");
            way["bicycle"](poly:"$polyline");
            way["surface"](poly:"$polyline");
            way["smoothness"](poly:"$polyline");
            way["width"](poly:"$polyline");
            way["lit"](poly:"$polyline");
            way["maxspeed"](poly:"$polyline");
            way["incline"](poly:"$polyline");
            way["barrier"](poly:"$polyline");
            way["crossing"](poly:"$polyline");
            way["landuse"](poly:"$polyline");
            way["lane_markings"](poly:"$polyline");
        );
        out geom;
        """
        response = Overpass.query(query)
        parsed_response = JSON.parse(response)
        return parsed_response["elements"]
    catch e
        println("Error querying Overpass: $e")
        return []
    end
end

"""
    assign_road_features!(trackpoints::Vector{Dict{String, Any}}, overpass_result::Vector{Any})

Assigns road features from the Overpass result to the trackpoints.
"""
function assign_road_features!(trackpoints::Vector{Dict{String, Any}}, overpass_result::Vector{Any})
    for tp in trackpoints

        if ismissing(tp["latitude"]) || ismissing(tp["longitude"])
            continue
        end

        lat, lon = tp["latitude"], tp["longitude"]

        closest_features = find_closest_road_features(lat, lon, overpass_result)

        for key in keys(closest_features)
            tp[key] = closest_features[key]
        end
    end
end

"""
    find_closest_road_features(lat::Float64, lon::Float64, elements::Vector{Any})::Dict{String, Union{String, Missing}}

Finds the closest road features to a given latitude and longitude from a list of Overpass elements.

# Arguments
- `lat::Float64`: The latitude of the point.
- `lon::Float64`: The longitude of the point.
- `elements::Vector{Any}`: A list of Overpass elements containing road features.

# Returns
- `Dict{String, Union{String, Missing}}`: A dictionary containing the closest road features to the given point.
"""
function find_closest_road_features(lat::Float64, lon::Float64, elements::Vector{Any})::Dict{String, Union{String, Missing, Float64}}
    closest_features = Dict{String, Union{String, Missing, Float64}}(
        "highway" => missing,
        "cycleway" => missing,
        "bicycle" => missing,
        "surface" => missing,
        "smoothness" => missing,
        "width" => missing,
        "lit" => missing,
        "maxspeed" => missing,
        "incline" => missing,
        "barrier" => missing,
        "crossing" => missing,
        "landuse" => missing,
        "lane_markings" => missing
    )
    closest_distance = Inf

    for element in elements
        if haskey(element, "tags") && haskey(element, "geometry")
            for node in element["geometry"]
                node_distance = haversine_distance(lat, lon, node["lat"], node["lon"])

                if node_distance < closest_distance
                    closest_distance = node_distance

                    for key in keys(closest_features)
                        if haskey(element["tags"], key)
                            value = element["tags"][key]

                            if key in ["width", "maxspeed", "incline"]
                                try
                                    closest_features[key] = parse(Float64, value)
                                catch
                                    closest_features[key] = value
                                end
                            else
                                closest_features[key] = value
                            end
                        end
                    end
                end
            end
        end
    end

    return closest_features
end

const weather_cache = Dict{Tuple{Float64, Float64, DateTime}, Dict{String, Any}}()
const WEATHER_GRID_RESOLUTION = 0.25

round_coord(value::Float64, res::Float64=WEATHER_GRID_RESOLUTION) = round(value / res) * res

function fetch_weather(lat::Float64, lon::Float64, dt::DateTime)
    lat_r = round_coord(lat)
    lon_r = round_coord(lon)
    dt_hour = DateTime(year(dt), month(dt), day(dt), hour(dt))
    cache_key = (lat_r, lon_r, dt_hour)
    if haskey(weather_cache, cache_key)
        return weather_cache[cache_key]
    end
    date_str = Dates.format(dt_hour, "yyyy-mm-dd")
    url = "https://archive-api.open-meteo.com/v1/archive?" *
        "latitude=$(lat_r)&longitude=$(lon_r)" *
        "&start_date=$(date_str)&end_date=$(date_str)" *
        "&hourly=temperature_2m,precipitation,windspeed_10m,winddirection_10m," *
        "relative_humidity_2m,cloudcover,weathercode,pressure_msl,dewpoint_2m," *
        "uv_index,uv_index_clear_sky,snowfall,snow_depth,shortwave_radiation," *
        "direct_radiation,diffuse_radiation,evapotranspiration,et0_fao_evapotranspiration"
    data = Dict{String,Any}()
    try
        r = HTTP.get(url)
        data = JSON.parse(String(r.body))
    catch e
        println("Weather request failed: $e")
        data["hourly"] = Dict{String,Any}("time" => String[])
    end
    times = haskey(data, "hourly") && haskey(data["hourly"], "time") ?
                DateTime.(data["hourly"]["time"]) : DateTime[]
    idx = findfirst(==(dt_hour), times)
    keys = [
        "temperature_2m", "precipitation", "windspeed_10m", "winddirection_10m",
        "relative_humidity_2m", "cloudcover", "weathercode", "pressure_msl",
        "dewpoint_2m", "uv_index", "uv_index_clear_sky", "snowfall", "snow_depth",
        "shortwave_radiation", "direct_radiation", "diffuse_radiation",
        "evapotranspiration", "et0_fao_evapotranspiration"
    ]
    weather = Dict{String, Any}()
    if isnothing(idx)
        for k in keys
            weather[k] = missing
        end
    else
        for k in keys
            weather[k] = haskey(data["hourly"], k) ? data["hourly"][k][idx] : missing
        end
    end
    weather_cache[cache_key] = weather
    return weather
end

function enrich_with_weather!(trackpoints::Vector{Dict{String, Any}})
    for tp in trackpoints
        if ismissing(tp["latitude"]) || ismissing(tp["longitude"]) || ismissing(tp["time"])
            for k in [
                "temperature_2m", "precipitation", "windspeed_10m", "winddirection_10m",
                "relative_humidity_2m", "cloudcover", "weathercode", "pressure_msl",
                "dewpoint_2m", "uv_index", "uv_index_clear_sky", "snowfall", "snow_depth",
                "shortwave_radiation", "direct_radiation", "diffuse_radiation",
                "evapotranspiration", "et0_fao_evapotranspiration"
            ]
                tp[k] = missing
            end
            continue
        end
        lat = tp["latitude"]
        lon = tp["longitude"]
        # Parse time to DateTime
        dt = tp["time"] isa DateTime ? tp["time"] : tryparse(DateTime, tp["time"])
        if isnothing(dt)
            for k in [
                "temperature_2m", "precipitation", "windspeed_10m", "winddirection_10m",
                "relative_humidity_2m", "cloudcover", "weathercode", "pressure_msl",
                "dewpoint_2m", "uv_index", "uv_index_clear_sky", "snowfall", "snow_depth",
                "shortwave_radiation", "direct_radiation", "diffuse_radiation",
                "evapotranspiration", "et0_fao_evapotranspiration"
            ]
                tp[k] = missing
            end
            continue
        end
        weather = fetch_weather(lat, lon, dt)
        for (k, v) in weather
            tp[k] = v
        end
    end
end