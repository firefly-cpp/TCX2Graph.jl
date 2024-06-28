using TCX2Graph

function main()
    tcx_files = [
        "../example_data/activity_12163012156.tcx",
        "../example_data/activity_12171312300.tcx",
        "../example_data/activity_12186252814.tcx",
        "../example_data/activity_12270580292.tcx",
        "../example_data/activity_12381259800.tcx"
    ]

    save_path = "multi_tcx_graph_property.svg"

    # Create the property graph
    graph, gps_data, paths = TCX2Graph.create_property_graph(tcx_files)

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
