export SegmentCacheRecord, build_segment_cache_metadata, save_segment_cache,
       load_segment_cache, cache_parameters_match, build_segment_adjacency,
       PropertyGraphCacheRecord, save_property_graph_cache, load_property_graph_cache

using Dates
using JLD2

const SEGMENT_CACHE_VERSION = v"1.0.0"

"""
    SegmentCacheRecord

Opaque container returned by [`load_segment_cache`](@ref) that bundles the metadata,
stored overlapping segments, the indices of rides that were close to the reference ride,
and (optionally) a pre-computed adjacency list that can be fed directly into path
search routines.
"""
struct SegmentCacheRecord
    metadata::Dict{String, Any}
    segments::Vector{Dict{String, Any}}
    close_ride_indices::Vector{Int}
    adjacency::Union{Nothing, Vector{Vector{Int}}}
end

"""
    PropertyGraphCacheRecord

Container returned by [`load_property_graph_cache`](@ref) that bundles the property
graph components needed by the analysis pipeline. The record captures the graph
structure, vertex properties, per-ride vertex ranges, and the original file mapping,
plus light metadata describing how the cache was produced.
"""
struct PropertyGraphCacheRecord
    metadata::Dict{String, Any}
    graph::Any
    gps_data::Dict{Int, Dict{String, Any}}
    paths::Vector{UnitRange{Int64}}
    paths_files::Dict{UnitRange{Int64}, String}
end

"""
    build_segment_cache_metadata(; kwargs...) -> Dict{String, Any}

Helper that produces a metadata dictionary describing a persisted set of overlapping
segments. Supplying the metadata explicitly keeps cache files self-describing and makes
it easy to decide whether an on-disk cache matches the configuration of the current run.

# Keyword Arguments
- `ref_ride_idx::Int`: Index of the reference ride used for segment detection.
- `ref_filename::Union{Nothing,String}`: Optional filename of the reference ride.
- `data_source::Symbol`: Where the underlying data came from (e.g. `:neo4j`).
- `parameters::NamedTuple`: Parameter values used during detection
  (`(; max_length_m, tol_m, min_runs, ... )`).
- `segment_count::Integer`: Number of overlapping segments stored.
- `close_ride_count::Integer`: Number of rides that passed the broad-phase filter.
- `notes::Union{Nothing,String}`: Free-form description.
- `extra::Dict{String,Any}`: Additional metadata entries to merge into the result.
"""
function build_segment_cache_metadata(;
    ref_ride_idx::Int,
    ref_filename::Union{Nothing,String}=nothing,
    data_source::Symbol=:unknown,
    parameters::NamedTuple=NamedTuple(),
    segment_count::Integer=-1,
    close_ride_count::Integer=-1,
    notes::Union{Nothing,String}=nothing,
    extra::Dict{String,Any}=Dict{String,Any}()
)::Dict{String, Any}
    metadata = Dict{String, Any}(
        "schema_version" => string(SEGMENT_CACHE_VERSION),
        "created_at_utc" => Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "ref_ride_idx" => ref_ride_idx,
        "ref_filename" => ref_filename,
        "data_source" => String(data_source),
        "segment_count" => Int(segment_count),
        "close_ride_count" => Int(close_ride_count),
        "parameters" => Dict(String(k) => v for (k, v) in pairs(parameters))
    )

    if !isnothing(notes)
        metadata["notes"] = notes
    end

    for (k, v) in extra
        metadata[k] = v
    end

    return metadata
end

function _inject_cache_defaults!(metadata::Dict{String,Any}, segments::Vector{Dict{String,Any}}, close_ride_indices::Vector{Int})
    metadata["schema_version"] = get(metadata, "schema_version", string(SEGMENT_CACHE_VERSION))
    metadata["segment_count"] = get(metadata, "segment_count", length(segments))
    metadata["close_ride_count"] = get(metadata, "close_ride_count", length(close_ride_indices))
    metadata
end

"""
    save_segment_cache(file_path, segments, close_ride_indices; kwargs...)

Persist the expensive output of `find_overlapping_segments` to disk in a binary JLD2
file so that it can be re-loaded instantly in later sessions.

# Arguments
- `file_path::AbstractString`: Destination file path (directories are created if needed).
- `segments::Vector{Dict{String,Any}}`: Result of `find_overlapping_segments`.
- `close_ride_indices::Vector{Int}`: Rides that were deemed close to the reference ride.

# Keyword Arguments
- `metadata::Union{Nothing,Dict{String,Any}}`: Metadata created via
  [`build_segment_cache_metadata`](@ref). Defaults to a minimal auto-generated dictionary.
- `adjacency::Union{Nothing,Vector{Vector{Int}}}`: Optional adjacency list (for path search).
- `force::Bool=false`: Overwrite existing files when `true`.
"""
function save_segment_cache(
    file_path::AbstractString,
    segments::Vector{Dict{String,Any}},
    close_ride_indices::Vector{Int};
    metadata::Union{Nothing,Dict{String,Any}}=nothing,
    adjacency::Union{Nothing,Vector{Vector{Int}}}=nothing,
    force::Bool=false
)
    if isfile(file_path) && !force
        error("Cache file already exists at $(file_path). Pass force=true to overwrite.")
    end

    cache_metadata = isnothing(metadata) ? Dict{String,Any}() : deepcopy(metadata)
    _inject_cache_defaults!(cache_metadata, segments, close_ride_indices)

    out_dir = dirname(file_path)
    if !isempty(out_dir) && !isdir(out_dir)
        mkpath(out_dir)
    end

    @save file_path cache_metadata segments close_ride_indices adjacency

    return file_path
end

"""
    load_segment_cache(file_path::AbstractString) -> SegmentCacheRecord

Load a previously persisted set of overlapping segments and validate that the schema
version is compatible with this build of the package.
"""
function load_segment_cache(file_path::AbstractString)::SegmentCacheRecord
    if !isfile(file_path)
        error("Cache file not found at $(file_path)")
    end

    raw = JLD2.load(file_path)

    if !haskey(raw, "cache_metadata") || !haskey(raw, "segments") || !haskey(raw, "close_ride_indices")
        error("Cache file $(file_path) is missing required keys.")
    end

    metadata = raw["cache_metadata"]
    segments = raw["segments"]
    close_ride_indices = raw["close_ride_indices"]
    adjacency = get(raw, "adjacency", nothing)

    version_str = get(metadata, "schema_version", "0.0.0")
    cached_version = VersionNumber(version_str)
    if cached_version > SEGMENT_CACHE_VERSION
        error("Cache schema version $(version_str) is newer than supported $(SEGMENT_CACHE_VERSION).")
    end

    return SegmentCacheRecord(metadata, segments, close_ride_indices, adjacency)
end

"""
    save_property_graph_cache(file_path, graph, gps_data, paths, paths_files; metadata=nothing, force=false)

Persist the property-graph components needed for downstream analysis to disk so the
pipeline can skip expensive re-ingestion of TCX/Neo4j data.
"""
function save_property_graph_cache(
    file_path::AbstractString,
    graph,
    gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int}},
    paths_files::Dict{UnitRange{Int}, String};
    metadata::Union{Nothing,Dict{String,Any}}=nothing,
    force::Bool=false
)
    if isfile(file_path) && !force
        error("Graph cache already exists at $(file_path). Pass force=true to overwrite.")
    end

    graph_metadata = isnothing(metadata) ? Dict{String,Any}() : deepcopy(metadata)
    graph_metadata["created_at_utc"] = get(
        graph_metadata, "created_at_utc",
        Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    )

    out_dir = dirname(file_path)
    if !isempty(out_dir) && !isdir(out_dir)
        mkpath(out_dir)
    end

    @save file_path graph_metadata graph gps_data paths paths_files compress=true

    return file_path
end

"""
    load_property_graph_cache(file_path) -> PropertyGraphCacheRecord

Load a previously cached property graph and return its components.
"""
function load_property_graph_cache(file_path::AbstractString)::PropertyGraphCacheRecord
    if !isfile(file_path)
        error("Graph cache not found at $(file_path).")
    end

    raw = JLD2.load(file_path)
    for key in ("graph_metadata", "graph", "gps_data", "paths", "paths_files")
        haskey(raw, key) || error("Graph cache $(file_path) is missing required key '$(key)'.")
    end

    metadata = raw["graph_metadata"]
    graph = raw["graph"]
    gps_data = raw["gps_data"]
    paths = raw["paths"]
    paths_files = raw["paths_files"]

    return PropertyGraphCacheRecord(metadata, graph, gps_data, paths, paths_files)
end

"""
    cache_parameters_match(metadata::Dict{String,Any}, parameters::NamedTuple) -> Bool

Quick utility that compares the parameter block stored in cache metadata with the
parameters of the current run. This helps deciding whether a cache can be reused.
"""
function cache_parameters_match(metadata::Dict{String,Any}, parameters::NamedTuple)::Bool
    cached_params = get(metadata, "parameters", Dict{String,Any}())
    for (k, v) in pairs(parameters)
        cached_value = get(cached_params, String(k), nothing)
        if cached_value !== v
            return false
        end
    end
    return true
end

"""
    build_segment_adjacency(overlap_segments; min_runs=2, tolerance_m=50.0)
        -> Vector{Vector{Int}}

Construct a simple adjacency list (direction-aware) using only the stored
`candidate_polyline` coordinates. The output mirrors the layout used by
`find_path_between_segments`: the first `N` entries represent segments in the forward
direction, and the next `N` entries represent them in the reversed direction.
"""
function build_segment_adjacency(
    overlap_segments::Vector{Dict{String,Any}};
    min_runs::Int=2,
    tolerance_m::Float64=50.0
)
    num_segments = length(overlap_segments)
    adjacency = [Int[] for _ in 1:(2 * num_segments)]

    seg_ori_to_node(idx, orientation) = orientation === :forward ? idx : idx + num_segments

    endpoints = map(overlap_segments) do segment
        polyline = get(segment, "candidate_polyline", nothing)
        if isnothing(polyline) || isempty(polyline)
            error("Segment cache is missing candidate_polyline data required for adjacency computation.")
        end
        start_pt = polyline[1]
        end_pt = polyline[end]
        return (
            start_lat = start_pt[2],
            start_lon = start_pt[1],
            end_lat = end_pt[2],
            end_lon = end_pt[1]
        )
    end

    for i in 1:num_segments
        if length(overlap_segments[i]["run_ranges"]) < min_runs
            continue
        end

        for j in 1:num_segments
            if i == j || length(overlap_segments[j]["run_ranges"]) < min_runs
                continue
            end

            coords_i = endpoints[i]
            coords_j = endpoints[j]

            if haversine_distance(coords_i.end_lat, coords_i.end_lon, coords_j.start_lat, coords_j.start_lon) <= tolerance_m
                push!(adjacency[seg_ori_to_node(i, :forward)], seg_ori_to_node(j, :forward))
            end
            if haversine_distance(coords_i.end_lat, coords_i.end_lon, coords_j.end_lat, coords_j.end_lon) <= tolerance_m
                push!(adjacency[seg_ori_to_node(i, :forward)], seg_ori_to_node(j, :reversed))
            end
            if haversine_distance(coords_i.start_lat, coords_i.start_lon, coords_j.start_lat, coords_j.start_lon) <= tolerance_m
                push!(adjacency[seg_ori_to_node(i, :reversed)], seg_ori_to_node(j, :forward))
            end
            if haversine_distance(coords_i.start_lat, coords_i.start_lon, coords_j.end_lat, coords_j.end_lon) <= tolerance_m
                push!(adjacency[seg_ori_to_node(i, :reversed)], seg_ori_to_node(j, :reversed))
            end
        end
    end

    return adjacency
end
