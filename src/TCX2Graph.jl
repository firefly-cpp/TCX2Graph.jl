# TCX2Graph.jl
# This module provides functions to parse TCX files, create property graphs, create KD-tree indices,
# find overlapping segments, extract features for ARM, and visualize the data.

module TCX2Graph

export read_tcx_gps_points, create_property_graph, find_overlapping_segments_across_paths,
       extract_segment_data_for_arm, plot_property_graph, round_coord, create_kdtree_index, plot_individual_overlapping_segments,
       save_transactions_to_txt

include("TCXParser.jl")
include("GraphBuilder.jl")
include("KDTreeUtils.jl")
include("FeatureExtractor.jl")
include("Visualizer.jl")
include("Utils.jl")
include("SegmentVisualizer.jl")

end
