include("../src/TCX2Graph.jl")

function get_absolute_path(relative_path::String)
    return abspath(joinpath(@__DIR__, relative_path))
end

function main()
    tcx_files = [
        get_absolute_path("../example_data/activity_12163012156.tcx"),
        get_absolute_path("../example_data/activity_12171312300.tcx"),
        get_absolute_path("../example_data/activity_12186252814.tcx"),
        get_absolute_path("../example_data/activity_12270580292.tcx"),
        get_absolute_path("../example_data/activity_12381259800.tcx")
    ]

    save_path = get_absolute_path("multi_tcx_graph_property.svg")

    for file in tcx_files
        println("Checking file: $file")
        if !isfile(file)
            error("File not found: $file")
        end
    end

    # Create the property graph
    graph, gps_data, paths = TCX2Graph.create_property_graph(tcx_files)

    println("all gps data: ", gps_data)

    # Find overlapping points
    overlapping_points = TCX2Graph.find_overlapping_points(gps_data)

    println("Overlapping points: ", length(overlapping_points))

    # Extract features
    features = TCX2Graph.extract_features(gps_data, overlapping_points)

    println("Features: ", features)

    # Visualize the graph and save as SVG
    TCX2Graph.plot_property_graph(gps_data, paths, save_path)
end

main()
