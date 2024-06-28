using Graphs

function create_property_graph(tcx_files::Vector{String})
    graph = SimpleGraph()
    all_gps_data = Dict{Int, Dict{String, Any}}()  
    paths = Vector{UnitRange{Int64}}()  

    for (index, tcx_file_path) in enumerate(tcx_files)
        gps_points = read_tcx_gps_points(tcx_file_path)

        start_index = nv(graph) + 1
        add_vertices!(graph, length(gps_points))
        for i in 1:length(gps_points) - 1
            add_edge!(graph, start_index + i - 1, start_index + i)
        end

        for (i, gps) in enumerate(gps_points)
            vertex_index = start_index + i - 1
            all_gps_data[vertex_index] = gps  
        end

        push!(paths, start_index:(start_index + length(gps_points) - 1))
    end

    return graph, all_gps_data, paths
end
