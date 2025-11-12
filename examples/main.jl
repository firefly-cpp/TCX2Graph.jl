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
    DATA_SOURCE = :neo4j

    # If reading from :files, choose whether to add features from OSM and weather APIs.
    # This is ignored if DATA_SOURCE is :neo4j, as data is assumed to be pre-processed.
    ADD_EXTERNAL_FEATURES = false

    # --- Case Study Selection ---
    # 1: Single Segment Analysis (generates segment_runs_cleaned.csv for one segment)
    # 2: Path Analysis (generates path_analysis_features.csv for a computed path)
    # 3: Placeholder for future analysis
    CASE_STUDY = 2

    # --- Visualization Toggles ---
    # Set to true to generate and save a plot for each detected overlapping segment.
    # Warning: This can create a large number of files.
    VISUALIZE_INDIVIDUAL_SEGMENTS = false

    SEGMENT_CACHE_PATH = "./example_data/cache/overlapping_segments.jld2"
    USE_SEGMENT_CACHE = true
    REBUILD_SEGMENT_CACHE = false
    CACHE_FORCE_OVERWRITE = true
    GRAPH_CACHE_PATH = "/Volumes/Arion/feri/tcx2graph/cache/property_graph.jld2"
    USE_GRAPH_CACHE = false
    REBUILD_GRAPH_CACHE = false

    # --- File and Ride Configuration ---
    # Path to the folder containing TCX files. Only used if DATA_SOURCE is :files.
    tcx_folder_path = "../example_data/files"
    # The reference ride for segment detection. This filename must exist in your chosen DATA_SOURCE.
    target_file = "78.tcx"

    # --- Case Study 1 Parameters ---
    segment_to_analyze_idx = 1
    # Missing-value removal threshold for Case Study 1 (trackpoint-level CSV)
    CS1_MISSING_THRESHOLD = 99.0

    # --- Overlapping Segment Detection Parameters ---
    segment_max_length_m = 1000.0 # Max length of a candidate segment in meters
    segment_tolerance_m = 100.0   # Max Frechet distance for a segment to be considered an overlap
    segment_min_runs = 10          # A segment must appear in at least this many rides to be detected
    prefilter_margin_m = 1.0    # Broad-phase filter for rides; only rides within this margin are checked
    dedup_overlap_frac = 0.75      # Deduplicate segments if they overlap by more than this fraction

    # --- Pathfinding Parameters (only used for Case Study 2) ---
    start_segment_idx = 6  # Index of the start segment in the `overlapping_segments` list
    end_segment_idx = 32   # Index of the end segment in the `overlapping_segments` list
    path_min_length = 5    # The minimum number of segments required in a valid path
    path_min_runs = 2      # A segment must have at least this many runs to be used in the path.
    path_tolerance_m = 300.0 # Max distance (gap or overlap) between segments in meters to be connected

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
    graph_cache_hit = false
    if USE_GRAPH_CACHE && !REBUILD_GRAPH_CACHE && isfile(GRAPH_CACHE_PATH)
        try
            graph_cache = TCX2Graph.load_property_graph_cache(GRAPH_CACHE_PATH)
            cached_source = Symbol(get(graph_cache.metadata, "data_source", String(DATA_SOURCE)))
            cached_features = get(graph_cache.metadata, "add_external_features", ADD_EXTERNAL_FEATURES)
            if cached_source == DATA_SOURCE && cached_features == ADD_EXTERNAL_FEATURES
                graph, gps_data, paths, paths_files = graph_cache.graph, graph_cache.gps_data, graph_cache.paths, graph_cache.paths_files
                graph_cache_hit = true
                println("Loaded property graph from cache at $(GRAPH_CACHE_PATH).")
            else
                println("Graph cache metadata mismatch (source/features). Rebuilding graph.")
            end
        catch err
            @warn "Failed to load property graph cache: $err"
        end
    end

    if !graph_cache_hit
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

        if USE_GRAPH_CACHE
            metadata = Dict{String,Any}(
                "data_source" => String(DATA_SOURCE),
                "add_external_features" => ADD_EXTERNAL_FEATURES
            )
            try
                TCX2Graph.save_property_graph_cache(
                    GRAPH_CACHE_PATH,
                    graph,
                    gps_data,
                    paths,
                    paths_files;
                    metadata = metadata,
                    force = CACHE_FORCE_OVERWRITE || REBUILD_GRAPH_CACHE
                )
                println("Property graph cached at $(GRAPH_CACHE_PATH).")
            catch err
                @warn "Failed to save property graph cache: $err"
            end
        end
    end

    # Visualize the complete property graph with all loaded rides
    #=
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
        export_point_properties = false,
        properties_whitelist = nothing,
        sample_rate = 1,
        max_points_per_file = 40000
    )
    # Serve via a local server: cd './example_data/all_plots/leaflet_viewer'; python3 -m http.server
    =#
    result = TCX2Graph.compute_unique_coverage_km(gps_data, paths; quantize_m=10.0)
    println(result)

    if !(target_file in basename.(values(paths_files)))
        error("The specified target_file '$target_file' was not found in the data source.")
    end

    # ==========================================================================================
    # --- 3. OVERLAPPING SEGMENT DETECTION ---
    # ==========================================================================================
    println("\n--- Detecting Overlapping Segments ---")
    ref_ride_idx = TCX2Graph.get_ref_ride_idx_by_filename(paths, paths_files, target_file)
    println("Using ride index $ref_ride_idx ('$target_file') as reference.")

    cache_parameters = (
        max_length_m = segment_max_length_m,
        tol_m = segment_tolerance_m,
        min_runs = segment_min_runs,
        prefilter_margin_m = prefilter_margin_m,
        dedup_overlap_frac = dedup_overlap_frac
    )
    overlapping_segments = Vector{Dict{String,Any}}()
    close_ride_indices = Int[]
    segment_adjacency = nothing
    cache_hit = false

    if USE_SEGMENT_CACHE && !REBUILD_SEGMENT_CACHE && isfile(SEGMENT_CACHE_PATH)
        cached = TCX2Graph.load_segment_cache(SEGMENT_CACHE_PATH)
        cache_hit = TCX2Graph.cache_parameters_match(cached.metadata, cache_parameters) &&
                    get(cached.metadata, "ref_ride_idx", nothing) == ref_ride_idx
        if cache_hit
            overlapping_segments = cached.segments
            close_ride_indices = cached.close_ride_indices
            adjacency_min_runs = get(cached.metadata, "adjacency_min_runs", nothing)
            adjacency_tol = get(cached.metadata, "adjacency_tolerance_m", nothing)
            if !isnothing(cached.adjacency) &&
               adjacency_min_runs == path_min_runs &&
               adjacency_tol == Float64(path_tolerance_m)
                segment_adjacency = cached.adjacency
            else
                segment_adjacency = nothing
            end
            println("Loaded $(length(overlapping_segments)) overlapping segments from cache.")
        else
            println("Cache metadata mismatch; rebuilding overlaps.")
        end
    end

    if isempty(overlapping_segments)
        @time overlapping_segments, close_ride_indices = TCX2Graph.find_overlapping_segments(
            gps_data,
            paths;
            ref_ride_idx = ref_ride_idx,
            max_length_m = segment_max_length_m,
            tol_m = segment_tolerance_m,
            window_step = 100,
            min_runs = segment_min_runs,
            prefilter_margin_m = prefilter_margin_m,
            dedup_overlap_frac = dedup_overlap_frac,
            show_progress = true,
            progress_dt_s = 0.5
        )
        segment_adjacency = isempty(overlapping_segments) ? nothing :
            TCX2Graph.build_segment_adjacency(
                overlapping_segments;
                min_runs = path_min_runs,
                tolerance_m = path_tolerance_m
            )
        if USE_SEGMENT_CACHE
            metadata = TCX2Graph.build_segment_cache_metadata(
                ref_ride_idx = ref_ride_idx,
                ref_filename = target_file,
                data_source = DATA_SOURCE,
                parameters = cache_parameters,
                segment_count = length(overlapping_segments),
                close_ride_count = length(close_ride_indices),
                extra = Dict{String,Any}(
                    "adjacency_min_runs" => path_min_runs,
                    "adjacency_tolerance_m" => Float64(path_tolerance_m)
                )
            )
            TCX2Graph.save_segment_cache(
                SEGMENT_CACHE_PATH,
                overlapping_segments,
                close_ride_indices;
                metadata = metadata,
                adjacency = segment_adjacency,
                force = CACHE_FORCE_OVERWRITE || !cache_hit
            )
        end
    end
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

        if isnothing(segment_adjacency) && !isempty(overlapping_segments)
            segment_adjacency = TCX2Graph.build_segment_adjacency(
                overlapping_segments;
                min_runs = path_min_runs,
                tolerance_m = path_tolerance_m
            )
        end

        println("\n--- Finding Path Between Segments ---")
        path_segments = []
        path_kwargs = (; min_length = path_min_length, min_runs = path_min_runs, tolerance_m = Float64(path_tolerance_m))
        if isempty(overlapping_segments) || max(start_segment_idx, end_segment_idx) > length(overlapping_segments)
            println("Warning: Not enough segments found to perform pathfinding with the given indices.")
        else
            start_segment = overlapping_segments[start_segment_idx]
            end_segment = overlapping_segments[end_segment_idx]
            try
                path_segments = TCX2Graph.find_path_between_segments(
                    start_segment, end_segment, overlapping_segments, gps_data;
                    path_kwargs..., adjacency = segment_adjacency
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
