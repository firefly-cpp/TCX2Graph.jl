"""
    module TCX2Graph

The `TCX2Graph` module provides a comprehensive set of tools for processing GPS data from TCX files, building property graphs, detecting overlapping segments, and visualizing paths and transactions. It is designed to help analyze cycling routes, identify recurring patterns, and visualize segment overlaps across multiple cycling sessions.

# Purpose
The `TCX2Graph` module simplifies the analysis of cycling data from TCX files by converting GPS points into a graph structure, detecting overlapping segments across multiple paths, and visualizing the results. This module is particularly useful for analyzing recurring routes, segment usage, segment characteristics, and detecting path overlaps in multi-session cycling data.

"""
module TCX2Graph

export read_tcx_gps_points, create_property_graph, find_overlapping_segments_across_paths,
       plot_property_graph, round_coord, create_kdtree_index, plot_individual_overlapping_segments,
       custom_atan2, haversine_distance, compute_segment_characteristics_basic, get_absolute_path,
       get_tcx_files_from_directory, find_path_between_segments, euclidean_distance, get_feature_stats,
       compute_segment_variability, extract_segment_features, build_rule, feature_position, calculate_border,
       calculate_selected_category, add_attribute, pso, de, fitness_function, support, confidence, normalize_features,
       filter_features, initpopulation, terminate

include("TCXParser.jl")
include("GraphBuilder.jl")
include("KDTreeUtils.jl")
include("Visualizer.jl")
include("Utils.jl")
include("SegmentVisualizer.jl")
include("SegmentAnalysis.jl")
include("PathFinder.jl")
include("RuleUtils.jl")
include("Metrics.jl")
include("EvolutionaryAlgorithms.jl")
include("Optimization.jl")

end
