# Functions

### TCX2Graph

#### `TCX2Graph.get_absolute_path(path::String) -> String`
Returns the absolute path for a given relative path.

#### `TCX2Graph.get_tcx_files_from_directory(directory::String) -> Vector{String}`
Retrieves all TCX files from the specified directory.

#### `TCX2Graph.plot_property_graph(gps_data::Dict{Int64, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, output_file::String)`
Plots a property graph for the provided GPS data and paths and saves it as an image.

#### `TCX2Graph.is_same_location(point1::Dict{String, Any}, point2::Dict{String, Any}) -> Bool`
Determines if two GPS points represent the same location based on their coordinates.

#### `TCX2Graph.find_overlapping_segments_across_paths(gps_data::Dict{Int64, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, tolerance) -> Vector{Dict{String, Any}}`
Finds overlapping segments across different paths using the provided GPS data and tolerance.

#### `TCX2Graph.create_property_graph(files::Vector{String}) -> Dict{String, Any}`
Creates a property graph from the provided TCX files.

#### `TCX2Graph.haversine_distance(lat1::Float64, lon1::Float64, lat2::Float64, lon2::Float64) -> Float64`
Calculates the Haversine distance between two points specified by their latitude and longitude.

#### `TCX2Graph.custom_atan2(y::Any, x::Any) -> Float64`
Custom implementation of the `atan2` function to compute the angle between two points.

#### `TCX2Graph.compute_segment_characteristics(gps_data::Dict{Int64, Dict{String, Any}}, start_idx::Int, end_idx::Int) -> Dict{String, Any}`
Computes characteristics for a segment of the path based on the GPS data.

#### `TCX2Graph.plot_individual_overlapping_segments(gps_data::Dict{Int64, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, overlapping_segments::Vector{Dict{String, Any}}, output_file::String)`
Plots individual overlapping segments based on the GPS data and saves the output.

#### `TCX2Graph.read_tcx_gps_points(file::String) -> Dict{Int64, Dict{String, Any}}`
Reads TCX GPS points from the specified file and returns the data.

#### `TCX2Graph.round_coord(coord::Float64, decimals::Int) -> Float64`
Rounds the given coordinate to the specified number of decimal places.

#### `TCX2Graph.create_kdtree_index(gps_data::Dict{Int64, Dict{String, Any}})`
Creates a KD-tree index for fast nearest neighbor queries based on the GPS data.

#### `TCX2Graph.gps_to_point(gps_data::Dict{String, Any}) -> Tuple{Float64, Float64}`
Converts a GPS point to a tuple of latitude and longitude.

#### `TCX2Graph.euclidean_distance(point1::Tuple{Float64, Float64}, point2::Tuple{Float64, Float64}) -> Float64`
Calculates the Euclidean distance between two points specified by their latitude and longitude.

# Functions Documentation

```@docs
TCX2Graph.get_absolute_path
TCX2Graph.get_tcx_files_from_directory
TCX2Graph.plot_property_graph
TCX2Graph.is_same_location
TCX2Graph.find_overlapping_segments_across_paths
TCX2Graph.create_property_graph
TCX2Graph.haversine_distance
TCX2Graph.custom_atan2
TCX2Graph.compute_segment_characteristics
TCX2Graph.plot_individual_overlapping_segments
TCX2Graph.read_tcx_gps_points
TCX2Graph.round_coord
TCX2Graph.create_kdtree_index
TCX2Graph.gps_to_point
TCX2Graph.euclidean_distance
```
