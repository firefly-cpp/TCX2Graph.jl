using TCXReader, Graphs, GraphPlot, Compose, Cairo, Fontconfig

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

# Function to create and plot a graph from multiple GPS point paths
function create_and_plot_graph(tcx_files)
    graph = SimpleGraph()  # Use a simple graph to represent all paths
    all_coordinates = []  # Store all coordinates for custom layout
    paths = []  # Keep track of which GPS points belong to which path

    for (path_index, tcx_file_path) in enumerate(tcx_files)
        gps_points = read_tcx_gps_points(tcx_file_path)

        # Add vertices and edges for the current path
        start_index = nv(graph) + 1
        add_vertices!(graph, length(gps_points))
        for i in 1:length(gps_points) - 1
            add_edge!(graph, start_index + i - 1, start_index + i)
        end

        # Record coordinates and associate them with the graph vertices
        append!(all_coordinates, gps_points)
        push!(paths, start_index:(start_index + length(gps_points) - 1))
    end

    # Create a layout function that maps all graph nodes to their coordinates
    latitudes = [pt[1] for pt in all_coordinates]
    longitudes = [pt[2] for pt in all_coordinates]
    custom_layout = graph -> (x = longitudes, y = latitudes)

    # Plot the combined graph
    plot = gplot(graph, layout=custom_layout)
    draw(PNG("multi_tcx_graph.png", 16cm, 12cm), plot)
end

# Main function to specify multiple TCX files
function main()
    tcx_files = [
        "../example_data/activity_12163012156.tcx",
        "../example_data/activity_12171312300.tcx",
        "../example_data/activity_12186252814.tcx",
        "../example_data/activity_12270580292.tcx",
        "../example_data/activity_12381259800.tcx"
    ]  
    
    create_and_plot_graph(tcx_files)
end

main()