# FeatureExtractor.jl
# This file provides functions to extract and prepare raw features from GPS data,
# focusing on overlapping segments identified via KD-tree, and ready them for ARM.
using Statistics

"""
    extract_segment_data_for_arm(gps_data::Dict{Int, Dict{String, Any}},
                                 overlapping_segments::Vector{Tuple{Int, Int}},
                                 paths::Vector{UnitRange{Int}}) -> Vector{Vector{Dict{String, Any}}}

Extract raw data from overlapping GPS segments across multiple TCX files and prepare it for ARM.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data where the key is an integer identifier and the value is a dictionary of properties.
- `overlapping_segments::Vector{Tuple{Int, Int}}`: A vector of tuples, each representing an overlapping segment between two paths.
- `paths::Vector{UnitRange{Int}}`: A vector of ranges representing the indices of vertices for each TCX file.

# Returns
- A vector where each element corresponds to an overlapping segment and contains a list of transactions (dictionaries) from different TCX files.
"""
function extract_segment_data_for_arm(
    gps_data::Dict{Int, Dict{String, Any}},
    overlapping_segments::Vector{Tuple{Int, Int}},
    paths::Vector{UnitRange{Int}}
) :: Vector{Vector{Dict{String, Any}}}

    transactions_per_segment = []

    for (start_idx, end_idx) in overlapping_segments
        segment_transactions = []

        for (file_idx, path) in enumerate(paths)
            # Get all points within the overlapping segment for the current path
            segment_points = [p for p in path if start_idx <= p <= end_idx]

            if !isempty(segment_points)
                # Create a transaction for this path in this segment
                transaction = Dict{String, Any}()

                # Collect data for each point in the segment
                speeds = Float64[]
                altitudes = Float64[]
                heart_rates = Float64[]
                distances = Float64[]
                cadences = Float64[]
                watts = Float64[]

                for p in segment_points
                    point = gps_data[p]
                    if haskey(point, "speed") && point["speed"] !== missing
                        push!(speeds, point["speed"])
                    end
                    if haskey(point, "altitude") && point["altitude"] !== missing
                        push!(altitudes, point["altitude"])
                    end
                    if haskey(point, "heart_rate") && point["heart_rate"] !== missing
                        push!(heart_rates, point["heart_rate"])
                    end
                    if haskey(point, "distance") && point["distance"] !== missing
                        push!(distances, point["distance"])
                    end
                    if haskey(point, "cadence") && point["cadence"] !== missing
                        push!(cadences, point["cadence"])
                    end
                    if haskey(point, "watts") && point["watts"] !== missing
                        push!(watts, point["watts"])
                    end
                end

                # Aggregate data for the transaction, only including non-empty data
                if !isempty(speeds)
                    transaction["avg_speed"] = mean(speeds)
                end
                if !isempty(altitudes)
                    transaction["avg_altitude"] = mean(altitudes)
                end
                if !isempty(heart_rates)
                    transaction["avg_heart_rate"] = mean(heart_rates)
                end
                if !isempty(distances)
                    transaction["total_distance"] = sum(distances)
                end
                if !isempty(cadences)
                    transaction["avg_cadence"] = mean(cadences)
                end
                if !isempty(watts)
                    transaction["avg_watts"] = mean(watts)
                end

                if !isempty(transaction)
                    transaction["start_latitude"] = gps_data[segment_points[1]]["latitude"]
                    transaction["start_longitude"] = gps_data[segment_points[1]]["longitude"]
                    transaction["end_latitude"] = gps_data[segment_points[end]]["latitude"]
                    transaction["end_longitude"] = gps_data[segment_points[end]]["longitude"]

                    push!(segment_transactions, transaction)
                end
            end
        end

        # Only add to result if we have transactions from multiple files
        if length(segment_transactions) > 1
            push!(transactions_per_segment, segment_transactions)
        end
    end

    return transactions_per_segment
end