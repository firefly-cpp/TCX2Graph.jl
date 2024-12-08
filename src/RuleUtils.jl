using JSON3

function build_rule(solution::Vector{Float64}, features::Vector{Dict{String, Any}})
    println("Entered build_rule")

    num_features = count_sub_features(features)
    expected_solution_length = 4 * num_features + num_features + 3

    # Validate solution vector length
    if length(solution) != expected_solution_length
        error("Solution vector length mismatch. Expected: $expected_solution_length, Actual: $(length(solution))")
    end

    # Divide the solution vector
    rule_part = solution[1:4 * num_features]
    permutation_part = solution[4 * num_features + 1:4 * num_features + num_features]
    reserved_metadata = solution[end - 2:end]  # Adjusted for metadata

    # Validate permutation length
    if length(permutation_part) != num_features
        error("Permutation part length mismatch. Expected: $num_features, Actual: $(length(permutation_part))")
    end

    permutation_indices = sortperm(permutation_part, rev=true)

    # Debug prints
    println("Solution vector length: $(length(solution))")
    println("num_features: $num_features")
    println("rule_part length: $(length(rule_part))")
    println("permutation_part length: $(length(permutation_part))")
    println("Permutation indices: $permutation_indices")

    rules = Vector{Dict{String, Any}}()
    sub_feature_index = 1

    for feature in features
        for sub_feature_name in keys(feature)
            # Skip irrelevant keys
            if sub_feature_name in ["start_idx", "end_idx"]
                continue
            end

            feature_meta = feature[sub_feature_name]
            feature_min = feature_meta["min"]
            feature_max = feature_meta["max"]

            if feature_min === missing || feature_max === missing || feature_min == feature_max
                println("Skipping sub-feature $sub_feature_name: invalid min/max values.")
                continue
            end

            # Calculate indices for rule_part
            idx_base = (sub_feature_index - 1) * 4 + 1
            if idx_base + 3 > length(rule_part)
                error("Rule part access out of bounds: [$idx_base, $(idx_base + 3)]. Rule part length: $(length(rule_part))")
            end

            println("Processing feature $sub_feature_name with idx_base: $idx_base")

            # Calculate borders and threshold
            border1 = feature_min + (feature_max - feature_min) * rule_part[idx_base]
            border2 = feature_min + (feature_max - feature_min) * rule_part[idx_base + 1]
            threshold = rule_part[idx_base + 2]
            avg_weight = rule_part[idx_base + 3]

            # Validate and add attribute
            if abs(border2 - border1) > 1e-2
                rules = add_attribute(
                    rules, sub_feature_name, feature_meta["type"],
                    min(border1, border2), max(border1, border2), threshold, avg_weight
                )
                println("Generated rule: $(rules[end])")
            else
                println("Skipping sub-feature $sub_feature_name: borders too close.")
            end

            sub_feature_index += 1
        end
    end

    # Export rules and debug information to JSON
    export_data = Dict(
        "solution_vector" => solution,
        "features" => features,
        "rules" => rules,
        "reserved_metadata" => reserved_metadata
    )

    open("debug_rules.json", "w") do io
        write(io, JSON3.write(export_data, pretty=true))  # Pretty print for readability
    end
    println("Debug information exported to debug_rules.json")

    return rules
end

function add_attribute(rules::Vector{Dict{String, Any}}, feature_name::String, feature_type::String, border1::Float64, border2::Float64, threshold::Float64, avg::Float64)
    rule = Dict(
        "feature" => feature_name,
        "type" => feature_type,
        "border1" => border1,
        "border2" => border2,
        "threshold" => threshold,
        "avg" => avg  # Include avg in the rule for completeness
    )
    push!(rules, rule)
    return rules
end

