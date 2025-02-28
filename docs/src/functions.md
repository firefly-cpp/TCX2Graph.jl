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

#### `TCX2Graph.find_overlapping_segments(all_gps_data::Dict{Int,Dict{String,Any}}, paths::Vector{UnitRange{Int64}}; ref_ride_idx::Int = 1, max_length_m::Float64 = 500.0, tol_m::Float64 = 5.0, window_step::Int = 1, min_runs::Int = 2, prefilter_margin_m::Float64 = 5.0, dedup_overlap_frac::Float64 = 0.8)`
Finds overlapping segments across different paths using the provided GPS data and tolerance.

#### `TCX2Graph.create_property_graph(files::Vector{String}) -> Dict{String, Any}`
Creates a property graph from the provided TCX files.

#### `TCX2Graph.haversine_distance(lat1::Float64, lon1::Float64, lat2::Float64, lon2::Float64) -> Float64`
Calculates the Haversine distance between two points specified by their latitude and longitude.

#### `TCX2Graph.custom_atan2(y::Any, x::Any) -> Float64`
Custom implementation of the `atan2` function to compute the angle between two points.

#### `TCX2Graph.compute_segment_characteristics_basic(gps_data::Dict{Int64, Dict{String, Any}}, start_idx::Int, end_idx::Int) -> Dict{String, Any}`
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

#### `TCX2Graph.find_path_between_segments(gps_data::Dict{Int64, Dict{String, Any}}, start_idx::Int, end_idx::Int, tolerance::Float64) -> Vector{Dict{String, Any}}`
Finds the path between two segments based on the GPS data and tolerance.

#### `TCX2Graph.filter_features(features::Vector{Dict{String, Any}}, tolerance::Float64) -> Vector{Dict{String, Any}}`
Filters road features based on the provided tolerance.

#### `TCX2Graph.douglas_peucker(points::Vector{Dict{String, Any}}, epsilon::Float64) -> Vector{Dict{String, Any}}`
Simplifies a polyline using the Douglas-Peucker algorithm.

#### `TCX2Graph.extract_segment_features(gps_data::Dict{Int64, Dict{String, Any}}, segment::Dict{String, Any}, tolerance::Float64) -> Vector{Dict{String, Any}}`
Extracts road features for a segment based on the GPS data and tolerance.

#### `TCX2Graph.get_feature_stats(features::Vector{Dict{String, Any}}) -> Dict{String, Any}`
Computes statistics for the provided road features.

#### `TCX2Graph.find_closest_road_features(gps_data::Dict{Int64, Dict{String, Any}}, segment::Dict{String, Any}, tolerance::Float64) -> Vector{Dict{String, Any}}`
Finds the closest road features for a segment based on the GPS data and tolerance.

#### `TCX2Graph.assign_road_features!(gps_data::Dict{Int64, Dict{String, Any}}, tolerance::Float64)`
Assigns road features to the GPS data based on the provided tolerance.

#### `TCX2Graph.create_proper_polyline(polyline::Vector{Dict{String, Any}}) -> Vector{Dict{String, Any}}`
Creates a proper polyline from the provided data.

#### `TCX2Graph.query_overpass_polyline(polyline::Vector{Dict{String, Any}}) -> Vector{Dict{String, Any}}`
Queries Overpass API for road features along the provided polyline.

#### `TCX2Graph.extract_single_segment_runs() -> Tuple{Dict{String, Any}, Dict{Int64, Dict{String, Any}}}`
Extracts single segment runs from the provided data.

#### `TCX2Graph.find_best_window_in_ride(ref_indices::Vector{Int64}, ref_points::Vector{SVector{2, Float64}}, ref_ride_idx::Int64, max_length_m::Float64, all_gps_data::Dict{Int64, Dict{String, Any}}) -> Tuple{Vector{Int64}, Vector{SVector{2, Float64}}, Int64, Float64, Dict{Int64, Dict{String, Any}}}`
Finds the best window in a ride based on the reference indices, points, ride index, maximum length, and GPS data.

#### `TCX2Graph.get_ref_ride_idx_by_filename(paths::Vector{UnitRange{Int64}}, paths_files::Dict{UnitRange{Int64}, String}, target_filename::String) -> Int`
Gets the reference ride index based on the filename and paths.

# Functions Documentation

```@docs
TCX2Graph.get_absolute_path
TCX2Graph.get_tcx_files_from_directory
TCX2Graph.plot_property_graph
TCX2Graph.is_same_location
TCX2Graph.find_overlapping_segments
TCX2Graph.create_property_graph
TCX2Graph.haversine_distance
TCX2Graph.custom_atan2
TCX2Graph.compute_segment_characteristics_basic
TCX2Graph.plot_individual_overlapping_segments
TCX2Graph.read_tcx_gps_points
TCX2Graph.round_coord
TCX2Graph.create_kdtree_index
TCX2Graph.gps_to_point
TCX2Graph.euclidean_distance
TCX2Graph.find_path_between_segments
TCX2Graph.filter_features
TCX2Graph.douglas_peucker
TCX2Graph.extract_segment_features
TCX2Graph.get_feature_stats
TCX2Graph.find_closest_road_features
TCX2Graph.assign_road_features!
TCX2Graph.create_proper_polyline
TCX2Graph.query_overpass_polyline
TCX2Graph.extract_single_segment_runs
TCX2Graph.find_best_window_in_ride
TCX2Graph.get_ref_ride_idx_by_filename
```
