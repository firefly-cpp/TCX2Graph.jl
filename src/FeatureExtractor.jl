# FeatureExtractor.jl
# This file provides functions to extract and prepare raw features from GPS data,
# focusing on overlapping segments identified via KD-tree, and prepare them for ARM.

using Combinatorics

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
    overlapping_segments::Vector{Dict{String, Any}},
    paths::Vector{UnitRange{Int64}}
) :: Vector{Vector{Dict{String, Any}}}

    transactions_per_segment = []

    features = ["speed", "altitude", "heart_rate", "distance", "cadence", "watts", "latitude", "longitude", "time"]

    for segment in overlapping_segments
        segment_transactions = []

        # Extract the start and end indices for the segment
        start_idx = segment["start_idx"]
        end_idx = segment["end_idx"]
        segment_paths = segment["paths"]  # Paths where this segment occurs

        # Loop through each path involved in this segment
        for path_idx in segment_paths
            path = paths[path_idx]

            # For each GPS point in the segment, extract relevant features and build transactions
            for idx in start_idx:end_idx
                if idx in path
                    point = gps_data[idx]
                    available_data = Dict{String, Any}()

                    # Collect only non-missing data from the point
                    for feature in features
                        if haskey(point, feature) && point[feature] !== missing
                            available_data[feature] = point[feature]
                        end
                    end

                    # Generate all combinations of antecedents and consequents
                    for k in 1:(length(keys(available_data)) - 1)
                        antecedent_combinations = combinations(collect(keys(available_data)), k)
                        for antecedent_keys in antecedent_combinations
                            antecedent = Dict{String, Any}()
                            consequent = Dict{String, Any}()

                            # Fill antecedent and consequent from available data
                            for key in antecedent_keys
                                antecedent[key] = available_data[key]
                            end
                            # Remaining features go to the consequent
                            for key in setdiff(keys(available_data), antecedent_keys)
                                consequent[key] = available_data[key]
                            end

                            # Create the transaction
                            if !isempty(antecedent) && !isempty(consequent)
                                transaction = Dict("antecedent" => antecedent, "consequent" => consequent)
                                push!(segment_transactions, transaction)
                            end
                        end
                    end
                end
            end
        end

        # Add segment's transactions to overall result
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
                # Save the antecedent
                antecedent_str = "Antecedent: " * string(transaction["antecedent"]) * "\n"
                write(io, antecedent_str)

                # Save the consequent
                consequent_str = "Consequent: " * string(transaction["consequent"]) * "\n"
                write(io, consequent_str)

                write(io, "\n-----------------------------\n")
            end
        end
        println("Transactions for segment $segment_idx saved to: $output_file")
    end
end
