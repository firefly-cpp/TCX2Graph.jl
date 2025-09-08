using Revise
using TCX2Graph
using ProgressMeter
using DataFrames
using CSV
using Dates

const OUTPUT_DIR = "case_study_1_outputs"
const SEGMENT_LENGTH_M = 1000.0
const FRECHET_TOLERANCE_M = 100.0
const MIN_REPETITIONS = 50 # Minimum number of runs to be considered a candidate

# --- Main Logic ---

"""
    find_most_repeated_segments()

Main function to execute Case Study 1:
1. Creates output directories.
2. Fetches all ride data from Neo4j.
3. Iterates through each ride as a reference to find overlapping segments.
4. Collects all segments and identifies those with the most repetitions.
5. Saves the top segments to a CSV file.
6. Generates visualizations for the top segments.
"""
function find_most_repeated_segments()
    println("--- Starting Case Study 1: Find Most Repeated 1km Segments ---")

    # 1. Create output directories
    vis_dir = joinpath(OUTPUT_DIR, "visualizations")
    csv_dir = joinpath(OUTPUT_DIR, "csv")
    mkpath(vis_dir)
    mkpath(csv_dir)
    println("Output will be saved to: $OUTPUT_DIR")

    # 2. Fetch data from Neo4j
    println("Fetching data from Neo4j...")
    graph, all_gps_data, paths, paths_files = build_graph_from_neo4j()
    num_rides = length(paths)
    println("Loaded data for $num_rides rides.")

    if num_rides == 0
        println("No rides found. Exiting.")
        return
    end

    # 3. Find all overlapping segments
    all_found_segments = []
    println("Searching for $SEGMENT_LENGTH_M-meter segments across all rides...")

    @showprogress "Processing rides..." for i in 1:num_rides
        try
           segments, _ = find_overlapping_segments(
                all_gps_data,
                paths,
                ref_ride_idx=i,
                max_length_m=SEGMENT_LENGTH_M,
                tol_m=FRECHET_TOLERANCE_M,
                min_runs=MIN_REPETITIONS,
                window_step=1,
                prefilter_margin_m=100.0,
                dedup_overlap_frac=0.1
            )
            if !isempty(segments)
                push!(all_found_segments, segments...)
            end
        catch e
            println("Could not process ride $i as reference: $e")
        end
    end

    if isempty(all_found_segments)
        println("No repeated segments found with at least $MIN_REPETITIONS repetitions. Try lowering the threshold.")
        return
    end

    println("Found $(length(all_found_segments)) candidate segments in total.")
    println("Identifying the most repeated segment(s)...")

    # 4. Find the segment with the maximum number of runs
    max_runs = 0
    top_segments = []

    for seg in all_found_segments
        num_runs = length(seg["run_ranges"])
        if num_runs > max_runs
            max_runs = num_runs
            top_segments = [seg] # New top segment found
        elseif num_runs == max_runs
            # Check for duplicates before adding
            is_duplicate = false
            for existing_seg in top_segments
                # Use Frechet distance to check if they are geometrically similar
                df = discrete_frechet(seg["candidate_polyline"], existing_seg["candidate_polyline"])
                if df <= FRECHET_TOLERANCE_M
                    is_duplicate = true
                    break
                end
            end
            if !is_duplicate
                push!(top_segments, seg)
            end
        end
    end

    if isempty(top_segments)
        println("Could not identify a top segment.")
        return
    end

    println("Found $(length(top_segments)) top segment(s) with $max_runs repetitions.")

    # 5. Save results to CSV
    csv_path = joinpath(csv_dir, "top_segments.csv")
    df_rows = []
    for (i, seg) in enumerate(top_segments)
        start_pt_idx = first(seg["ref_range"])
        end_pt_idx = last(seg["ref_range"])
        start_gps = all_gps_data[start_pt_idx]
        end_gps = all_gps_data[end_pt_idx]

        push!(df_rows, (
            segment_id = i,
            repetitions = max_runs,
            length_m = seg["candidate_length"],
            start_lat = start_gps["latitude"],
            start_lon = start_gps["longitude"],
            end_lat = end_gps["latitude"],
            end_lon = end_gps["longitude"],
            ref_file = paths_files[paths[findfirst(p -> start_pt_idx in p, paths)]]
        ))
    end
    df = DataFrame(df_rows)
    CSV.write(csv_path, df)
    println("Saved top segment(s) info to: $csv_path")

    # 6. Generate visualizations
    for (i, seg) in enumerate(top_segments)
        vis_path = joinpath(vis_dir, "segment_$(i)_runs")
        println("Visualizing segment $i with $max_runs runs at: $vis_path")
        try
            visualize_segment_runs(
                seg,
                all_gps_data,
                paths_files,
                output_dir=vis_path
            )
        catch e
            println("Failed to visualize segment $i: $e")
        end
    end

    println("--- Case Study 1 Finished ---")
end

# --- Run the script ---
find_most_repeated_segments()
