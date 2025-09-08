using Graphs
using MetaGraphs  # added to enable metadata-aware graphs

export create_property_graph

"""
    create_property_graph(tcx_files::Vector{String})
    -> (SimpleGraph, Dict{Int, Dict{String, Any}}, Vector{UnitRange{Int64}})

Creates a property graph from a list of TCX files. Each vertex in the graph represents a GPS point with associated properties
(e.g., latitude, longitude, speed, etc.), and edges connect consecutive GPS points from the same TCX file. The function
returns the graph, a dictionary of GPS data with properties for each vertex, and a vector of paths representing ranges of vertices
for each TCX file.

# Arguments
- `tcx_files::Vector{String}`: A vector containing file paths to the TCX files to be processed.

# Returns
- `SimpleGraph`: A graph where each vertex represents a GPS point, and edges represent consecutive points within each path.
- `Dict{Int, Dict{String, Any}}`: A dictionary where the key is a vertex index and the value is a dictionary of properties
   (such as latitude, longitude, speed, etc.) for the corresponding GPS point.
- `Vector{UnitRange{Int64}}`: A vector of ranges, where each range corresponds to the indices of vertices for a specific TCX file.

# Details
This function processes each TCX file by reading the GPS points and creating a graph with vertices and edges. Each vertex
in the graph holds properties related to a GPS point, such as latitude, longitude, and other metrics. The edges connect
consecutive GPS points within each TCX file. The function also returns a dictionary containing the properties for each vertex
and a vector representing the vertex ranges for each path (i.e., each TCX file).

"""
function create_property_graph(tcx_files::Union{Vector{String}, Missing}, add_features::Bool=false)
    graph = MetaDiGraph(DiGraph(0))

    all_gps_data = Dict{Int, Dict{String, Any}}()
    paths = Vector{UnitRange{Int64}}()
    paths_files = Dict{UnitRange{Int64}, String}()

    use_neo4j = ismissing(tcx_files)

    if use_neo4j
        println("Fetching TCX filenames from Neo4j...")
        tcx_files = fetch_tcx_filenames_from_neo4j()

        if isempty(tcx_files)
            error("No TCX data available in Neo4j.")
        end
    end

    println("Processing $(length(tcx_files)) TCX files...")

    for (index, tcx_file_path) in enumerate(tcx_files)
        gps_points = use_neo4j ? fetch_gps_data_from_neo4j(tcx_file_path) :
                                 read_tcx_gps_points(tcx_file_path, add_features)

        if isnothing(gps_points) || isempty(gps_points)
            println("Skipping file: $tcx_file_path (No valid trackpoints).")
            continue
        end

        start_index = nv(graph) + 1
        for _ in 1:length(gps_points)
            add_vertex!(graph)
        end

        for i in 1:(length(gps_points)-1)
            add_edge!(graph, start_index + i - 1, start_index + i)
        end

        for (i, gps) in enumerate(gps_points)
            vertex_index = start_index + i - 1
            for (k, v) in gps
                try
                    set_prop!(graph, vertex_index, Symbol(k), v)
                catch
                    @warn "Failed to set property $k for vertex $vertex_index: $v"
                end
            end
            all_gps_data[vertex_index] = gps
        end

        push!(paths, start_index:(start_index + length(gps_points) - 1))
        paths_files[start_index:(start_index + length(gps_points) - 1)] = tcx_file_path
    end

    return graph, all_gps_data, paths, paths_files
end
