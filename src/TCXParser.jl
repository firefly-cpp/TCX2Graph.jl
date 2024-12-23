using TCXReader
using Overpass
using JSON

# Set your Overpass endpoint to your local instance
Overpass.set_endpoint("http://localhost:12345/api/interpreter")

"""
    read_tcx_gps_points(tcx_file_path::String, add_features::Bool, batch_size::Int) -> Vector{Dict{String, Any}}

Reads GPS trackpoints from a TCX file and extracts additional properties such as time, altitude, distance, heart rate, cadence, speed, and power (watts).
Optionally queries Overpass for additional road surface information in batches.

# Arguments
- `tcx_file_path::String`: The file path to the TCX file to be processed.
- `add_features::Bool`: Whether to query Overpass for additional features (road surface).
- `batch_size::Int`: Number of trackpoints to group into a batch for surface queries.

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
function read_tcx_gps_points(tcx_file_path::String, add_features::Bool, batch_size::Int)
    author, activities = TCXReader.loadTCXFile(tcx_file_path)
    trackpoints = Vector{Dict{String, Any}}()

    for activity in activities
        for lap in activity.laps
            for trackpoint in lap.trackPoints
                if !isnothing(trackpoint.latitude) && !isnothing(trackpoint.longitude)
                    properties = Dict(
                        "latitude" => trackpoint.latitude,
                        "longitude" => trackpoint.longitude,
                        "time" => trackpoint.time
                    )

                    if !isnothing(trackpoint.altitude_meters)
                        properties["altitude"] = trackpoint.altitude_meters
                    else
                        properties["altitude"] = missing
                    end
                    if !isnothing(trackpoint.distance_meters)
                        properties["distance"] = trackpoint.distance_meters
                    else
                        properties["distance"] = missing
                    end
                    if !isnothing(trackpoint.heart_rate_bpm)
                        properties["heart_rate"] = trackpoint.heart_rate_bpm
                    else
                        properties["heart_rate"] = missing
                    end
                    if !isnothing(trackpoint.cadence)
                        properties["cadence"] = trackpoint.cadence
                    else
                        properties["cadence"] = missing
                    end
                    if !isnothing(trackpoint.speed)
                        properties["speed"] = trackpoint.speed
                    else
                        properties["speed"] = missing
                    end
                    if !isnothing(trackpoint.watts)
                        properties["watts"] = trackpoint.watts
                    else
                        properties["watts"] = missing
                    end

                    push!(trackpoints, properties)
                end
            end
        end
    end

    if add_features
        # Process trackpoints in batches
        for i in 1:batch_size:length(trackpoints)
            batch = trackpoints[i:min(i + batch_size - 1, length(trackpoints))]
            surface = get_surface_for_batch(batch)

            for tp in batch
                tp["surface"] = surface
            end
        end
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

# Function to get the surface for a batch of trackpoints
function get_surface_for_batch(batch::Vector{Dict{String, Any}})::Union{String, Missing}
    for tp in batch
        lat, lon = tp["latitude"], tp["longitude"]
        surface = get_road_surface(lat, lon)
        if surface !== missing
            return surface
        end
    end
    return missing  # If no surface is found for the batch
end

function get_road_surface(lat::Float64, lon::Float64)::Union{String, Missing}
    try
        query = """
        [out:json];
        way["highway"](around:10, $lat, $lon);
        out tags;
        """
        response = Overpass.query(query)

        # Parse the JSON response
        parsed_response = JSON.parse(response)

        if !isempty(parsed_response["elements"])
            for element in parsed_response["elements"]
                if haskey(element, "tags") && haskey(element["tags"], "surface")
                    return element["tags"]["surface"]
                end
            end
        end
        return missing
    catch e
        println("Error querying Overpass for ($lat, $lon): $e")
        return missing
    end
end
