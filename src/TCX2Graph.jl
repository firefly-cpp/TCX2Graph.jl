"""
    module TCX2Graph

The `TCX2Graph` module provides a comprehensive set of tools for processing GPS data from TCX files, building property graphs, detecting overlapping segments, and visualizing paths and transactions. It is designed to help analyze cycling routes, identify recurring patterns, and visualize segment overlaps across multiple cycling sessions.

# Purpose
The `TCX2Graph` module simplifies the analysis of cycling data from TCX files by converting GPS points into a graph structure, detecting overlapping segments across multiple paths, and visualizing the results. This module is particularly useful for analyzing recurring routes, segment usage, segment characteristics, and detecting path overlaps in multi-session cycling data.

"""
module TCX2Graph

include("TCXParser.jl")
include("GraphBuilder.jl")
include("OverlappingSegmentsUtils.jl")
include("Visualizer.jl")
include("Utils.jl")
include("SegmentVisualizer.jl")
include("SegmentAnalysis.jl")
include("PathFinder.jl")
include("SegmentRuns.jl")
include("Neo4jUtils.jl")

end
