include("../src/TCX2Graph.jl")
using BenchmarkTools
using Base.Threads
using JSON
using CSV

# Check the number of threads available
println("Number of threads: ", Threads.nthreads())

function main()

    # Path to the folder containing the .tcx files
    tcx_folder_path = TCX2Graph.get_absolute_path("../example_data/files_weather")

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

    # Create property graph
    # tcx_files or missing and true or false for osm and weather
    graph, gps_data, paths, paths_files = TCX2Graph.create_property_graph(tcx_files, true)

    # Print all the paths_files
    for (path, file) in paths_files
        println("Path: $path, File: $file")
    end

    # Plot property graph
    TCX2Graph.plot_property_graph(gps_data, paths, "./example_data/all_plots/multi_tcx_graph_property.html")

    # choose the ride by filename.
   #=  target_file = "50.tcx"
    ref_ride_idx = TCX2Graph.get_ref_ride_idx_by_filename(paths, paths_files, target_file)
    println("Using ride index $ref_ride_idx corresponding to file $target_file")

    @time overlapping_segments = TCX2Graph.find_overlapping_segments(
        gps_data,
        paths;
        ref_ride_idx = ref_ride_idx,
        max_length_m = 600.0,
        tol_m = 75.0,
        window_step = 1,
        min_runs = 52,
        prefilter_margin_m = 150.0,
        dedup_overlap_frac = 0.5
    )

    println("Found $(length(overlapping_segments)) overlapping segments.")
    for seg in overlapping_segments
        println(seg)
    end

    # Plot individual overlapping segments
    TCX2Graph.plot_individual_overlapping_segments(gps_data, paths, overlapping_segments, "./example_data/seg_plots/") =#

    # Choose segment index for analysis
    # segment_idx = 1
    # total_distance, total_ascent, total_descent, total_vertical_meters, max_gradient, avg_gradient =
    #     TCX2Graph.compute_segment_characteristics_basic(segment_idx, gps_data, overlapping_segments)

    # println("Segment $segment_idx Characteristics:")
    # println("Distance: $total_distance meters")
    # println("Ascent: $total_ascent meters")
    # println("Descent: $total_descent meters")
    # println("Vertical Meters: $total_vertical_meters meters")
    # println("Max Gradient: $(max_gradient * 100)%")
    # println("Average Gradient: $(avg_gradient * 100)%")

    # Final visualization of property graph
    # TCX2Graph.plot_property_graph(gps_data, paths, save_path)
    # println("Visualization saved to: ", save_path)
#=
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
    # println("Filtered features: ", filtered_features)



    runs = TCX2Graph.extract_single_segment_runs(overlapping_segments[1], gps_data)
    json_str = JSON.json(runs)
    write("./example_data/seg_json/segment_runs.json", json_str)
    println("Segment runs JSON written.")

    # Load JSON data
    json_path = "./example_data/seg_json/segment_runs.json"
    json_data = open(json_path, "r") do f
        JSON.parse(read(f, String))
    end

    json_data = convert(Vector{Dict}, json_data)

    # Set missing threshold
    missing_threshold = 99.0

    # Process JSON and get cleaned DataFrame
    cleaned_df = TCX2Graph.process_json_data(json_data, missing_threshold)

    # Save cleaned data to CSV
    CSV.write("./example_data/seg_json/segment_runs_cleaned.csv", cleaned_df)

    println("Cleaned dataset saved successfully!")
=#
end

main()