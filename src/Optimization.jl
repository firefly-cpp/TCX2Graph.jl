function fitness_function(solution::Vector{Float64}; problem::NamedTuple)::Float64
    println("Debug: Solution length = ", length(solution))
    println("Debug: Expected length = ", 2 * length(problem.features) + length(problem.features))

    support_weight = 1.0
    confidence_weight = 1.0

    cut_point_val = solution[end]
    rule = build_rule(solution[1:end], problem.features)

    if isempty(rule)
        println("Debug: Rule is empty. Fitness = 0.0")
        return 0.0
    end

    cut = calculate_cut_point(cut_point_val, length(rule))
    antecedent = rule[1:cut]
    consequent = rule[cut+1:end]

    if isempty(antecedent) || isempty(consequent)
        println("Debug: Antecedent or consequent is empty.")
        return 0.0
    end

    total_support = support(problem.features, antecedent)
    total_confidence = confidence(problem.features, antecedent, consequent)

    fitness = (support_weight * total_support) + (confidence_weight * total_confidence)
    println("Debug: Total Support = ", total_support)
    println("Debug: Total Confidence = ", total_confidence)
    println("Debug: Fitness = ", fitness)
    return fitness
end

function calculate_cut_point(cut_value::Float64, num_features::Int)::Int
    cut = Int(floor(cut_value * num_features))
    return clamp(cut, 1, num_features - 1)
end
