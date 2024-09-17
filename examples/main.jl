include("../src/TCX2Graph.jl")
using NiaARM
using DataFrames

function get_absolute_path(relative_path::String)
    return abspath(joinpath(@__DIR__, relative_path))
end

function save_rules_to_txt(rules, output_file)
    open(output_file, "w") do io
        for rule in rules
            if rule.fitness == -Inf
                println(io, "Warning: Fitness was not calculated.")
            end
            write(io, "Antecedent: ", string(rule.antecedent), "\n")
            write(io, "Consequent: ", string(rule.consequent), "\n")
            write(io, "Fitness: ", string(rule.fitness), "\n")
            write(io, "\n-----------------------------\n")
        end
    end
end

function main()

    tcx_files = [
        #get_absolute_path("../example_data/activity_12163012156.tcx"),
        #get_absolute_path("../example_data/activity_12171312300.tcx"),
        #get_absolute_path("../example_data/activity_12186252814.tcx"),
        get_absolute_path("../example_data/activity_12270580292.tcx"),#ok
        get_absolute_path("../example_data/activity_12381259800.tcx") #ok
    ]

    save_path = get_absolute_path("multi_tcx_graph_property.svg")

    for file in tcx_files
        println("Checking file: $file")
        if !isfile(file)
            error("File not found: $file")
        end
    end

    # Create property graph and KDTree
    graph, gps_data, paths = TCX2Graph.create_property_graph(tcx_files)
    kdtree = TCX2Graph.create_kdtree_index(gps_data)

    # Find overlapping segments across multiple paths
    overlapping_segments = TCX2Graph.find_overlapping_segments_across_paths(gps_data, paths, kdtree)

    println("Overlapping segments (KD-tree): ", length(overlapping_segments))

    # Plot individual overlapping segments
    TCX2Graph.plot_individual_overlapping_segments(gps_data, paths, overlapping_segments, "./examples/segments_visualizations/")

    # Extract transactions for association rule mining
    transactions_per_segment = TCX2Graph.extract_all_possible_transactions(gps_data, overlapping_segments, paths)
    println("Prepared Transactions per Segment for ARM: ", length(transactions_per_segment))

    # Save transactions to a file
    TCX2Graph.save_transactions_to_txt(transactions_per_segment, "./examples/transactions/")

    # ARM criterion and rule generation
    criterion = StoppingCriterion(maxevals=5000)

    for (i, segment_transactions) in enumerate(transactions_per_segment)
        println("Processing Segment $i with NiaARM...")

        df = DataFrame(segment_transactions)

        result_de = mine(df, de, criterion, seed=1234)
        save_rules_to_txt(result_de, "./examples/rules/rules_de_segment_$i.txt")

        result_pso = mine(df, pso, criterion, seed=1234)
        save_rules_to_txt(result_pso, "./examples/rules/rules_pso_segment_$i.txt")
    end

    # Final visualization of property graph
    TCX2Graph.plot_property_graph(gps_data, paths, save_path)
    println("Visualization saved to: ", save_path)
end

main()
