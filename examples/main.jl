include("../src/TCX2Graph.jl")
using BenchmarkTools
using Base.Threads

# Check the number of threads available
println("Number of threads: ", Threads.nthreads())

function main()
    # Path to the folder containing the .tcx files
    tcx_folder_path = TCX2Graph.get_absolute_path("../example_data/files")

    # Get all .tcx files from the folder
    tcx_files = TCX2Graph.get_tcx_files_from_directory(tcx_folder_path)

    if isempty(tcx_files)
        error("No TCX files found in the folder: $tcx_folder_path")
    end

    println("Found $(length(tcx_files)) TCX files.")

    save_path = TCX2Graph.get_absolute_path("multi_tcx_graph_property.svg")

    # Check for file existence
    for file in tcx_files
        println("Checking file: $file")
        if !isfile(file)
            error("File not found: $file")
        end
    end

    # Create property graph and KDTree
    graph, gps_data, paths = TCX2Graph.create_property_graph(tcx_files, true)
    kdtree = TCX2Graph.create_kdtree_index(gps_data)

    # Find overlapping segments across multiple paths
    @time overlapping_segments = TCX2Graph.find_overlapping_segments_across_paths(gps_data, paths, kdtree, max_gap=0.0045, min_segment_length=3, segment_gap_tolerance=15)
    println("Overlapping segments (KD-tree): ", length(overlapping_segments))

    # Plot individual overlapping segments
    #TCX2Graph.plot_individual_overlapping_segments(gps_data, paths, overlapping_segments, "./examples/")
    #TCX2Graph.plot_individual_overlapping_segments(gps_data, paths, overlapping_segments, "/Volumes/Arion/feri/tcx2graph/svtemp/")

    # Choose segment index for analysis
    # segment_idx = 1
    # total_distance, total_ascent, total_descent, total_vertical_meters, max_gradient, avg_gradient =
    #    TCX2Graph.compute_segment_characteristics_basic(segment_idx, gps_data, overlapping_segments)

    # println("Segment $segment_idx Characteristics:")
    # println("Distance: $total_distance meters")
    # println("Ascent: $total_ascent meters")
    # println("Descent: $total_descent meters")
    # println("Vertical Meters: $total_vertical_meters meters")
    # println("Max Gradient: $(max_gradient * 100)%")
    # println("Average Gradient: $(avg_gradient * 100)%")

    # Final visualization of property graph
    #TCX2Graph.plot_property_graph(gps_data, paths, save_path)
    #println("Visualization saved to: ", save_path)

    # Example of selecting start and end segments (use actual indices or logic as needed)
    start_segment = overlapping_segments[7]  # Select your actual start segment
    end_segment = overlapping_segments[5]  # Select your actual end segment

    path_segments = []

    # Call the function to find the path between the selected start and end segments
    try
        path_segments = TCX2Graph.find_path_between_segments(
                start_segment,
                end_segment,
                overlapping_segments,
                gps_data;
                min_length=3,       # Adjust this as needed
                min_paths=2,        # Adjust this as needed
                tolerance=0.07     # Adjust this as needed
            )

        println("Path found with segments:")
        for segment in path_segments
          println(segment)
        end
    catch e
        println("Error finding path: ", e)
    end

    # Define problem dimensions and bounds based on feature count
    path_features = TCX2Graph.extract_segment_features(path_segments, gps_data)
    println("Extracting features for path segments...")
    filtered_features = TCX2Graph.filter_features(path_features)
    println("Filtered features: ", filtered_features)

    # Run PSO
    best_fitness_pso = TCX2Graph.run_pso(
        TCX2Graph.fitness_function,
        filtered_features,
        100;
        popsize=20,
        omega=0.7,
        c1=2.0,
        c2=2.0
    )
    println("Best PSO Fitness: ", best_fitness_pso)

    # Run DE
    best_fitness_de = TCX2Graph.run_de(
        TCX2Graph.fitness_function,
        filtered_features,
        100;
        popsize=50,
        cr=0.8,
        f=0.9
    )
    println("Best DE Fitness: ", best_fitness_de)

end

main()