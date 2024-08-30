# FeatureExtractor.jl
# This file provides functions to extract and prepare raw features from GPS data,
# focusing on overlapping segments identified via KD-tree, and ready them for NiaARM.

"""
    extract_segment_data_for_arm(gps_data::Dict{Int, Dict{String, Any}}, overlapping_segments::Vector{Tuple{Int, Int}}, paths::Vector{UnitRange{Int64}}) -> Vector{Vector{Dict{String, Any}}}

Extract raw data from overlapping GPS segments across multiple TCX files and prepare it for ARM.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data where the key is an integer identifier and the value is a dictionary of properties.
- `overlapping_segments::Vector{Tuple{Int, Int}}`: A vector of tuples, each representing an overlapping segment between two paths.
- `paths::Vector{UnitRange{Int64}}`: A vector of ranges representing the indices of vertices for each TCX file.

# Returns
- A vector of transactions, where each transaction is a vector of dictionaries containing raw features for each overlapping segment, across all TCX files.
"""
function extract_segment_data_for_arm(gps_data::Dict{Int, Dict{String, Any}}, overlapping_segments::Vector{Tuple{Int, Int}}, paths::Vector{UnitRange{Int64}})
    transactions_per_segment = []

    for (idx1, idx2) in overlapping_segments
        segment_transactions = []

        for path in paths
            segment_points = [p for p in path if idx1 <= p <= idx2]
            if isempty(segment_points)
                continue  # No overlapping points in this path for this segment
            end

            # Collect raw data from the segment points
            for p in segment_points
                point = gps_data[p]
                transaction = Dict(
                    "latitude" => point["latitude"],
                    "longitude" => point["longitude"],
                    "speed" => point["speed"],
                    "altitude" => point["altitude"],
                    "heart_rate" => point["heart_rate"],
                    "distance" => point["distance"],
                    "cadence" => point["cadence"],
                    "watts" => point["watts"]
                )
                push!(segment_transactions, transaction)
            end
        end

        # Only consider segments that have data from multiple TCX files
        if length(segment_transactions) > 1
            push!(transactions_per_segment, segment_transactions)
        end
    end

    return transactions_per_segment
end
