using TCXReader, Graphs, Plots, Statistics

# Function to read GPS points and additional properties from a TCX file
function read_tcx_gps_points(tcx_file_path)
    author, activities = loadTCXFile(tcx_file_path)
    trackpoints = []

    # Extract GPS coordinates and additional properties from each activity, lap, and trackpoint
    for activity in activities
        for lap in activity.laps
            for trackpoint in lap.trackPoints
                if !isnothing(trackpoint.latitude) && !isnothing(trackpoint.longitude)
                    properties = Dict(
                        "latitude" => trackpoint.latitude,
                        "longitude" => trackpoint.longitude,
                        "time" => trackpoint.time
                    )

                    # Add optional properties if they exist
                    if !isnothing(trackpoint.altitude_meters)
                        properties["altitude"] = trackpoint.altitude_meters
                    else
                        properties["altitude"] = missing
                    end
                    if !isnothing(trackpoint.distance_meters)
                        properties["distance"] = trackpoint.distance_meters
                    else
                        properties["distance"] = missing
                    end
                    if !isnothing(trackpoint.heart_rate_bpm)
                        properties["heart_rate"] = trackpoint.heart_rate_bpm
                    else
                        properties["heart_rate"] = missing
                    end
                    if !isnothing(trackpoint.speed)
                        properties["speed"] = trackpoint.speed
                    else
                        properties["speed"] = missing
                    end

                    push!(trackpoints, properties)
                end
            end
        end
    end

    return trackpoints
end

# Create a property graph structure with attributes
function create_property_graph(tcx_files)
    graph = SimpleGraph()
    all_gps_data = Dict{Int, Dict{String, Any}}()  # Stores properties for each vertex
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
            all_gps_data[vertex_index] = gps  # Store all properties
        end

        push!(paths, start_index:(start_index + length(gps_points) - 1))
    end

    return graph, all_gps_data, paths
end

function find_overlapping_points(gps_data)
    point_counts = Dict{Tuple{Float64, Float64}, Int}()
    for (_, properties) in gps_data
        coord = (properties["latitude"], properties["longitude"])
        if haskey(point_counts, coord)
            point_counts[coord] += 1
        else
            point_counts[coord] = 1
        end
    end

    overlapping_points = filter(x -> x[2] > 1, point_counts)
    return keys(overlapping_points)
end

function extract_features(gps_data, overlapping_points)
    features = []

    for coord in overlapping_points
        points = filter(x -> gps_data[x]["latitude"] == coord[1] && gps_data[x]["longitude"] == coord[2], keys(gps_data))

        avg_speed = mean([gps_data[p]["speed"] for p in points if gps_data[p]["speed"] !== missing])
        avg_heart_rate = mean([gps_data[p]["heart_rate"] for p in points if gps_data[p]["heart_rate"] !== missing])
        avg_altitude = mean([gps_data[p]["altitude"] for p in points if gps_data[p]["altitude"] !== missing])
        avg_distance = mean([gps_data[p]["distance"] for p in points if gps_data[p]["distance"] !== missing])

        push!(features, Dict(
            "latitude" => coord[1],
            "longitude" => coord[2],
            "avg_speed" => avg_speed,
            "avg_heart_rate" => avg_heart_rate,
            "avg_altitude" => avg_altitude,
            "avg_distance" => avg_distance
        ))
    end

    return features
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
            push!(longs, coord["longitude"])
            push!(lats, coord["latitude"])
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

    # Find overlapping points
    overlapping_points = find_overlapping_points(gps_data)

    println("Overlapping points: ", length(overlapping_points))

    # Extract features
    features = extract_features(gps_data, overlapping_points)

    println("Features: ", features)

    # Visualize the graph
    plot_property_graph(graph, gps_data, paths)
end

main()
