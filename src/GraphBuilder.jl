# GraphBuilder.jl
# This file provides functions to create a property graph from TCX files.

using Graphs

"""
    create_property_graph(tcx_files::Vector{String}) -> (SimpleGraph, Dict{Int, Dict{String, Any}}, Vector{UnitRange{Int64}})

Create a property graph from a list of TCX files. Each vertex in the graph represents a GPS point with associated properties,
and edges connect consecutive GPS points within each file. The function returns the graph, a dictionary of GPS data with properties,
and a vector of paths representing the ranges of vertices for each TCX file.

# Arguments
- `tcx_files::Vector{String}`: A vector of file paths to the TCX files.

# Returns
- `SimpleGraph`: A graph where each vertex represents a GPS point and edges connect consecutive points.
- `Dict{Int, Dict{String, Any}}`: A dictionary where the key is a vertex index and the value is a dictionary of GPS properties.
- `Vector{UnitRange{Int64}}`: A vector of ranges, each representing the indices of vertices for a specific TCX file.
"""
function create_property_graph(tcx_files::Vector{String})
    graph = SimpleGraph()
    all_gps_data = Dict{Int, Dict{String, Any}}()  # Stores properties for each vertex
    paths = Vector{UnitRange{Int64}}()  # Stores ranges of vertices for each TCX file

    for (index, tcx_file_path) in enumerate(tcx_files)
        gps_points = read_tcx_gps_points(tcx_file_path)

        start_index = nv(graph) + 1
        add_vertices!(graph, length(gps_points))
        for i in 1:length(gps_points) - 1
            add_edge!(graph, start_index + i - 1, start_index + i)
        end

        for (i, gps) in enumerate(gps_points)
            vertex_index = start_index + i - 1
            all_gps_data[vertex_index] = gps  # Store all properties
        end

        push!(paths, start_index:(start_index + length(gps_points) - 1))
    end

    return graph, all_gps_data, paths
end
