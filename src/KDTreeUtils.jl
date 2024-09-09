# KDTreeUtils.jl
# This file provides functions to create a KD-tree index from GPS data and find overlapping segments using the KD-tree.

using NearestNeighbors
using StaticArrays

"""
    gps_to_point(gps::Dict{String, Any}) -> SVector{2, Float64}

Convert GPS data into a point for KD-tree insertion.

# Arguments
- `gps::Dict{String, Any}`: A dictionary containing the latitude and longitude of a GPS point.

# Returns
- An `SVector` point representing the GPS coordinate.
"""
function gps_to_point(gps::Dict{String, Any})
    lat = gps["latitude"]
    lon = gps["longitude"]
    return SVector(lon, lat)
end

"""
    create_kdtree_index(all_gps_data::Dict{Int, Dict{String, Any}}) -> KDTree{Float64, 2}

Create a KD-tree index from GPS data for efficient spatial querying.

# Arguments
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary where the key is a vertex index and the value is a dictionary of GPS properties.

# Returns
- `KDTree{Float64, 2}`: A KDTree that indexes the GPS points for efficient spatial querying.
"""
function create_kdtree_index(all_gps_data::Dict{Int, Dict{String, Any}})
    points = [SVector{2, Float64}(gps["longitude"], gps["latitude"]) for gps in values(all_gps_data)]  # Ensure 2D vectors
    return KDTree(points)
end

"""
    find_overlapping_segments_kdtree(all_gps_data::Dict{Int, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, kdtree::KDTree{Float64, 2}) -> Vector{Tuple{Int, Int}}

Find overlapping segments between paths using the KD-tree.

# Arguments
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary of GPS data with properties.
- `paths::Vector{UnitRange{Int64}}`: A vector of ranges representing the indices of vertices for each TCX file.
- `kdtree::KDTree{Float64, 2}`: The KDTree index for efficient spatial querying.

# Returns
- `Vector{Tuple{Int, Int}}`: A vector of tuples, each representing an overlapping segment between two paths.
"""
function find_overlapping_segments_kdtree(all_gps_data::Dict{Int, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, kdtree)
    overlap_segments = []

    for i in 1:length(paths)-1
        for j in i+1:length(paths)
            path1 = paths[i]
            path2 = paths[j]

            segment_start = nothing
            segment_end = nothing

            for idx1 in path1
                gps1 = gps_to_point(all_gps_data[idx1])
                candidates = inrange(kdtree, gps1, 0.0001)  # Searching nearby points within tolerance (11 meters)
                for idx2 in candidates
                    if idx2 in path2 && is_same_location(all_gps_data[idx1], all_gps_data[idx2])
                        if segment_start === nothing
                            segment_start = (idx1, idx2)
                        end
                        segment_end = (idx1, idx2)
                    elseif segment_start !== nothing && segment_end !== nothing
                        push!(overlap_segments, (segment_start, segment_end))
                        segment_start = nothing
                        segment_end = nothing
                    end
                end
            end
            if segment_start !== nothing && segment_end !== nothing
                push!(overlap_segments, (segment_start, segment_end))
            end
        end
    end

    return Vector{Tuple{Tuple{Int64, Int64}, Tuple{Int64, Int64}}}(overlap_segments)
end

"""
    is_same_location(gps1::Dict{String, Any}, gps2::Dict{String, Any}; tolerance=0.0001) -> Bool

Check if two GPS points are the same based on their latitude and longitude.

# Arguments
- `gps1::Dict{String, Any}`: The first GPS point dictionary.
- `gps2::Dict{String, Any}`: The second GPS point dictionary.
- `tolerance::Float64=0.0001`: The tolerance within which the points are considered the same.

# Returns
- `Bool`: `true` if the two points are considered the same, `false` otherwise.
"""
function is_same_location(gps1::Dict{String, Any}, gps2::Dict{String, Any}; tolerance=0.0001)  # 11m
    lat1 = gps1["latitude"]
    lon1 = gps1["longitude"]
    lat2 = gps2["latitude"]
    lon2 = gps2["longitude"]

    return abs(lat1 - lat2) < tolerance && abs(lon1 - lon2) < tolerance
end
