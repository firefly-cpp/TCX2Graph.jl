using Random
using StatsBase

function pso(feval::Function, problem::NamedTuple{(:dimension, :lowerbound, :upperbound, :features)}, stopping_criterion::Int;
             popsize::Int64=10, omega::Float64=0.7, c1::Float64=2.0, c2::Float64=2.0, seed::Union{Int64, Nothing}=nothing, kwargs...)
    evals = 0
    iters = 0
    rng = MersenneTwister(seed)

    # Define bounds and initialize population
    range = problem.upperbound - problem.lowerbound
    lowervelocity = -range
    uppervelocity = range
    pop = initpopulation(popsize, problem, rng)
    pbest = copy(pop)
    velocity = -lowervelocity .+ rand!(rng, similar(pop)) .* (uppervelocity - lowervelocity)

    fitness = zeros(popsize)
    bestfitness = Inf
    bestindex = 1

    # Evaluate initial population
    for (i, individual) in enumerate(eachrow(pop))
        @inbounds fitness[i] = feval(Vector(individual); problem=problem, kwargs...)
        if fitness[i] < bestfitness
            @inbounds bestfitness = fitness[i]
            bestindex = i
        end
        evals += 1
        if terminate(stopping_criterion, evals, iters, bestfitness)
            return pop[bestindex, :], bestfitness
        end
    end

    # Main optimization loop
    while !terminate(stopping_criterion, evals, iters, bestfitness)
        for i = 1:popsize
            for d = 1:problem.dimension
                @inbounds velocity[i, d] = omega * velocity[i, d] +
                                           c1 * rand(rng) * (pbest[i, d] - pop[i, d]) +
                                           c2 * rand(rng) * (pop[bestindex, d] - pop[i, d])
                @inbounds velocity[i, d] = clamp(velocity[i, d], lowervelocity, uppervelocity)
            end

            @inbounds pop[i, :] = pop[i, :] .+ velocity[i, :]
            @inbounds pop[i, :] = clamp!(pop[i, :], problem.lowerbound, problem.upperbound)

            newfitness = feval(Vector(pop[i, :]); problem=problem, kwargs...)
            if newfitness < fitness[i]
                @inbounds fitness[i] = newfitness
                @inbounds pbest[i, :] = pop[i, :]
                if newfitness < bestfitness
                    bestindex = i
                    bestfitness = newfitness
                end
            end
            evals += 1
            if terminate(stopping_criterion, evals, iters, bestfitness)
                return pop[bestindex, :], bestfitness
            end
        end
        iters += 1
    end
    return pop[bestindex, :], bestfitness
end

function de(feval::Function, problem::NamedTuple{(:dimension, :lowerbound, :upperbound, :features)}, stopping_criterion::Int;
            popsize::Int64=50, cr::Float64=0.8, f::Float64=0.9, seed::Union{Int64, Nothing}=nothing, kwargs...)
    if popsize < 4
        throw(DomainError("Population size must be at least 4."))
    end

    evals = 0
    iters = 0
    rng = MersenneTwister(seed)

    pop = initpopulation(popsize, problem, rng)
    fitness = zeros(popsize)
    bestfitness = Inf
    bestindex = 1

    # Evaluate initial population
    for (i, individual) in enumerate(eachrow(pop))
        @inbounds fitness[i] = feval(Vector(individual); problem=problem, kwargs...)
        if fitness[i] < bestfitness
            @inbounds bestfitness = fitness[i]
            bestindex = i
        end
        evals += 1
        if terminate(stopping_criterion, evals, iters, bestfitness)
            return pop[bestindex, :], bestfitness
        end
    end

    # Main optimization loop
    while !terminate(stopping_criterion, evals, iters, bestfitness)
        for i = 1:popsize
            perm = sample(rng, 1:popsize, 4)
            @inbounds a, b, c, k = perm[1], perm[2], perm[3], perm[4]

            # Ensure a, b, c are distinct from i
            if a == i; a = k; elseif b == i; b = k; elseif c == i; c = k; end

            r = rand(rng, 1:problem.dimension)

            @inbounds y = pop[i, :]
            for d = 1:problem.dimension
                if d == r || rand(rng) < cr
                    @inbounds y[d] = pop[a, d] + f * (pop[b, d] - pop[c, d])
                    @inbounds y[d] = clamp(y[d], problem.lowerbound, problem.upperbound)
                end
            end

            newfitness = feval(y; problem=problem, kwargs...)
            if newfitness < fitness[i]
                @inbounds fitness[i] = newfitness
                @inbounds pop[i, :] = y
                if newfitness < bestfitness
                    bestfitness = newfitness
                    bestindex = i
                end
            end
            evals += 1
            if terminate(stopping_criterion, evals, iters, bestfitness)
                return pop[bestindex, :], bestfitness
            end
        end
        iters += 1
    end
    return pop[bestindex, :], bestfitness
end

function initpopulation(popsize::Int, problem::NamedTuple, rng::AbstractRNG)::Matrix{Float64}
    println("Debug: Initializing population with dimension = ", problem.dimension)
    return problem.lowerbound .+ rand!(rng, zeros(popsize, problem.dimension)) .* (problem.upperbound - problem.lowerbound)
end

function terminate(stopping_criterion::Int, evals::Int, iters::Int, best_fitness::Float64)::Bool
    return evals >= stopping_criterion
end
