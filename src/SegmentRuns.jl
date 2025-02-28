export extract_single_segment_runs

"""
    extract_single_segment_runs(segment::Dict{String, Any}, gps_data::Dict{Int, Dict{String, Any}})
    -> Vector{Dict{String, Any}}

Extracts raw run data for a single overlapping segment using precomputed "run_ranges".

# Arguments
- `segment`: A dictionary representing one overlapping segment. It must contain a key `"run_ranges"` mapping each ride index to a UnitRange of GPS indices.
- `gps_data`: A dictionary mapping global GPS point indices to their corresponding data.

# Returns
- A vector of dictionaries, each containing:
    - `"path_index"`: The ride index.
    - `"run_start"`: The starting global GPS index for that ride's run.
    - `"run_end"`: The ending global GPS index for that ride's run.
    - `"run_data"`: A vector of raw GPS trackpoints for that run.
    - `"tcx_file"`: The source TCX file name (if available).
"""
function extract_single_segment_runs(segment::Dict{String, Any}, gps_data::Dict{Int, Dict{String, Any}})
    runs = Vector{Dict{String, Any}}()
    run_ranges = segment["run_ranges"]
    for (path_index, run_range) in run_ranges
        run_data = [gps_data[idx] for idx in run_range if haskey(gps_data, idx)]
        if !isempty(run_data)
            tcx_file = haskey(run_data[1], "file_name") ? run_data[1]["file_name"] : "unknown"
            push!(runs, Dict(
                "path_index" => path_index,
                "run_start"  => first(run_range),
                "run_end"    => last(run_range),
                "run_data"   => run_data,
                "tcx_file"   => tcx_file
            ))
        end
    end
    return runs
end