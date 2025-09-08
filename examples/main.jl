include("../src/TCX2Graph.jl")
using BenchmarkTools
using Base.Threads
using JSON
using CSV

# Check the number of threads available
println("Number of threads: ", Threads.nthreads())

function main()
    # ==========================================================================================
    # --- 1. CONFIGURATION ---
    # ==========================================================================================

    # --- Data Source and Feature Enrichment ---
    # Choose the source of the data. Options: :files, :neo4j
    DATA_SOURCE = :files

    # If reading from :files, choose whether to add features from OSM and weather APIs.
    # This is ignored if DATA_SOURCE is :neo4j, as data is assumed to be pre-processed.
    ADD_EXTERNAL_FEATURES = false

    # --- Case Study Selection ---
    # 1: Single Segment Analysis (generates segment_runs_cleaned.csv for one segment)
    # 2: Path Analysis (generates path_analysis_features.csv for a computed path)
    # 3: Placeholder for future analysis
    CASE_STUDY = 1

    # --- Visualization Toggles ---
    # Set to true to generate and save a plot for each detected overlapping segment.
    # Warning: This can create a large number of files.
    VISUALIZE_INDIVIDUAL_SEGMENTS = false

    # --- File and Ride Configuration ---
    # Path to the folder containing TCX files. Only used if DATA_SOURCE is :files.
    tcx_folder_path = "../example_data/files"
    # The reference ride for segment detection. This filename must exist in your chosen DATA_SOURCE.
    target_file = "50.tcx"

    # --- Case Study 1 Parameters ---
    segment_to_analyze_idx = 1
    # Missing-value removal threshold for Case Study 1 (trackpoint-level CSV)
    CS1_MISSING_THRESHOLD = 99.0

    # --- Overlapping Segment Detection Parameters ---
    segment_max_length_m = 1000.0 # Max length of a candidate segment in meters
    segment_tolerance_m = 100.0   # Max Frechet distance for a segment to be considered an overlap
    segment_min_runs = 50          # A segment must appear in at least this many rides to be detected
    prefilter_margin_m = 100.0    # Broad-phase filter for rides; only rides within this margin are checked
    dedup_overlap_frac = 0.1      # Deduplicate segments if they overlap by more than this fraction

    # --- Pathfinding Parameters (only used for Case Study 2) ---
    start_segment_idx = 7  # Index of the start segment in the `overlapping_segments` list
    end_segment_idx = 19   # Index of the end segment in the `overlapping_segments` list
    path_min_length = 5    # The minimum number of segments required in a valid path
    path_min_runs = 2      # A segment must have at least this many runs to be used in the path.
    path_tolerance_m = 347.1 # Max distance (gap or overlap) between segments in meters to be connected

    # --- Case Study 2 Parameters ---
    # Missing-value removal threshold for Case Study 2 (segment-level CSV)
    CS2_MISSING_THRESHOLD = 99.0

    # --- Case Study 3 Parameters ---
    # Missing-value removal threshold for Case Study 3 (transition-level CSV)
    CS3_MISSING_THRESHOLD = 99.0

    # ==========================================================================================
    # --- 2. DATA LOADING ---
    # ==========================================================================================
    println("\n--- Loading Data ---")

    local graph, gps_data, paths, paths_files
    if DATA_SOURCE == :files
        println("Data source: Local TCX files.")
        absolute_tcx_path = TCX2Graph.get_absolute_path(tcx_folder_path)
        tcx_files = TCX2Graph.get_tcx_files_from_directory(absolute_tcx_path)
        if isempty(tcx_files)
            error("No TCX files found in the folder: $absolute_tcx_path")
        end
        println("Found $(length(tcx_files)) TCX files. Adding external features: $ADD_EXTERNAL_FEATURES")
        graph, gps_data, paths, paths_files = TCX2Graph.create_property_graph(tcx_files, ADD_EXTERNAL_FEATURES)
    elseif DATA_SOURCE == :neo4j
        println("Data source: Neo4j database.")
        # `missing` for tcx_files triggers Neo4j fetch. `add_features` is false as data is already processed.
        graph, gps_data, paths, paths_files = TCX2Graph.create_property_graph(missing, false)
    else
        error("Invalid DATA_SOURCE specified. Choose :files or :neo4j.")
    end

    # Visualize the complete property graph with all loaded rides
    props_set = Set{String}()
    for v in values(gps_data)
        for k in keys(v)
            push!(props_set, String(k))
        end
    end
    props_list = collect(props_set)

    viewer_path = TCX2Graph.plot_property_graph(
        graph,
        gps_data;
        out_dir = "./example_data/all_plots/leaflet_viewer",
        simplify_tolerance_m = 0.0,
        quantize_decimals = 5,
        min_points = 2,
        export_point_properties = true,
        properties_whitelist = props_list,
        sample_rate = 1,
        max_points_per_file = 40000
    )
    # Serve via a local server: cd './example_data/all_plots/leaflet_viewer'; python3 -m http.server

    # Verify that the target_file for reference exists in the loaded data
    if !(target_file in basename.(values(paths_files)))
        error("The specified target_file '$target_file' was not found in the data source.")
    end

    # ==========================================================================================
    # --- 3. OVERLAPPING SEGMENT DETECTION ---
    # ==========================================================================================
    println("\n--- Detecting Overlapping Segments ---")
    ref_ride_idx = TCX2Graph.get_ref_ride_idx_by_filename(paths, paths_files, target_file)
    println("Using ride index $ref_ride_idx ('$target_file') as reference.")

    @time overlapping_segments, close_ride_indices = TCX2Graph.find_overlapping_segments(
        gps_data,
        paths;
        ref_ride_idx = ref_ride_idx,
        max_length_m = segment_max_length_m,
        tol_m = segment_tolerance_m,
        window_step = 1,
        min_runs = segment_min_runs,
        prefilter_margin_m = prefilter_margin_m,
        dedup_overlap_frac = dedup_overlap_frac
    )
    println("Found $(length(overlapping_segments)) overlapping segments.")

    # Visualize all detected segments on a single map for overview
    if !isempty(overlapping_segments)
        TCX2Graph.plot_all_segments_on_map(
            gps_data,
            paths,
            overlapping_segments,
            close_ride_indices,
            "./example_data/all_plots/all_segments_map.html"
        )
    end

    # Optionally, visualize each segment individually
    if VISUALIZE_INDIVIDUAL_SEGMENTS && !isempty(overlapping_segments)
        println("\n--- Visualizing Individual Segments ---")
        individual_plots_path = "./example_data/seg_plots/"
        mkpath(individual_plots_path) # Ensure the directory exists
        TCX2Graph.plot_individual_overlapping_segments(gps_data, paths, overlapping_segments, individual_plots_path)
    end

    # ==========================================================================================
    # --- 4. CASE STUDY EXECUTION ---
    # ==========================================================================================
    if CASE_STUDY == 1
        println("\n--- Running Case Study 1: Single Segment Analysis ---")
        if !isempty(overlapping_segments)
            # Validate the chosen segment index
            if segment_to_analyze_idx < 1 || segment_to_analyze_idx > length(overlapping_segments)
                error("Invalid `segment_to_analyze_idx`: $segment_to_analyze_idx. Please choose an index between 1 and $(length(overlapping_segments)).")
            end
            segment_to_analyze = overlapping_segments[segment_to_analyze_idx]

            println("\n--- Analyzing characteristics for segment $segment_to_analyze_idx ---")
            total_distance, total_ascent, total_descent, total_vertical_meters, max_gradient, avg_gradient =
                TCX2Graph.compute_segment_characteristics_basic(segment_to_analyze_idx, gps_data, overlapping_segments)
            println("Total Distance: ", total_distance, "m")
            println("Total Ascent: ", total_ascent, "m")
            println("Total Descent: ", total_descent, "m")
            println("Max Gradient: ", max_gradient * 100, "%")
            println("Average Gradient: ", avg_gradient * 100, "%")

            println("\n--- Generating feature CSV for segment $segment_to_analyze_idx ---")
            runs = TCX2Graph.extract_single_segment_runs(segment_to_analyze, gps_data)

            cleaned_df = TCX2Graph.process_json_data(runs, CS1_MISSING_THRESHOLD)

            csv_path = "./example_data/seg_csv/segment_runs_cleaned.csv"
            CSV.write(csv_path, cleaned_df)
            println("Cleaned dataset for single segment saved to $csv_path")
        else
            println("No overlapping segments found to analyze for Case Study 1.")
        end

    elseif CASE_STUDY == 2
        println("\n--- Running Case Study 2: Path Analysis ---")

        # --- 4a. PATHFINDING (Only for Case Study 2) ---
        println("\n--- Finding Path Between Segments ---")
        path_segments = []
        if isempty(overlapping_segments) || max(start_segment_idx, end_segment_idx) > length(overlapping_segments)
            println("Warning: Not enough segments found to perform pathfinding with the given indices.")
        else
            start_segment = overlapping_segments[start_segment_idx]
            end_segment = overlapping_segments[end_segment_idx]
            try
                path_segments = TCX2Graph.find_path_between_segments(
                    start_segment, end_segment, overlapping_segments, gps_data;
                    min_length = path_min_length,
                    path_min_runs = path_min_runs,
                    tolerance_m = path_tolerance_m
                )
                println("Path found with $(length(path_segments)) segments.")
                TCX2Graph.plot_path_with_segments(gps_data, paths, path_segments, "./example_data/path_plots/path_segments.html")
            catch e
                println("Error finding path: ", e)
            end
        end

        # --- 4b. PATH FEATURE AGGREGATION (one row per segment, combining all runs) ---
        if !isempty(path_segments)
            println("\n--- Aggregating features for the found path (per segment) ---")

            path_segments_df = TCX2Graph.process_segments_aggregated(path_segments, gps_data, CS2_MISSING_THRESHOLD)
            if !isempty(path_segments_df)
                path_csv_path = "./example_data/path_csv/path_analysis_features.csv"
                CSV.write(path_csv_path, path_segments_df)
                println("Aggregated path features (per segment) saved to: $path_csv_path")
            else
                println("No features produced for the path.")
            end
        else
            println("No path found to analyze for Case Study 2.")
        end

    elseif CASE_STUDY == 3
        println("\n--- Running Case Study 3: Transition Analysis (Global, Run-Level) ---")

        # No pathfinding needed; use all detected overlapping segments and all rides.
        if isempty(overlapping_segments)
            println("No overlapping segments found to analyze for Case Study 3.")
        else
            println("\n--- Building global, per-run transitions across all rides ---")
            mkpath("./example_data/transitions_csv/")
            global_df = TCX2Graph.process_run_level_transitions_global(
                overlapping_segments, gps_data;
                max_dist_m = 300.0,
                max_gap_s = 3600.0,
                missing_threshold = CS3_MISSING_THRESHOLD
            )
            if !isempty(global_df)
                CSV.write("./example_data/transitions_csv/run_transitions_features.csv", global_df)
                println("Run-level transitions saved to: ./example_data/transitions_csv/run_transitions_features.csv")
            else
                println("No run-level transitions produced.")
            end
        end
    else
        println("Invalid CASE_STUDY selection. Please choose 1, 2, or 3.")
    end
end

main()