function build_rule(solution::Vector{Float64}, features::Vector{Dict{String, Any}})
    println("Debug: build_rule called with solution length = ", length(solution))
    println("Debug: Features count = ", length(features))

    expected_length = 2 * length(features) + length(features)
    if length(solution) != expected_length
        error("Solution length $(length(solution)) does not match expected length $expected_length.")
    end

    rule_part = solution[1:2 * length(features)]
    permutation_part = solution[2 * length(features) + 1:end]
    permutation_indices = sortperm(permutation_part, rev=true)
    println("Debug: Permutation indices = ", permutation_indices)

    attributes = Vector{Dict{String, Any}}()
    for i in 1:length(features)
        feature = features[permutation_indices[i]]
        feature_name = first(keys(feature))
        feature_meta = feature[feature_name]

        feature_min = feature_meta["min"]
        feature_max = feature_meta["max"]

        if feature_min === missing || feature_max === missing || feature_min == feature_max
            println("Debug: Feature $feature_name has invalid min/max values; skipping.")
            continue
        end

        idx1 = 2 * (i - 1) + 1
        idx2 = 2 * (i - 1) + 2
        if idx2 > length(rule_part)
            println("Debug: Skipping feature $feature_name due to out-of-bounds indices.")
            continue
        end

        border1 = feature_min + (feature_max - feature_min) * rule_part[idx1]
        border2 = feature_min + (feature_max - feature_min) * rule_part[idx2]
        if abs(border2 - border1) > 1e-2
            attributes = add_attribute(
                attributes, feature_name, feature_meta["type"], min(border1, border2), max(border1, border2)
            )
        else
            println("Debug: Borders for $feature_name are too close or equal; skipping.")
        end
    end

    println("Debug: Rule generated: ", attributes)
    return attributes
end

function add_attribute(attributes::Vector{Dict{String, Any}}, feature_name::String, feature_type::String, border1::Float64, border2::Float64)
    attribute = Dict(
        "feature" => feature_name,
        "type" => feature_type,
        "border1" => border1,
        "border2" => border2
    )
    push!(attributes, attribute)
    return attributes
end
