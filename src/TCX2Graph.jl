# TCX2Graph.jl
# This module provides functions to parse TCX files, create property graphs, find overlapping points, extract features, and visualize the data.

module TCX2Graph

export read_tcx_gps_points, create_property_graph, find_overlapping_points, extract_features, plot_property_graph, round_coord

# Include the necessary files for the functionality
include("TCXParser.jl")
include("GraphBuilder.jl")
include("FeatureExtractor.jl")
include("Visualizer.jl")
include("Utils.jl")

end
