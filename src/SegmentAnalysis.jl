using Statistics

"""
    compute_segment_characteristics_basic(segment_idx::Int, gps_data::Dict{Int, Dict{String, Any}},
                                    overlapping_segments::Vector{Dict{String, Any}})
                                    -> Tuple{Float64, Float64, Float64, Float64, Float64, Float64}

Computes various characteristics for a given GPS segment, including total distance, ascent, descent, vertical meters, and gradients.

# Arguments
- `segment_idx::Int`: The index of the segment to analyze from the `overlapping_segments` vector.
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS trackpoints with properties like latitude, longitude, and altitude.
- `overlapping_segments::Vector{Dict{String, Any}}`: A vector of overlapping segments, where each segment is represented as a dictionary with start and end indices.

# Returns
- `Tuple{Float64, Float64, Float64, Float64, Float64, Float64}`: A tuple containing:
    - `total_distance`: The total distance of the segment in meters.
    - `total_ascent`: The total ascent (positive elevation change) in meters.
    - `total_descent`: The total descent (negative elevation change) in meters.
    - `total_vertical_meters`: The total vertical movement (both ascent and descent) in meters.
    - `max_gradient`: The maximum ascent gradient within the segment (elevation change over distance).
    - `avg_gradient`: The average ascent gradient over the segment, considering only ascent portions.

# Details
This function computes various metrics over a segment of GPS data defined by its start and end indices in `overlapping_segments`.
It calculates the distance between consecutive GPS points using the Haversine formula. If altitude data is available, it tracks
the ascent and descent, as well as calculates gradients (ascent per distance). The result is a tuple of characteristics
for the entire segment.
"""
function compute_segment_characteristics_basic(segment_idx, gps_data, overlapping_segments)
    segment = overlapping_segments[segment_idx]
    start_idx = segment["start_idx"]
    end_idx = segment["end_idx"]

    total_distance = 0.0
    total_ascent = 0.0
    total_descent = 0.0
    total_vertical_meters = 0.0
    ascent_gradient_sum = 0.0
    ascent_count = 0
    max_gradient = 0.0

    for idx in start_idx:end_idx-1
        point1 = gps_data[idx]
        point2 = gps_data[idx + 1]

        lat1, lon1 = point1["latitude"], point1["longitude"]
        lat2, lon2 = point2["latitude"], point2["longitude"]

        segment_distance = haversine_distance(lat1, lon1, lat2, lon2)
        total_distance += segment_distance

        if point1["altitude"] !== missing && point2["altitude"] !== missing
            altitude_change = point2["altitude"] - point1["altitude"]

            if altitude_change > 0
                gradient = altitude_change / segment_distance
                ascent_gradient_sum += gradient
                ascent_count += 1

                if gradient > max_gradient
                    max_gradient = gradient
                end

                total_ascent += altitude_change

            elseif altitude_change < 0
                total_descent += abs(altitude_change)
            end

            total_vertical_meters += abs(altitude_change)
        end
    end

    avg_gradient = ascent_count > 0 ? ascent_gradient_sum / ascent_count : 0.0

    return total_distance, total_ascent, total_descent, total_vertical_meters, max_gradient, avg_gradient
end

"""
    extract_segment_features(overlapping_segments::Vector{Dict{String, Any}}, gps_data::Dict{Int, Dict{String, Any}})
    -> Vector{Dict{String, Any}}

Extracts numerical features for all overlapping segments, including min, max, and average values for relevant GPS properties.

# Arguments
- `overlapping_segments::Vector{Dict{String, Any}}`: A vector of dictionaries, each representing an overlapping segment.
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary where keys are indices, and values are GPS data dictionaries.

# Returns
- `Vector{Dict{String, Any}}`: A vector of dictionaries, each containing the features for a segment.
"""
function extract_segment_features(overlapping_segments::Vector{Dict{String, Any}}, gps_data::Dict{Int, Dict{String, Any}})
    all_features = Vector{Dict{String, Any}}()

    for segment in overlapping_segments
        start_idx = segment["start_idx"]
        end_idx = segment["end_idx"]

        trackpoints = [gps_data[idx] for idx in start_idx:end_idx]

        features = Dict(
            "distance" => merge(get_feature_stats(trackpoints, "distance"), Dict("type" => "Numerical")),
            "altitude" => merge(get_feature_stats(trackpoints, "altitude"), Dict("type" => "Numerical")),
            "speed" => merge(get_feature_stats(trackpoints, "speed"), Dict("type" => "Numerical")),
            "heart_rate" => merge(get_feature_stats(trackpoints, "heart_rate"), Dict("type" => "Numerical")),
            "cadence" => merge(get_feature_stats(trackpoints, "cadence"), Dict("type" => "Numerical")),
            "watts" => merge(get_feature_stats(trackpoints, "watts"), Dict("type" => "Numerical"))
        )

        # Combine features with segment info
        push!(all_features, merge(Dict("start_idx" => start_idx, "end_idx" => end_idx), features))
    end

    return all_features
end

"""
    get_feature_stats(trackpoints::Vector{Dict{String, Any}}, feature_name::String) -> Dict{String, Any}

Calculates min, max, and average values for a specific feature from a set of trackpoints.

# Arguments
- `trackpoints::Vector{Dict{String, Any}}`: A vector of GPS trackpoints.
- `feature_name::String`: The name of the feature to analyze.

# Returns
- `Dict{String, Any}`: A dictionary containing min, max, and average values for the feature.
"""
function get_feature_stats(trackpoints::Vector{Dict{String, Any}}, feature_name::String)
    values = [point[feature_name] for point in trackpoints if haskey(point, feature_name) && point[feature_name] !== missing]

    if isempty(values)
        return Dict("min" => missing, "max" => missing, "avg" => missing)
    end

    return Dict(
        "min" => minimum(values),
        "max" => maximum(values),
        "avg" => mean(values)
    )
end

"""
    filter_features(features::Vector{Dict{String, Any}}) -> Vector{Dict{String, Any}}

Filters out individual features where any of their values (`avg`, `min`, `max`) are `missing`.

# Arguments
- `features::Vector{Dict{String, Any}}`: A vector of feature dictionaries.

# Returns
- `Vector{Dict{String, Any}}`: Filtered feature dictionaries without `missing` values for any feature.
"""
function filter_features(features::Vector{Dict{String, Any}})
    return [
        Dict(
            key => value for (key, value) in feature
            if key in ["start_idx", "end_idx"] || (isa(value, Dict) && all(v -> v !== missing, values(value)))
        )
        for feature in features
    ]
end







