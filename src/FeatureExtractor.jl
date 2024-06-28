# FeatureExtractor.jl
# This file provides functions to find overlapping GPS points and extract features
# from GPS data.

using Statistics

"""
    find_overlapping_points(gps_data::Dict{Int, Dict{String, Any}}) -> Keys{Dict{Tuple{Float64, Float64}, Int}}

Find GPS points that overlap (i.e., have the same coordinates up to a precision of 5 decimal places)
and return their coordinates.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data where the key is an integer identifier and the value is a dictionary of properties.

# Returns
- A set of tuples containing the coordinates of overlapping points.
"""
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

"""
    extract_features(gps_data::Dict{Int, Dict{String, Any}}, overlapping_points::Base.KeySet{Tuple{Float64, Float64}, Dict{Tuple{Float64, Float64}, Int}}) -> Vector{Dict{String, Any}}

Extract features such as average speed, heart rate, altitude, and distance for the overlapping GPS points.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data where the key is an integer identifier and the value is a dictionary of properties.
- `overlapping_points::Base.KeySet{Tuple{Float64, Float64}, Dict{Tuple{Float64, Float64}, Int}}`: A set of tuples containing the coordinates of overlapping points.

# Returns
- A vector of dictionaries, each containing the coordinates and average properties (speed, heart rate, altitude, distance) of the overlapping points.
"""
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
