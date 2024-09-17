# KDTreeUtils.jl
# This file provides functions to create a KD-tree index from GPS data and find overlapping segments using the KD-tree.

using NearestNeighbors
using StaticArrays

"""
    gps_to_point(gps::Dict{String, Any}) -> SVector{2, Float64}

Convert GPS data into a point (latitude and longitude) for KD-tree insertion.

# Arguments
- `gps::Dict{String, Any}`: A dictionary containing GPS properties, particularly latitude and longitude.

# Returns
- `SVector{2, Float64}`: A 2D static vector representing the GPS point's longitude and latitude.
"""
function gps_to_point(gps::Dict{String, Any})
    lat = gps["latitude"]
    lon = gps["longitude"]
    return SVector(lon, lat)
end

"""
    create_kdtree_index(all_gps_data::Dict{Int, Dict{String, Any}}) -> KDTree{Float64, 2}

Create a KD-tree index from GPS data for efficient spatial queries.

# Arguments
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary where the key is the index of the GPS point, and the value is a dictionary of GPS properties.

# Returns
- `KDTree{Float64, 2}`: A KD-tree that can be used for spatial queries.
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

Find overlapping GPS segments across multiple paths using a KD-tree and associate them with the paths in which they appear.

# Arguments
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data with properties for each GPS point.
- `paths::Vector{UnitRange{Int64}}`: A vector representing ranges of GPS indices for each path (TCX file).
- `kdtree::KDTree{Float64, 2}`: A KD-tree for efficient spatial querying of GPS data.
- `max_gap::Float64`: Maximum allowed distance (in degrees) between consecutive points in an overlapping segment.
- `min_segment_length::Int`: Minimum number of points required to consider an overlapping segment valid.
- `segment_gap_tolerance::Int`: Maximum consecutive non-overlapping points allowed before a segment is ended.

# Returns
- `Vector{Dict{String, Any}}`: A vector of dictionaries where each dictionary represents an overlapping segment, including the start and end points and the paths it is found in.
"""
function find_overlapping_segments_across_paths(
    all_gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    kdtree;
    max_gap::Float64=0.0015,
    min_segment_length::Int=3,
    segment_gap_tolerance::Int=5
) :: Vector{Dict{String, Any}}
    # This will store segments with their associated paths
    overlap_segments = []

    # A mapping from segment identifiers to the paths they appear in
    segment_map = Dict{Tuple{Int, Int}, Set{Int}}()

    # Iterate over all paths
    for (path_idx, path) in enumerate(paths)
        segment_start = nothing
        current_segment = []
        gap_count = 0
        overlapping_paths = Set{Int}()  # Initialize here for each new segment

        for idx in path
            gps1 = gps_to_point(all_gps_data[idx])
            candidates = inrange(kdtree, gps1, max_gap)

            found_overlap = false

            # Check for overlaps in other paths
            for candidate_idx in candidates
                # Skip if candidate is in the same path
                if candidate_idx in path
                    continue
                end

                # Check if the candidate point is in a different path
                for (other_path_idx, other_path) in enumerate(paths)
                    if candidate_idx in other_path && other_path_idx != path_idx
                        if is_same_location(all_gps_data[idx], all_gps_data[candidate_idx]; tolerance=max_gap * 20)
                            found_overlap = true
                            gap_count = 0
                            overlapping_paths = union(overlapping_paths, Set([path_idx, other_path_idx]))

                            if segment_start === nothing
                                segment_start = idx
                            end

                            push!(current_segment, idx)

                            # Update the segment_map
                            segment_key = (segment_start, idx)
                            if haskey(segment_map, segment_key)
                                push!(segment_map[segment_key], path_idx)
                            else
                                segment_map[segment_key] = overlapping_paths
                            end
                        end
                    end
                end
            end

            if !found_overlap
                gap_count += 1
                if gap_count > segment_gap_tolerance
                    if length(current_segment) >= min_segment_length && length(overlapping_paths) > 1
                        # Add segment with associated paths
                        push!(overlap_segments, Dict("start_idx" => segment_start,
                                                     "end_idx" => current_segment[end],
                                                     "paths" => segment_map[(segment_start, current_segment[end])]))
                    end
                    segment_start = nothing
                    current_segment = []
                    gap_count = 0
                    overlapping_paths = Set{Int}()  # Reset paths set for new segment
                end
            end
        end

        # Handle any remaining segment at the end
        if length(current_segment) >= min_segment_length && length(overlapping_paths) > 1
            push!(overlap_segments, Dict("start_idx" => segment_start,
                                         "end_idx" => current_segment[end],
                                         "paths" => segment_map[(segment_start, current_segment[end])]))
        end
    end

    return overlap_segments
end

"""
    is_same_location(gps1::Dict{String, Any}, gps2::Dict{String, Any}; tolerance=0.0111) -> Bool

Determine if two GPS points are within a given tolerance of each other.

# Arguments
- `gps1::Dict{String, Any}`: The first GPS point dictionary containing latitude and longitude.
- `gps2::Dict{String, Any}`: The second GPS point dictionary containing latitude and longitude.
- `tolerance::Float64`: The allowed difference in latitude and longitude between two points for them to be considered the same.

# Returns
- `Bool`: Returns `true` if the points are within the specified tolerance, `false` otherwise.
"""
function is_same_location(gps1::Dict{String, Any}, gps2::Dict{String, Any}; tolerance=0.0111)
    lat1 = gps1["latitude"]
    lon1 = gps1["longitude"]
    lat2 = gps2["latitude"]
    lon2 = gps2["longitude"]

    return abs(lat1 - lat2) < tolerance && abs(lon1 - lon2) < tolerance
end
