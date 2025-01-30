using NiaARM: StoppingCriterion, Problem, pso, de

function prepare_problem(features::Vector{Dict{String, Any}})
    num_features = count_sub_features(features)
    dimension = 4 * num_features + num_features + 3
    lowerbound = 0.0
    upperbound = 1.0
    lowerinit = lowerbound
    upperinit = upperbound

    return Problem(dimension, lowerbound, upperbound, lowerinit, upperinit)
end

function run_pso(feval::Function, features::Vector{Dict{String, Any}}, maxevals::Int; kwargs...)
    problem = prepare_problem(features)
    println("Solution length: $(problem.dimension)")
    return pso((solution...; problem=problem) -> feval(solution...; problem=problem, features=features),
        problem, StoppingCriterion(maxevals=maxevals); kwargs...)
end

function run_de(feval::Function, features::Vector{Dict{String, Any}}, maxevals::Int; kwargs...)
    problem = prepare_problem(features)
    return de((solution...; problem=problem) -> feval(solution...; problem=problem, features=features),
        problem, StoppingCriterion(maxevals=maxevals); kwargs...)
end
