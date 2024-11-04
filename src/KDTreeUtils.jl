using NearestNeighbors
using StaticArrays
using Base.Threads
using LinearAlgebra

overlap_segments_lock = ReentrantLock()
segment_map_lock = ReentrantLock()

"""
    gps_to_point(gps::Dict{String, Any}) -> SVector{2, Float64}

Converts GPS data into a 2D point (latitude, longitude) for KD-tree insertion.

# Arguments
- `gps::Dict{String, Any}`: A dictionary containing GPS properties, particularly latitude and longitude.

# Returns
- `SVector{2, Float64}`: A 2D static vector where the first element is longitude and the second is latitude, representing the GPS point.

# Details
This function extracts the `latitude` and `longitude` from the provided GPS data and returns them as a static 2D vector (`SVector`),
suitable for use in a KD-tree for spatial queries.
"""
function gps_to_point(gps::Dict{String, Any})
    lat = gps["latitude"]
    lon = gps["longitude"]
    return SVector(lon, lat)
end

"""
    create_kdtree_index(all_gps_data::Dict{Int, Dict{String, Any}}) -> KDTree{Float64, 2}

Creates a KD-tree index from GPS data for efficient spatial queries.

# Arguments
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary where the key is the index of a GPS point, and the value is a dictionary of GPS properties, particularly latitude and longitude.

# Returns
- `KDTree{Float64, 2}`: A KD-tree where each node represents a 2D point (longitude, latitude) that can be used for spatial queries.

# Details
This function takes all the GPS data, extracts the `longitude` and `latitude` from each point, and constructs a KD-tree to enable
efficient nearest-neighbor searches.
"""
function create_kdtree_index(all_gps_data::Dict{Int, Dict{String, Any}})
    points = [SVector{2, Float64}(gps["longitude"], gps["latitude"]) for gps in values(all_gps_data)]
    return KDTree(points)
end

"""
    find_overlapping_segments_across_paths(all_gps_data::Dict{Int, Dict{String, Any}},
                                           paths::Vector{UnitRange{Int64}},
                                           kdtree::KDTree{Float64, 2};
                                           max_gap::Float64=0.0015,
                                           min_segment_length::Int=3,
                                           segment_gap_tolerance::Int=5)
                                           -> Vector{Dict{String, Any}}

Finds overlapping GPS segments across multiple paths using a KD-tree for efficient spatial queries and associates them with
the paths in which they appear.

# Arguments
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data with properties for each GPS point, particularly latitude and longitude.
- `paths::Vector{UnitRange{Int64}}`: A vector representing ranges of GPS indices for each path (e.g., from TCX files).
- `kdtree::KDTree{Float64, 2}`: A KD-tree built from GPS points for efficient nearest-neighbor searches.
- `max_gap::Float64`: Maximum allowed distance (in degrees) between consecutive points in an overlapping segment.
- `min_segment_length::Int`: Minimum number of points required to consider an overlapping segment valid.
- `segment_gap_tolerance::Int`: Maximum number of consecutive non-overlapping points allowed before the segment is ended.

# Returns
- `Vector{Dict{String, Any}}`: A vector of dictionaries representing overlapping segments, each containing the start and end indices of the segment
  and the paths in which the segment appears.

# Details
This function finds overlapping GPS segments across different paths using spatial proximity queries via a KD-tree. Segments are
formed by identifying GPS points that are spatially close across different paths and satisfy the gap and length criteria. Each
identified segment is returned as a dictionary, including the start and end indices of the segment and the list of paths that overlap.
"""
function find_overlapping_segments_across_paths(
    all_gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    kdtree;
    max_gap::Float64=0.0015,
    min_segment_length::Int=3,
    segment_gap_tolerance::Int=5
) :: Vector{Dict{String, Any}}
    overlap_segments = Vector{Dict{String, Any}}()
    segment_map = Dict{Tuple{Int, Int}, Set{Int}}()

    @threads for path_idx in 1:length(paths)
        local_segments = Vector{Dict{String, Any}}()
        local_segment_map = Dict{Tuple{Int, Int}, Set{Int}}()

        path = paths[path_idx]
        segment_start = nothing
        current_segment = []
        gap_count = 0
        overlapping_paths = Set{Int}()

        for idx in path
            gps1 = gps_to_point(all_gps_data[idx])
            candidates = inrange(kdtree, gps1, max_gap)

            found_overlap = false

            for candidate_idx in candidates
                if candidate_idx in path
                    continue
                end

                for other_path_idx in 1:length(paths)
                    other_path = paths[other_path_idx]
                    if candidate_idx in other_path && other_path_idx != path_idx
                        if is_same_location(all_gps_data[idx], all_gps_data[candidate_idx]; tolerance=max_gap)
                            found_overlap = true
                            gap_count = 0
                            overlapping_paths = union(overlapping_paths, Set([path_idx, other_path_idx]))

                            if segment_start === nothing
                                segment_start = idx
                            end

                            push!(current_segment, idx)

                            segment_key = (segment_start, idx)

                            if haskey(local_segment_map, segment_key)
                                push!(local_segment_map[segment_key], path_idx)
                            else
                                local_segment_map[segment_key] = overlapping_paths
                            end
                        end
                    end
                end
            end

            if !found_overlap
                gap_count += 1
                if gap_count > segment_gap_tolerance
                    if length(current_segment) >= min_segment_length && length(overlapping_paths) > 1
                        push!(local_segments, Dict("start_idx" => segment_start,
                                                   "end_idx" => current_segment[end],
                                                   "paths" => copy(overlapping_paths)))
                    end
                    segment_start = nothing
                    current_segment = []
                    gap_count = 0
                    overlapping_paths = Set{Int}()
                end
            end
        end

        if length(current_segment) >= min_segment_length && length(overlapping_paths) > 1
            push!(local_segments, Dict("start_idx" => segment_start,
                                       "end_idx" => current_segment[end],
                                       "paths" => copy(overlapping_paths)))
        end

        lock(overlap_segments_lock) do
            append!(overlap_segments, local_segments)
        end
        lock(segment_map_lock) do
            for (key, value) in local_segment_map
                if haskey(segment_map, key)
                    union!(segment_map[key], value)
                else
                    segment_map[key] = value
                end
            end
        end
    end

    unique_segments = Dict{Tuple{Int, Int}, Dict{String, Any}}()
    for segment in overlap_segments
        key = (segment["start_idx"], segment["end_idx"])
        if !haskey(unique_segments, key)
            unique_segments[key] = segment
        end
    end

    result = collect(values(unique_segments))
    if isempty(result)
        throw(ErrorException("No overlapping segments found"))
    end

    return result
end

"""
    is_same_location(gps1::Dict{String, Any}, gps2::Dict{String, Any}; tolerance=0.0015) -> Bool

Determines if two GPS points are within a specified Euclidean distance tolerance.

# Arguments
- `gps1::Dict{String, Any}`: A dictionary containing latitude and longitude for the first GPS point.
- `gps2::Dict{String, Any}`: A dictionary containing latitude and longitude for the second GPS point.
- `tolerance::Float64`: The maximum Euclidean distance allowed between the two points for them to be considered close.

# Returns
- `Bool`: Returns `true` if the Euclidean distance between the points is within the specified tolerance, `false` otherwise.

# Details
This function calculates the Euclidean distance between the `longitude` and `latitude` coordinates of two GPS points.
It returns `true` if the distance is within the given tolerance, making it suitable for spatial proximity checks.
"""
function is_same_location(gps1::Dict{String, Any}, gps2::Dict{String, Any}; tolerance=0.0015)
    point1 = SVector(gps1["longitude"], gps1["latitude"])
    point2 = SVector(gps2["longitude"], gps2["latitude"])
    return euclidean_distance(point1, point2) <= tolerance
end

