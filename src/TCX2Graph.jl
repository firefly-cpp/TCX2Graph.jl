module TCX2Graph

export read_tcx_gps_points, create_property_graph, find_overlapping_points, extract_features, plot_property_graph, round_coord

include("TCXParser.jl")
include("GraphBuilder.jl")
include("FeatureExtractor.jl")
include("Visualizer.jl")
include("Utils.jl")

end 
