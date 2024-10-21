using TCXReader

"""
    read_tcx_gps_points(tcx_file_path::String) -> Vector{Dict{String, Any}}

Reads GPS trackpoints from a TCX file and extracts additional properties such as time, altitude, distance, heart rate, cadence, speed, and power (watts).

# Arguments
- `tcx_file_path::String`: The file path to the TCX file to be processed.

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

# Details
This function processes the given TCX file by extracting relevant data from each GPS trackpoint. If specific properties (such as altitude, heart rate, or power) are not available for a given trackpoint, they are marked as `missing`. The result is a vector of dictionaries, where each dictionary represents a single trackpoint with its associated properties.

The function ignores trackpoints that do not have both latitude and longitude values, ensuring that only valid GPS points are included in the output.
"""
function read_tcx_gps_points(tcx_file_path::String)
    author, activities = TCXReader.loadTCXFile(tcx_file_path)
    trackpoints = []

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

    return trackpoints
end
