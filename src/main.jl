using TCXReader, Graphs, GraphPlot, Compose, Cairo, Fontconfig

function read_tcx_gps_points(tcx_file_path)
    author, activities = loadTCXFile(tcx_file_path)
    trackpoints = []

    for activity in activities
        for lap in activity.laps
            for trackpoint in lap.trackPoints
                if !isnothing(trackpoint.latitude) && !isnothing(trackpoint.longitude)
                    push!(trackpoints, (trackpoint.latitude, trackpoint.longitude))
                    println("Latitude: ", trackpoint.latitude, ", Longitude: ", trackpoint.longitude)
                end
            end
        end
    end

    return trackpoints
end

# Function to create and plot a graph from GPS points
function create_and_plot_graph(gps_points)
    g = Graph(length(gps_points))  # Each GPS point is a vertex

    # Add edges between consecutive GPS points
    for i in 1:length(gps_points) - 1
        add_edge!(g, i, i + 1)
    end

    # Custom layout function that maps each vertex index to its GPS coordinate
    latitudes = [pt[1] for pt in gps_points]
    longitudes = [pt[2] for pt in gps_points]
    custom_layout = (g -> (x = longitudes, y = latitudes))

    # Plot the graph using the custom layout
    plot = gplot(g, layout=custom_layout)

    # Save the plot to a file
    draw(PNG("graph_plot.png", 16cm, 12cm), plot)
end

function main()
    tcx_file_path = "../example_data/15.tcx"
    gps_points = read_tcx_gps_points(tcx_file_path)

    create_and_plot_graph(gps_points)
end

main()