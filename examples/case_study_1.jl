include("../src/TCX2Graph.jl")
using Revise
using ProgressMeter
using DataFrames
using CSV
using Dates
using JSON

const OUTPUT_DIR = "case_study_1_outputs"
const SEGMENT_LENGTH_M = 1000.0
const FRECHET_TOLERANCE_M = 100.0
const MIN_REPETITIONS = 60 # Minimum number of runs to be considered a candidate

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
    # `missing` for tcx_files triggers Neo4j fetch. `add_features` is false as data is already processed.
    graph, all_gps_data, paths, paths_files = TCX2Graph.create_property_graph(missing, false)
    num_rides = length(paths)
    println("Loaded data for $num_rides rides.")

    if num_rides == 0
        println("No rides found. Exiting.")
        return
    end

    # 3. Find all overlapping segments using an optimized approach
    all_found_segments = []
    println("Searching for $SEGMENT_LENGTH_M-meter segments across all rides...")

    # --- OPTIMIZATION: Find the best reference ride first ---
    best_ref_ride_idx = TCX2Graph.find_best_ref_ride(
        all_gps_data,
        paths,
        grid_size_m=50.0,
        min_reps_for_hotspot=MIN_REPETITIONS
    )
    ref_ride_filename = paths_files[paths[best_ref_ride_idx]]
    println("Using single best reference ride: #$best_ref_ride_idx ('$ref_ride_filename')")

    try
        segments, _ = TCX2Graph.find_overlapping_segments(
            all_gps_data,
            paths,
            ref_ride_idx=best_ref_ride_idx,
            max_length_m=SEGMENT_LENGTH_M,
            tol_m=FRECHET_TOLERANCE_M,
            min_runs=MIN_REPETITIONS,
            window_step=10, # Use a larger step to speed up, can be 1 for full detail
            prefilter_margin_m=100.0,
            dedup_overlap_frac=0.5
        )
        if !isempty(segments)
            # Add reference ride info to each segment
            for seg in segments
                seg["ref_ride_idx"] = best_ref_ride_idx
            end
            push!(all_found_segments, segments...)
        end
    catch e
        println("Could not process ride $best_ref_ride_idx as reference: $e")
    end


    if isempty(all_found_segments)
        println("No repeated segments found with at least $MIN_REPETITIONS repetitions. Try lowering the threshold.")
        return
    end

    println("Found $(length(all_found_segments)) candidate segments in total.")
    println("Identifying the most repeated segment(s)...")

    # 4. Find the segment with the maximum number of runs
    sort!(all_found_segments, by = s -> length(s["run_ranges"]), rev=true)

    if isempty(all_found_segments)
        println("Could not identify a top segment.")
        return
    end

    max_runs = length(all_found_segments[1]["run_ranges"])
    println("Top segment candidate has $max_runs repetitions. Filtering for similar top segments.")

    top_segments = [all_found_segments[1]]
    for seg in all_found_segments[2:end]
        if length(seg["run_ranges"]) < max_runs
            break # Since it's sorted, no more segments will have max_runs
        end

        is_duplicate = false
        for existing_seg in top_segments
            # Use Frechet distance to check if they are geometrically similar
            df = TCX2Graph.discrete_frechet(seg["candidate_polyline"], existing_seg["candidate_polyline"])
            if df <= FRECHET_TOLERANCE_M
                is_duplicate = true
                break
            end
        end
        if !is_duplicate
            push!(top_segments, seg)
        end
    end


    println("Found $(length(top_segments)) unique top segment(s) with $max_runs repetitions.")

    # 5. Save results to CSV
    csv_path = joinpath(csv_dir, "top_segments_summary.csv")
    df_rows = []
    for (i, seg) in enumerate(top_segments)
        start_pt_idx = first(seg["ref_range"])
        end_pt_idx = last(seg["ref_range"])
        start_gps = all_gps_data[start_pt_idx]
        end_gps = all_gps_data[end_pt_idx]
        ref_ride_path_range = paths[seg["ref_ride_idx"]]

        push!(df_rows, (
            segment_id = i,
            repetitions = max_runs,
            length_m = seg["candidate_length"],
            start_lat = start_gps["latitude"],
            start_lon = start_gps["longitude"],
            end_lat = end_gps["latitude"],
            end_lon = end_gps["longitude"],
            ref_file = paths_files[ref_ride_path_range]
        ))
    end
    df = DataFrame(df_rows)
    CSV.write(csv_path, df)
    println("Saved top segment(s) info to: $csv_path")

    # 6. Generate visualizations and detailed CSVs
    for (i, seg) in enumerate(top_segments)
        # Generate visualization
        vis_path = joinpath(vis_dir, "segment_$(i)_runs.html")
        println("Visualizing segment $i with $max_runs runs at: $vis_path")
        try
            TCX2Graph.visualize_segment_runs(
                seg,
                all_gps_data,
                paths_files,
                output_path=vis_path
            )
        catch e
            println("Failed to visualize segment $i: $e")
        end

        # Generate detailed CSV for the segment
        csv_detail_path = joinpath(csv_dir, "segment_$(i)_runs_details.csv")
        println("Exporting detailed runs for segment $i to: $csv_detail_path")
        try
            TCX2Graph.process_segment_runs(seg, all_gps_data, csv_detail_path)
        catch e
            println("Failed to export CSV for segment $i: $e")
        end
    end

    println("--- Case Study 1 Finished ---")
end

# --- Run the script ---
find_most_repeated_segments()
