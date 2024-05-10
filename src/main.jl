using TCXReader, Graphs, Plots

# Function to read GPS points from a TCX file
function read_tcx_gps_points(tcx_file_path)
    author, activities = loadTCXFile(tcx_file_path)
    trackpoints = []

    # Extract GPS coordinates from each activity, lap, and trackpoint
    for activity in activities
        for lap in activity.laps
            for trackpoint in lap.trackPoints
                if !isnothing(trackpoint.latitude) && !isnothing(trackpoint.longitude)
                    push!(trackpoints, (trackpoint.latitude, trackpoint.longitude))
                end
            end
        end
    end

    return trackpoints
end

# Create a property graph structure with attributes
function create_property_graph(tcx_files)
   
    graph = SimpleGraph()
    all_gps_data = Dict{Int, Tuple{Float64, Float64}}()  
    paths = []

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

# Function to visualize the graph with Plots
function plot_property_graph(graph, gps_data, paths)
    colors = [:red, :blue, :green, :orange, :purple, :cyan]
    p = plot(title="Multiple TCX Paths (Property Graph)", xlabel="Longitude", ylabel="Latitude")

    # Group paths and plot them separately
    path_index = 1
    for path in paths
        color = colors[(path_index - 1) % length(colors) + 1]
        longs, lats = [], []

        for vertex in path
            coord = gps_data[vertex]
            push!(longs, coord[2])
            push!(lats, coord[1])
        end

        plot!(p, longs, lats, color=color, label="Path $path_index", lw=2)
        path_index += 1
    end

    savefig(p, "multi_tcx_graph_property.png")
end

function main()
    tcx_files = [
        "../example_data/activity_12163012156.tcx",
        "../example_data/activity_12171312300.tcx",
        "../example_data/activity_12186252814.tcx",
        "../example_data/activity_12270580292.tcx",
        "../example_data/activity_12381259800.tcx"
    ]

    # Create the property graph
    graph, gps_data, paths = create_property_graph(tcx_files)

    # Visualize the graph
    plot_property_graph(graph, gps_data, paths)
end

main()
