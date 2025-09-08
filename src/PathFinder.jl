export find_path_between_segments

segment_start(seg) = first(seg["ref_range"])
segment_end(seg) = last(seg["ref_range"])

"""
    find_path_between_segments(
        start_segment::Dict{String, Any},
        end_segment::Dict{String, Any},
        overlap_segments::Vector{Dict{String, Any}},
        all_gps_data::Dict{Int, Dict{String, Any}};
        min_length::Int=3,
        min_runs::Int=2,
        tolerance_m::Float64=50.0
    ) -> Vector{Dict{String, Any}}

Finds a directed path between two segments by connecting them head-to-tail. This version is direction-aware,
meaning it considers that segments can be traversed in a forward or reversed orientation to form a continuous path.

# Arguments
- `start_segment::Dict{String, Any}`: The starting segment dictionary.
- `end_segment::Dict{String, Any}`: The ending segment dictionary.
- `overlap_segments::Vector{Dict{String, Any}}`: A list of all detected overlapping segments to search through.
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary of all GPS data points.
- `min_length::Int`: The minimum number of segments required in the resulting path.
- `min_runs::Int`: The minimum number of paths in which each segment must appear to be considered.
- `tolerance_m::Float64`: The maximum distance in **meters** allowed between segment endpoints for them to be considered connected.

# Returns
- `Vector{Dict{String, Any}}`: A vector of dictionaries, each representing a segment in the path. Each segment includes an added
  `"segment_index"` field and a `"orientation"` field (`:forward` or `:reversed`).

# Throws
- `ErrorException`: If no valid path is found or if the path does not meet `min_length`.
"""
function find_path_between_segments(
    start_segment::Dict{String, Any},
    end_segment::Dict{String, Any},
    overlap_segments::Vector{Dict{String, Any}},
    all_gps_data::Dict{Int, Dict{String, Any}};
    min_length::Int=3,
    min_runs::Int=2,
    tolerance_m::Float64=50.0
) :: Vector{Dict{String, Any}}

    start_segment_index = findfirst(s -> s == start_segment, overlap_segments)
    end_segment_index = findfirst(s -> s == end_segment, overlap_segments)

    if isnothing(start_segment_index) throw(ErrorException("Start segment not found in overlap_segments")) end
    if isnothing(end_segment_index) throw(ErrorException("End segment not found in overlap_segments")) end

    num_segments = length(overlap_segments)

    endpoints = [
        (
            (all_gps_data[segment_start(s)]["latitude"], all_gps_data[segment_start(s)]["longitude"]),
            (all_gps_data[segment_end(s)]["latitude"], all_gps_data[segment_end(s)]["longitude"])
        ) for s in overlap_segments
    ]

    node_to_seg_ori(n) = n > num_segments ? (n - num_segments, :reversed) : (n, :forward)
    seg_ori_to_node(s, o) = o == :forward ? s : s + num_segments

    adj = [Int[] for _ in 1:(2*num_segments)]

    for i in 1:num_segments
        if length(overlap_segments[i]["run_ranges"]) < min_runs continue end

        for j in 1:num_segments
            if i == j continue end
            if length(overlap_segments[j]["run_ranges"]) < min_runs continue end

            start_i_coords, end_i_coords = endpoints[i]
            start_j_coords, end_j_coords = endpoints[j]

            if haversine_distance(end_i_coords..., start_j_coords...) <= tolerance_m
                push!(adj[seg_ori_to_node(i, :forward)], seg_ori_to_node(j, :forward))
            end
            if haversine_distance(end_i_coords..., end_j_coords...) <= tolerance_m
                push!(adj[seg_ori_to_node(i, :forward)], seg_ori_to_node(j, :reversed))
            end

            if haversine_distance(start_i_coords..., start_j_coords...) <= tolerance_m
                push!(adj[seg_ori_to_node(i, :reversed)], seg_ori_to_node(j, :forward))
            end
            if haversine_distance(start_i_coords..., end_j_coords...) <= tolerance_m
                push!(adj[seg_ori_to_node(i, :reversed)], seg_ori_to_node(j, :reversed))
            end
        end
    end

    q = [seg_ori_to_node(start_segment_index, :forward)]
    visited = falses(2 * num_segments)
    visited[q[1]] = true
    parent = zeros(Int, 2 * num_segments)

    path_found = false
    end_node = -1

    while !isempty(q)
        u_node = popfirst!(q)
        u_seg_idx, u_orientation = node_to_seg_ori(u_node)

        if u_seg_idx == end_segment_index
            path_found = true
            end_node = u_node
            break
        end

        for v_node in adj[u_node]
            if !visited[v_node]
                visited[v_node] = true
                parent[v_node] = u_node
                push!(q, v_node)
            end
        end
    end

    if !path_found
        throw(ErrorException("No valid directed path found between the two segments with tolerance $(tolerance_m)m"))
    end

    path_nodes = []
    curr = end_node
    while curr != 0
        pushfirst!(path_nodes, curr)
        curr = parent[curr]
    end

    if isempty(path_nodes) || node_to_seg_ori(path_nodes[1])[1] != start_segment_index
        throw(ErrorException("Path reconstruction failed"))
    end

    if length(path_nodes) < min_length
        throw(ErrorException("Path does not meet the minimum required length of $min_length segments (found $(length(path_nodes)))"))
    end

    path_segments = []
    for node in path_nodes
        seg_idx, orientation = node_to_seg_ori(node)
        segment_data = merge(
            overlap_segments[seg_idx],
            Dict("segment_index" => seg_idx, "orientation" => orientation)
        )
        push!(path_segments, segment_data)
    end

    return path_segments
end
