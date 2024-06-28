using Statistics

function find_overlapping_points(gps_data::Dict{Int, Dict{String, Any}})
    point_counts = Dict{Tuple{Float64, Float64}, Int}()
    for (_, properties) in gps_data
        coord = (round_coord(properties["latitude"], 5), round_coord(properties["longitude"], 5))
        if haskey(point_counts, coord)
            point_counts[coord] += 1
        else
            point_counts[coord] = 1
        end
    end

    overlapping_points = filter(x -> x[2] > 1, point_counts)
    return keys(overlapping_points)
end

function extract_features(gps_data::Dict{Int, Dict{String, Any}}, overlapping_points::Base.KeySet{Tuple{Float64, Float64}, Dict{Tuple{Float64, Float64}, Int}})
    features = []

    for coord in overlapping_points
        points = filter(x -> round_coord(gps_data[x]["latitude"], 5) == coord[1] && round_coord(gps_data[x]["longitude"], 5) == coord[2], keys(gps_data))

        # Extract valid values for each property, filtering out missing values
        speeds = [gps_data[p]["speed"] for p in points if gps_data[p]["speed"] !== missing]
        heart_rates = [gps_data[p]["heart_rate"] for p in points if gps_data[p]["heart_rate"] !== missing]
        altitudes = [gps_data[p]["altitude"] for p in points if gps_data[p]["altitude"] !== missing]
        distances = [gps_data[p]["distance"] for p in points if gps_data[p]["distance"] !== missing]

        # Calculate averages, set to missing if no valid values
        avg_speed = isempty(speeds) ? missing : mean(speeds)
        avg_heart_rate = isempty(heart_rates) ? missing : mean(heart_rates)
        avg_altitude = isempty(altitudes) ? missing : mean(altitudes)
        avg_distance = isempty(distances) ? missing : mean(distances)

        # Store the features in a dictionary
        push!(features, Dict(
            "latitude" => coord[1],
            "longitude" => coord[2],
            "avg_speed" => avg_speed,
            "avg_heart_rate" => avg_heart_rate,
            "avg_altitude" => avg_altitude,
            "avg_distance" => avg_distance
        ))
    end

    return features
end
