function support(segments::Vector{Dict{String, Any}}, antecedent::Vector{Dict{String, Any}})::Float64
    total_segments = length(segments)
    if total_segments == 0
        return 0.0
    end

    count_antecedent = count(segment -> all(attr -> satisfies_condition(segment, attr), antecedent), segments)
    return count_antecedent / total_segments
end

function confidence(segments::Vector{Dict{String, Any}}, antecedent::Vector{Dict{String, Any}}, consequent::Vector{Dict{String, Any}})::Float64
    count_antecedent = count(segment -> all(attr -> satisfies_condition(segment, attr), antecedent), segments)
    if count_antecedent == 0
        return 0.0
    end

    count_both = count(segment ->
        all(attr -> satisfies_condition(segment, attr), antecedent) &&
        all(attr -> satisfies_condition(segment, attr), consequent),
        segments
    )

    return count_both / count_antecedent
end

function satisfies_condition(segment::Dict{String, Any}, attr::Dict{String, Any})::Bool
    if haskey(segment, attr["feature"]) && attr["type"] == "Numerical"
        feature_value = segment[attr["feature"]]["avg"]
        return attr["border1"] <= feature_value <= attr["border2"]
    else
        return false
    end
end
