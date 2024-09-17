# FeatureExtractor.jl
# This file provides functions to extract and prepare raw features from GPS data,
# focusing on overlapping segments identified via KD-tree, and prepare them for ARM.

using Combinatorics
using DataFrames
using NiaARM

"""
    extract_all_possible_transactions(gps_data::Dict{Int, Dict{String, Any}},
                                      overlapping_segments::Vector{Dict{String, Any}},
                                      paths::Vector{UnitRange{Int64}})
                                      -> Vector{Vector{Dict{String, Any}}}

Generate all possible transactions for each overlapping segment across multiple paths.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: The GPS data for each trackpoint.
- `overlapping_segments::Vector{Dict{String, Any}}`: The overlapping segments with path information.
- `paths::Vector{UnitRange{Int64}}`: The list of paths from the TCX files.

# Returns
- `Vector{Vector{Dict{String, Any}}}`: A list of transactions for each segment, containing all combinations of features.
"""
function extract_all_possible_transactions(
    gps_data::Dict{Int, Dict{String, Any}},
    overlapping_segments::Vector{Dict{String, Any}},
    paths::Vector{UnitRange{Int64}}
) :: Vector{Vector{Dict{String, Any}}}

    transactions_per_segment = []

    features = ["speed", "altitude", "heart_rate", "distance", "cadence", "watts", "latitude", "longitude", "time"]

    for segment in overlapping_segments
        segment_transactions = []

        start_idx = segment["start_idx"]
        end_idx = segment["end_idx"]
        segment_paths = segment["paths"]

        all_points = []
        for path_idx in segment_paths
            path = paths[path_idx]
            for idx in start_idx:end_idx
                if idx in path
                    point = gps_data[idx]
                    available_data = Dict{String, Any}()
                    for feature in features
                        if haskey(point, feature) && point[feature] !== missing
                            available_data[feature] = point[feature]
                            #println("Feature: ", feature, " Value: ", point[feature])
                        end
                    end
                    #println("add to all_points")
                    push!(all_points, available_data)
                end
            end
        end

        for (i, point1) in enumerate(all_points)
            for (j, point2) in enumerate(all_points)
                if i != j
                    for k in 1:length(features) - 1
                        antecedent_combinations = combinations(collect(keys(point1)), k)
                        for antecedent_keys in antecedent_combinations
                            antecedent = Dict{String, Any}()
                            consequent = Dict{String, Any}()

                            # Build the antecedent
                            for key in antecedent_keys
                                antecedent[key] = point1[key]
                            end

                            # Build the consequent from point2
                            for key in setdiff(keys(point2), antecedent_keys)
                                consequent[key] = point2[key]
                            end

                            if !isempty(antecedent) && !isempty(consequent)
                                transaction = Dict("antecedent" => antecedent, "consequent" => consequent)
                                #println("add to segment_transactions")
                                push!(segment_transactions, transaction)
                            end

                        end
                    end
                end
            end
        end

        if !isempty(segment_transactions)
            push!(transactions_per_segment, segment_transactions)
        end
    end

    return transactions_per_segment
end

"""
    save_transactions_to_txt(transactions::Vector{Vector{Dict{String, Any}}}, output_dir::String)

Save the transactions for each segment into separate text files. Each file will contain the antecedent and consequent pairs
for all transactions in a specific segment.

# Arguments
- `transactions::Vector{Vector{Dict{String, Any}}}`: A vector where each element contains the transactions for a segment.
- `output_dir::String`: Directory where each segment's transactions will be saved as separate text files.

# Details
This function iterates over the transactions for each segment and saves them into individual text files in the specified directory.
Each file will be named as `transactions_segment_X.txt` where `X` is the segment number.
"""
function save_transactions_to_txt(transactions, output_dir)
    for (segment_idx, segment_transactions) in enumerate(transactions)
        output_file = joinpath(output_dir, "transactions_segment_$(segment_idx).txt")

        open(output_file, "w") do io
            for transaction in segment_transactions
                write(io, "Antecedent: ", string(transaction["antecedent"]), "\n")
                write(io, "Consequent: ", string(transaction["consequent"]), "\n")
                write(io, "\n-----------------------------\n")
            end
        end
        println("Transactions for segment $segment_idx saved to: $output_file")
    end
end
