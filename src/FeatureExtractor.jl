# FeatureExtractor.jl
# This file provides functions to extract and prepare raw features from GPS data,
# focusing on overlapping segments identified via KD-tree, and prepare them for ARM.

using Statistics

"""
    extract_segment_data_for_arm(gps_data::Dict{Int, Dict{String, Any}},
                                 overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}},
                                 paths::Vector{UnitRange{Int}}) -> Vector{Vector{Dict{String, Any}}}

Extract raw data from overlapping GPS segments across multiple TCX files and prepare it for ARM.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data where the key is a vertex identifier and the value is a dictionary of properties.
- `overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}}`: A vector of tuples, each containing start and end indices of overlapping segments.
- `paths::Vector{UnitRange{Int}}`: A vector of ranges representing the indices of vertices (GPS points) for each TCX file.

# Returns
- A vector of transactions where each GPS point is treated as an individual transaction.
"""
function extract_segment_data_for_arm(
    gps_data::Dict{Int, Dict{String, Any}},
    overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}},
    paths::Vector{UnitRange{Int}}
) :: Vector{Vector{Dict{String, Any}}}

    transactions_per_segment = []
    tolerance = 0.0001  # 11 meters in degrees of lat/lon

    # Iterate through the overlapping segments
    for ((start_idx1, start_idx2), (end_idx1, end_idx2)) in overlapping_segments
        segment_transactions = []

        # For each file (path), retrieve the points between the start and end indices
        for (file_idx, path) in enumerate(paths)
            segment_points = []

            # Get points from each path based on the start and end indices
            if file_idx == 1
                for p in path
                    if start_idx1 <= p <= end_idx1 && is_same_location(gps_data[p], gps_data[start_idx1], tolerance=tolerance)
                        push!(segment_points, p)
                    end
                end
            else
                for p in path
                    if start_idx2 <= p <= end_idx2 && is_same_location(gps_data[p], gps_data[start_idx2], tolerance=tolerance)
                        push!(segment_points, p)
                    end
                end
            end

            if !isempty(segment_points)
                for p in segment_points
                    point = gps_data[p]
                    transaction = Dict{String, Any}()

                    # Collect only non-missing data for each point
                    if haskey(point, "speed") && point["speed"] !== missing
                        transaction["speed"] = point["speed"]
                    end
                    if haskey(point, "altitude") && point["altitude"] !== missing
                        transaction["altitude"] = point["altitude"]
                    end
                    if haskey(point, "heart_rate") && point["heart_rate"] !== missing
                        transaction["heart_rate"] = point["heart_rate"]
                    end
                    if haskey(point, "distance") && point["distance"] !== missing
                        transaction["distance"] = point["distance"]
                    end
                    # Optional fields like cadence and watts are handled gracefully
                    if haskey(point, "cadence") && point["cadence"] !== missing
                        transaction["cadence"] = point["cadence"]
                    end
                    if haskey(point, "watts") && point["watts"] !== missing
                        transaction["watts"] = point["watts"]
                    end

                    # Add GPS coordinates to each transaction
                    transaction["latitude"] = point["latitude"]
                    transaction["longitude"] = point["longitude"]

                    # Only push the transaction if it contains at least one valid data point
                    if length(transaction) > 2  # Latitude and longitude are always included
                        push!(segment_transactions, transaction)
                    end
                end
            end
        end

        # Only include the segment if there are transactions from multiple files
        if length(segment_transactions) > 1
            push!(transactions_per_segment, segment_transactions)
        end
    end

    return transactions_per_segment
end

