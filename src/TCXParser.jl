using TCXReader
using Overpass
using JSON

# Set your Overpass endpoint to your local instance
Overpass.set_endpoint("http://localhost:12345/api/interpreter")

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
                        "latitude" => trackpoint.latitude,
                        "longitude" => trackpoint.longitude,
                        "time" => trackpoint.time,
                        "altitude" => get_or_missing(trackpoint.altitude_meters),
                        "distance" => get_or_missing(trackpoint.distance_meters),
                        "heart_rate" => get_or_missing(trackpoint.heart_rate_bpm),
                        "cadence" => get_or_missing(trackpoint.cadence),
                        "speed" => get_or_missing(trackpoint.speed),
                        "watts" => get_or_missing(trackpoint.watts)
                    )
                    push!(trackpoints, properties)
                end
            end
        end
    end

    if add_features
        add_surface_info!(trackpoints)
    else
        for tp in trackpoints
            tp["surface"] = missing
        end
    end

    # Print enriched trackpoints (first 5 for brevity)
    println("First 5 enriched trackpoints:")
    for tp in trackpoints[1:min(5, length(trackpoints))]
        println(tp)
    end

    return trackpoints
end

function get_or_missing(value)
    isnothing(value) ? missing : value
end

"""
    add_surface_info!(trackpoints::Vector{Dict{String, Any}})

Adds surface information to trackpoints using Overpass API queries.
"""
function add_surface_info!(trackpoints::Vector{Dict{String, Any}})
    # Create a single polyline for all trackpoints
    polyline = create_proper_polyline(trackpoints)

    # Query Overpass for all trackpoints
    overpass_result = query_overpass_polyline(polyline)

    # Assign surfaces to trackpoints
    assign_surfaces!(trackpoints, overpass_result)
end

"""
    create_proper_polyline(trackpoints::Vector{Dict{String, Any}}) -> String

Creates a properly formatted polyline string for Overpass API from trackpoints.
"""
function create_proper_polyline(trackpoints::Vector{Dict{String, Any}})::String
    # Format as: lat1 lon1 lat2 lon2 ...
    coords = [(tp["latitude"], tp["longitude"]) for tp in trackpoints]

    # Ensure at least three points to form a valid polygon
    if length(coords) < 3
        error("Overpass requires at least three distinct points to form a valid polygon.")
    end

    # Join points into a poly string
    return join(["$(lat) $(lon)" for (lat, lon) in coords], " ")
end

"""
    query_overpass_polyline(polyline::String) -> Vector{Any}

Queries the Overpass API with the given polyline and returns the result.
"""
function query_overpass_polyline(polyline::String)
    try
        query = """
        [out:json];
        (
            way["highway"](poly:"$polyline");
        );
        out geom;
        """
        #println("Generated Overpass Query:\n$query")
        response = Overpass.query(query)
        parsed_response = JSON.parse(response)
        return parsed_response["elements"]
    catch e
        println("Error querying Overpass: $e")
        return []
    end
end

"""
    assign_surfaces!(trackpoints::Vector{Dict{String, Any}}, overpass_result::Vector{Any})

Assigns surface types from Overpass results to trackpoints.
"""
function assign_surfaces!(trackpoints::Vector{Dict{String, Any}}, overpass_result::Vector{Any})
    for tp in trackpoints
        lat, lon = tp["latitude"], tp["longitude"]
        tp["surface"] = find_closest_surface(lat, lon, overpass_result)
    end
end

"""
    find_closest_surface(lat::Float64, lon::Float64, elements::Vector{Any}) -> Union{String, Missing}

Finds the closest surface tag in Overpass results to the given coordinates.
"""
function find_closest_surface(lat::Float64, lon::Float64, elements::Vector{Any})::Union{String, Missing}
    closest_surface = missing
    closest_distance = Inf

    for element in elements
        if haskey(element, "tags") && haskey(element["tags"], "surface")
            # Try "bounds" first
            if haskey(element, "bounds")
                bbox = element["bounds"]
                distance = haversine_distance(lat, lon, bbox["minlat"], bbox["minlon"])
                if distance < closest_distance
                    closest_distance = distance
                    closest_surface = element["tags"]["surface"]
                end
            elseif haskey(element, "geometry")
                # Use geometry nodes if available
                for node in element["geometry"]
                    node_distance = haversine_distance(lat, lon, node["lat"], node["lon"])
                    if node_distance < closest_distance
                        closest_distance = node_distance
                        closest_surface = element["tags"]["surface"]
                    end
                end
            else
                println("No usable geometry for element: ", element)
            end
        end
    end

    return closest_surface
end