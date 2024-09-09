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

    # Iterate through the overlapping segments
    for ((start_idx1, start_idx2), (end_idx1, end_idx2)) in overlapping_segments
        segment_transactions = []

        # For each file (path), retrieve the points between the start and end indices
        for (file_idx, path) in enumerate(paths)
            # Retrieve points for the current path based on start and end indices
            segment_points = []

            if file_idx == 1
                segment_points = [p for p in path if start_idx1 <= p <= end_idx1]
            else
                segment_points = [p for p in path if start_idx2 <= p <= end_idx2]
            end

            if !isempty(segment_points)
                println("Segment Points Found for File $file_idx: ", length(segment_points))  # Debugging line

                # Collect data for each point in the segment
                for p in segment_points
                    point = gps_data[p]
                    transaction = Dict{String, Any}()

                    transaction["latitude"] = point["latitude"]
                    transaction["longitude"] = point["longitude"]
                    transaction["speed"] = haskey(point, "speed") ? point["speed"] : missing
                    transaction["altitude"] = haskey(point, "altitude") ? point["altitude"] : missing
                    transaction["heart_rate"] = haskey(point, "heart_rate") ? point["heart_rate"] : missing
                    transaction["distance"] = haskey(point, "distance") ? point["distance"] : missing
                    transaction["cadence"] = haskey(point, "cadence") ? point["cadence"] : missing
                    transaction["watts"] = haskey(point, "watts") ? point["watts"] : missing

                    # Add transaction for each point
                    push!(segment_transactions, transaction)
                end
            else
                println("No segment points found for file: $file_idx, overlapping segment: $start_idx1 to $end_idx1 or $start_idx2 to $end_idx2")
            end
        end

        # Only add to result if there are transactions from multiple files
        if length(segment_transactions) > 1
            push!(transactions_per_segment, segment_transactions)
        else
            println("No transactions generated for this segment.")
        end
    end

    return transactions_per_segment
end
