using TCXReader

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
                    if !isnothing(trackpoint.speed)
                        properties["speed"] = trackpoint.speed
                    else
                        properties["speed"] = missing
                    end

                    push!(trackpoints, properties)
                end
            end
        end
    end

    return trackpoints
end