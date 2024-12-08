function fitness_function(solution::AbstractVector{Float64}; problem::Problem, features::Vector{Dict{String, Any}})::Float64
    solution = Vector(solution)

    num_features = count_sub_features(features)
    expected_length = 4 * num_features + num_features + 3

    println("Expected solution length: $expected_length")
    println("Actual solution length: $(length(solution))")
    println("Number of features: $num_features")

    if length(solution) != expected_length
        error("Invalid solution length. Expected $expected_length, got $(length(solution)).")
    end

    println("Calling build_rule with solution of length $(length(solution)) and features of size $(length(features))")
    rules = build_rule(solution, features)

    if isempty(rules)
        println("No rules generated; fitness = 0.0")
        return 0.0
    end

    cut_point_val = solution[end - 2]
    cut_point = Int(round(cut_point_val * length(rules)))
    cut_point = clamp(cut_point, 1, length(rules) - 1)

    antecedent = rules[1:cut_point]
    consequent = rules[cut_point + 1:end]

    if isempty(antecedent) || isempty(consequent)
        println("Invalid antecedent or consequent; fitness = 0.0")
        return 0.0
    end

    total_support = support(features, antecedent)
    total_confidence = confidence(features, antecedent, consequent)

    fitness = total_support + total_confidence
    println("Fitness calculated: $fitness")
    return fitness
end
