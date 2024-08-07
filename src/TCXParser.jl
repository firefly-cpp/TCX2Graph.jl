# TCXParser.jl
# This file provides functions to parse TCX files and extract GPS points along with their properties.

using TCXReader

"""
    read_tcx_gps_points(tcx_file_path::String) -> Vector{Dict{String, Any}}

Read GPS points from a TCX file and extract additional properties such as time, altitude, distance, heart rate, and speed.

# Arguments
- `tcx_file_path::String`: The file path to the TCX file.

# Returns
- `Vector{Dict{String, Any}}`: A vector of dictionaries, each containing properties of a GPS trackpoint.
"""
function read_tcx_gps_points(tcx_file_path::String)
    author, activities = TCXReader.loadTCXFile(tcx_file_path)
    trackpoints = []

    # Extract GPS coordinates and additional properties from each activity, lap, and trackpoint
    for activity in activities
        for lap in activity.laps
            for trackpoint in lap.trackPoints
                if !isnothing(trackpoint.latitude) && !isnothing(trackpoint.longitude)
                    properties = Dict(
                        "latitude" => trackpoint.latitude,
                        "longitude" => trackpoint.longitude,
                        "time" => trackpoint.time
                    )

                    # Add optional properties if they exist
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
