using Combinatorics
using DataFrames
using NiaARM

"""
    extract_all_possible_transactions(gps_data::Dict{Int, Dict{String, Any}},
                                      overlapping_segments::Vector{Dict{String, Any}},
                                      paths::Vector{UnitRange{Int64}})
                                      -> Vector{Vector{Dict{String, Any}}}

Generates all possible transactions for each overlapping segment across multiple paths.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing the GPS data for each trackpoint, where the key is the index, and the value is another dictionary with trackpoint features (e.g., speed, altitude).
- `overlapping_segments::Vector{Dict{String, Any}}`: A vector of dictionaries representing overlapping segments, each containing segment-specific information, including path indices and start/end indices of the segment.
- `paths::Vector{UnitRange{Int64}}`: A vector of paths from the TCX files, where each path is represented as a range of trackpoint indices.

# Returns
- `Vector{Vector{Dict{String, Any}}}`: A list of transaction lists, where each transaction corresponds to a segment and contains combinations of antecedent and consequent features.

# Details
This function iterates over the overlapping segments and their corresponding paths. For each segment, it extracts all points within the overlapping range from the GPS data, generates antecedent-consequent pairs for feature combinations, and returns a list of transactions for each segment.
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
                        end
                    end
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

Saves the transactions for each segment into separate text files. Each file will contain antecedent-consequent pairs
for all transactions related to a specific segment.

# Arguments
- `transactions::Vector{Vector{Dict{String, Any}}}`: A vector where each element is a list of transactions for a particular segment.
- `output_dir::String`: The directory where the transactions will be saved. Each segment will be saved into its own file.

# Details
This function creates a text file for each segment's transactions. The files are named in the format `transactions_segment_X.txt`,
where `X` is the index of the segment. Each file will list the antecedent-consequent pairs, separated by a line.
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
