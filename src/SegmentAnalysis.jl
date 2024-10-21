"""
    compute_segment_characteristics(segment_idx::Int, gps_data::Dict{Int, Dict{String, Any}},
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
function compute_segment_characteristics(segment_idx, gps_data, overlapping_segments)
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