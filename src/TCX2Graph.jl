"""
    module TCX2Graph

The `TCX2Graph` module provides a comprehensive set of tools for processing GPS data from TCX files, building property graphs, detecting overlapping segments, and visualizing paths and transactions. It is designed to help analyze cycling routes, identify recurring patterns, and visualize segment overlaps across multiple cycling sessions.

# Exports
- `read_tcx_gps_points`: Reads GPS points from TCX files and returns structured GPS data.
- `create_property_graph`: Creates a property graph from TCX file data, where vertices represent GPS points, and edges connect consecutive points.
- `find_overlapping_segments_across_paths`: Identifies overlapping segments in GPS paths using spatial queries with a KD-tree.
- `extract_all_possible_transactions`: Generates all possible transactions for overlapping segments across paths.
- `plot_property_graph`: Visualizes the property graph, with options to highlight specific segments or paths.
- `round_coord`: Rounds GPS coordinates to a specified precision.
- `create_kdtree_index`: Builds a KD-tree from GPS data for efficient spatial queries.
- `plot_individual_overlapping_segments`: Visualizes overlapping segments in paths, highlighting segments in unique colors for each path.
- `save_transactions_to_txt`: Saves the generated transactions for overlapping segments to text files.
- `custom_atan2`: A custom implementation of the `atan2` function, which returns the angle between the positive x-axis and the point (x, y).
- `haversine_distance`: Calculates the Haversine distance between two geographical points on the Earth's surface.
- `compute_segment_characteristics`: Computes segment metrics, including total distance, ascent, descent, vertical meters, and gradients.
- `get_absolute_path`: Converts a relative file path into an absolute file path based on the current directory.
- `save_rules_to_txt`: Saves association rules generated by NiaARM to a text file.
- `get_tcx_files_from_directory`: Collects all `.tcx` files from a specified directory and returns their absolute file paths.
- `euclidean_distance`: Calculates the Euclidean distance between two points in 2D space.
- `find_path_between_segments`: Finds a path between two segments by concatenating overlapping segments, ensuring specific criteria are met.

# Included Files
- `TCXParser.jl`: Contains functions to parse and read TCX files, extracting relevant GPS data.
- `GraphBuilder.jl`: Contains utilities for creating and managing property graphs from GPS data.
- `KDTreeUtils.jl`: Provides functions to build and query KD-trees for spatial analysis of GPS data.
- `FeatureExtractor.jl`: Includes methods to extract relevant features (e.g., speed, altitude) from GPS points.
- `Visualizer.jl`: Contains functions for visualizing paths, property graphs, and segments.
- `Utils.jl`: A set of utility functions used throughout the module (e.g., for coordinate rounding and distance calculations).
- `SegmentVisualizer.jl`: Provides tools to visualize overlapping GPS segments across multiple paths.
- `SegmentAnalysis.jl`: Contains functions for analyzing and computing characteristics of GPS segments (e.g., total ascent, distance).
- `PathFinder.jl`: Includes functions for finding paths between segments based on overlapping segments and specific criteria.

# Purpose
The `TCX2Graph` module simplifies the analysis of cycling data from TCX files by converting GPS points into a graph structure, detecting overlapping segments across multiple paths, and visualizing the results. This module is particularly useful for analyzing recurring routes, segment usage, segment characteristics, and detecting path overlaps in multi-session cycling data.

"""
module TCX2Graph

export read_tcx_gps_points, create_property_graph, find_overlapping_segments_across_paths,
       plot_property_graph, round_coord, create_kdtree_index, plot_individual_overlapping_segments,
       custom_atan2, haversine_distance, compute_segment_characteristics, get_absolute_path,
       get_tcx_files_from_directory, find_path_between_segments, euclidean_distance

include("TCXParser.jl")
include("GraphBuilder.jl")
include("KDTreeUtils.jl")
include("Visualizer.jl")
include("Utils.jl")
include("SegmentVisualizer.jl")
include("SegmentAnalysis.jl")
include("PathFinder.jl")

end
