"""
    build_rule(solution::Vector{Float64}, features::Dict{String, Dict{String, Any}}; is_time_series::Bool=false)

Builds rules for cycling paths based on a solution vector and feature metadata.

# Arguments
- `solution::Vector{Float64}`: A vector containing thresholds and permutations for path segments.
- `features::Dict{String, Dict{String, Any}}`: A dictionary where keys are feature names, and values are metadata (e.g., type, range).
- `is_time_series::Bool=false`: Indicates whether the data contains time-dependent features.

# Returns
A vector of constructed attributes (rules), where each attribute describes a constraint or property of a feature.
"""
function build_rule(solution::Vector{Float64}, features::Dict{String, Dict{String, Any}}; is_time_series::Bool=false)
    is_first_attribute = true
    attributes = []

    num_features = length(features)
    len_solution = length(solution)

    if len_solution < num_features
        error("Solution length is smaller than the number of features.")
    end

    # Separate solution into two parts: thresholds and permutations
    permutation_part = solution[end-num_features+1:end]
    solution_part = solution[1:end-num_features]

    # Sort features by descending order of permutation values
    permutation_indices = sortperm(permutation_part, rev=true)

    # Iterate over features in sorted order
    for i in permutation_indices
        feature_name = keys(features)[i]  # Extract feature name
        feature_meta = features[feature_name]  # Metadata for this feature
        feature_type = feature_meta["type"]  # Type: "Numerical" or "Categorical"

        # Determine positions for thresholds in the solution vector
        vector_position = feature_position(features, feature_name)
        threshold_position = vector_position + (feature_type == "Numerical" ? 2 : 1)

        # Check if feature threshold condition is met
        if solution_part[vector_position] > solution_part[threshold_position]
            if feature_type != "Categorical"
                # Numerical feature: Calculate threshold values
                border1 = round(calculate_border(feature_meta, solution_part[vector_position]), digits=4)
                border2 = round(calculate_border(feature_meta, solution_part[vector_position + 1]), digits=4)
                if border1 > border2
                    border1, border2 = border2, border1
                end

                # Add numerical feature to rule attributes
                if is_first_attribute
                    attributes = add_attribute([], feature_name, feature_type, border1, border2, "EMPTY")
                    is_first_attribute = false
                else
                    attributes = add_attribute(attributes, feature_name, feature_type, border1, border2, "EMPTY")
                end
            else
                # Categorical feature: Select category
                categories = feature_meta["categories"]
                selected_category = calculate_selected_category(solution_part[vector_position], length(categories))

                # Add categorical feature to rule attributes
                if is_first_attribute
                    attributes = add_attribute([], feature_name, feature_type, 1.0, 1.0, categories[selected_category])
                    is_first_attribute = false
                else
                    attributes = add_attribute(attributes, feature_name, feature_type, 1.0, 1.0, categories[selected_category])
                end
            end
        end
    end

    return attributes
end

"""
    feature_position(features::Dict{String, Dict{String, Any}}, feature_name::String)

Finds the position of a feature in the solution vector based on its type.

# Arguments
- `features::Dict{String, Dict{String, Any}}`: Metadata about all features.
- `feature_name::String`: The name of the feature.

# Returns
The starting position of the feature in the solution vector.
"""
function feature_position(features::Dict{String, Dict{String, Any}}, feature_name::String)
    position = 0
    for (name, meta) in features
        if name == feature_name
            break
        end
        position += meta["type"] == "Categorical" ? 2 : 3
    end
    return position
end

"""
    calculate_border(feature_meta::Dict{String, Any}, value::Float64)

Calculates the threshold (border) for a numerical feature based on its range.

# Arguments
- `feature_meta::Dict{String, Any}`: Metadata about the feature (including `min` and `max` values).
- `value::Float64`: The value to map to the feature's range.

# Returns
The calculated threshold value.
"""
function calculate_border(feature_meta::Dict{String, Any}, value::Float64)
    feature_min = feature_meta["min"]
    feature_max = feature_meta["max"]
    return feature_min + (feature_max - feature_min) * value
end

"""
    calculate_selected_category(value::Float64, num_categories::Int)

Determines the index of the selected category based on the solution vector value.

# Arguments
- `value::Float64`: The encoded value representing a category.
- `num_categories::Int`: The number of available categories.

# Returns
The index of the selected category.
"""
function calculate_selected_category(value::Float64, num_categories::Int)
    return Int(floor(value * (num_categories - 1)))
end

"""
    add_attribute(attributes::Vector{Dict{String, Any}}, feature_name::String, feature_type::String, border1::Float64, border2::Float64, category::String)

Adds a new attribute to the rule being constructed.

# Argument0s
- `attributes::Vector{Dict{String, Any}}`: The list of attributes constructed so far.
- `feature_name::String`: The name of the feature.
- `feature_type::String`: The type of the feature (e.g., "Numerical" or "Categorical").
- `border1::Float64`: Lower bound for numerical features (or 1.0 for categorical).
- `border2::Float64`: Upper bound for numerical features (or 1.0 for categorical).
- `category::String`: The selected category for categorical features (or "EMPTY" for numerical).

# Returns
The updated list of attributes.
"""
function add_attribute(attributes::Vector{Dict{String, Any}}, feature_name::String, feature_type::String, border1::Float64, border2::Float64, category::String)
    attribute = Dict(
        "feature" => feature_name,
        "type" => feature_type,
        "border1" => border1,
        "border2" => border2,
        "category" => category
    )
    push!(attributes, attribute)
    return attributes
end
