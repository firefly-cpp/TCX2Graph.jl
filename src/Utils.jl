using NearestNeighbors
using StaticArrays
using LinearAlgebra

export round_coord, custom_atan2, haversine_distance, get_absolute_path, get_tcx_files_from_directory, euclidean_distance, douglas_peucker, get_ref_ride_idx_by_filename, gps_to_point, create_kdtree_index, create_ride_kdtree, haversine_distance_segment, discrete_frechet, cumulative_distances, is_same_location

"""
    round_coord(coord::Float64, decimals::Int) -> Float64

Rounds a coordinate value to a specified number of decimal places.

# Arguments
- `coord::Float64`: The coordinate value (latitude or longitude) to be rounded.
- `decimals::Int`: The number of decimal places to round the coordinate value to.

# Returns
- `Float64`: The coordinate value rounded to the specified number of decimal places.

# Details
This function multiplies the coordinate by a power of 10 based on the `decimals` argument, rounds the result, and then divides by the same factor to produce the rounded value. It is commonly used to reduce the precision of latitude and longitude values in GPS data.
"""
function round_coord(coord::Float64, decimals::Int)
    factor = 10.0^decimals
    return round(coord * factor) / factor
end

"""
    custom_atan2(y::Float64, x::Float64) -> Float64

A custom implementation of the `atan2` function, which returns the angle (in radians) between the positive x-axis and the point (x, y).

# Arguments
- `y::Float64`: The y-coordinate of the point.
- `x::Float64`: The x-coordinate of the point.

# Returns
- `Float64`: The angle in radians between the positive x-axis and the point (x, y).

# Details
This function calculates the angle (in radians) between the positive x-axis and the point (x, y). It takes into account the quadrant in which the point lies to return the correct angle. Special cases for vertical lines (`x == 0`) are also handled.
"""
function custom_atan2(y, x)
    if x > 0
        return atan(y/x)
    elseif x < 0 && y >= 0
        return atan(y/x) + π
    elseif x < 0 && y < 0
        return atan(y/x) - π
    elseif x == 0 && y > 0
        return π/2
    elseif x == 0 && y < 0
        return -π/2
    else
        return 0.0
    end
end

"""
    haversine_distance(lat1::Float64, lon1::Float64, lat2::Float64, lon2::Float64) -> Float64

Calculates the Haversine distance between two geographical points on the Earth’s surface.

# Arguments
- `lat1::Float64`: Latitude of the first point in degrees.
- `lon1::Float64`: Longitude of the first point in degrees.
- `lat2::Float64`: Latitude of the second point in degrees.
- `lon2::Float64`: Longitude of the second point in degrees.

# Returns
- `Float64`: The distance between the two points in meters.

# Details
The Haversine formula calculates the great-circle distance between two points on a sphere given their longitudes and latitudes. This function assumes the Earth is a sphere with a radius of 6,371 kilometers and returns the distance between two points in meters.
"""
function haversine_distance(lat1::Float64, lon1::Float64, lat2::Float64, lon2::Float64)::Float64
    R = 6371000.0  # Radius of the Earth in meters
    φ1 = deg2rad(lat1)
    φ2 = deg2rad(lat2)
    Δφ = deg2rad(lat2 - lat1)
    Δλ = deg2rad(lon2 - lon1)

    a = sin(Δφ / 2)^2 + cos(φ1) * cos(φ2) * sin(Δλ / 2)^2
    c = 2 * custom_atan2(sqrt(a), sqrt(1 - a))

    return R * c
end

"""
    get_absolute_path(relative_path::String) -> String

Converts a relative file path to an absolute file path based on the current directory.

# Arguments
- `relative_path::String`: The relative path to be converted.

# Returns
- `String`: The absolute file path.
"""
function get_absolute_path(relative_path::String)
    return abspath(joinpath(@__DIR__, relative_path))
end

"""
    get_tcx_files_from_directory(directory::String) -> Vector{String}

Collects all `.tcx` files from a specified directory and returns their absolute file paths.

# Arguments
- `directory::String`: The directory to search for `.tcx` files.

# Returns
- `Vector{String}`: A vector of absolute file paths for each `.tcx` file found in the directory.
"""
function get_tcx_files_from_directory(directory::String)
    # Collect all files with .tcx extension
    files = readdir(directory)
    tcx_files = filter(f -> endswith(f, ".tcx"), files)
    # Convert relative file paths to absolute paths
    return [abspath(joinpath(directory, file)) for file in tcx_files]
end

"""
    euclidean_distance(point1, point2) -> Float64

Calculates the Euclidean distance between two points in 2D space.

# Arguments
- `point1`: The first point as a tuple (longitude, latitude) or `SVector{2, Float64}`.
- `point2`: The second point as a tuple (longitude, latitude) or `SVector{2, Float64}`.

# Returns
- `Float64`: The Euclidean distance between the two points.
"""
function euclidean_distance(point1, point2) :: Float64
    return norm(SVector(point1...) - SVector(point2...))
end

"""
    douglas_peucker(points::Vector{Tuple{Float64, Float64}}, epsilon::Float64) -> Vector{Tuple{Float64, Float64}}

Reduces the number of points in a polyline using the Douglas-Peucker algorithm.

# Arguments
- `points::Vector{Tuple{Float64, Float64}}`: A vector of 2D points represented as tuples (x, y).
- `epsilon::Float64`: The maximum distance threshold for simplification.

# Returns
- `Vector{Tuple{Float64, Float64}}`: A simplified vector of 2D points.

# Details

The Douglas-Peucker algorithm simplifies a polyline by recursively dividing it into smaller segments. The algorithm starts with the two endpoints of the polyline and finds the point
farthest from the line segment connecting them. If this point is farther than `epsilon` from the line, the polyline is split at this point, and the algorithm is applied recursively to the
two resulting segments. If the point is within `epsilon`, the line segment is approximated by the two endpoints. The process continues until no points exceed the threshold distance.
"""
function douglas_peucker(points::Vector{Tuple{Float64, Float64}}, epsilon::Float64)::Vector{Tuple{Float64, Float64}}
    if length(points) < 3
        return points
    end

    function perpendicular_distance(point, line_start, line_end)
        x0, y0 = point
        x1, y1 = line_start
        x2, y2 = line_end
        num = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        den = sqrt((y2 - y1)^2 + (x2 - x1)^2)
        return num / den
    end

    max_distance, index = 0.0, 0
    for i in 2:length(points)-1
        dist = perpendicular_distance(points[i], points[1], points[end])
        if dist > max_distance
            max_distance, index = dist, i
        end
    end

    if max_distance > epsilon
        left_simplified = douglas_peucker(points[1:index], epsilon)
        right_simplified = douglas_peucker(points[index:end], epsilon)

        return vcat(left_simplified[1:end-1], right_simplified)
    else
        return [points[1], points[end]]
    end
end

"""
    get_ref_ride_idx_by_filename(paths::Vector{UnitRange{Int64}},
                                 paths_files::Dict{UnitRange{Int64}, String},
                                 target_filename::String) -> Int

Given the list of rides (`paths`) and the dictionary `paths_files` (which maps each ride range to its TCX file path),
returns the index (in `paths`) of the ride whose file’s basename matches `target_filename`.
"""
function get_ref_ride_idx_by_filename(paths::Vector{UnitRange{Int64}},
                                      paths_files::Dict{UnitRange{Int64}, String},
                                      target_filename::String)
    target_basename = basename(target_filename)
    for (i, ride_range) in enumerate(paths)
        if haskey(paths_files, ride_range)
            file_basename = basename(paths_files[ride_range])
            if file_basename == target_basename
                return i
            end
        end
    end
    error("No ride with file name '$target_filename' found.")
end

"""
    gps_to_point(gps::Dict{String, Any}) -> SVector{2, Float64}

Converts a GPS dictionary to an `SVector` containing longitude and latitude.

# Arguments
- `gps::Dict{String, Any}`: The GPS data dictionary containing keys `"longitude"` and `"latitude"`.

# Returns
- `SVector{2, Float64}`: A static vector containing the longitude and latitude.

# Details
This function extracts the longitude and latitude from the provided GPS dictionary and returns them as an `SVector` for efficient numerical computations.
"""
function gps_to_point(gps::Dict{String,Any})
    return SVector(gps["longitude"], gps["latitude"])
end

"""
    gps_to_point(gps::Dict{String, Any}) -> SVector{2, Float64}

Converts a GPS dictionary to an `SVector` containing longitude and latitude.

# Arguments
- `gps::Dict{String, Any}`: The GPS data dictionary containing keys `"longitude"` and `"latitude"`.

# Returns
- `SVector{2, Float64}`: A static vector containing the longitude and latitude.

# Details
This function extracts the longitude and latitude from the provided GPS dictionary and returns them as an `SVector` for efficient numerical computations.
"""
function create_kdtree_index(all_gps_data::Dict{Int,Dict{String,Any}})
    points = [gps_to_point(gps) for gps in values(all_gps_data)]
    return KDTree(points)
end

# Build a KDTree for a single ride (keeping the original global indices)
function create_ride_kdtree(ride::UnitRange{Int64}, all_gps_data::Dict{Int,Dict{String,Any}})
    pts = [gps_to_point(all_gps_data[i]) for i in ride]
    return KDTree(pts), collect(ride)  # returns the tree and the corresponding global indices
end

# Discrete Fréchet distance between two polylines P and Q.
# P and Q are vectors of SVector{2,Float64}; distances are computed using haversine_distance.
function discrete_frechet(P::Vector{SVector{2,Float64}}, Q::Vector{SVector{2,Float64}})
    n = length(P)
    m = length(Q)
    ca = fill(-1.0, n, m)
    function c(i, j)
        if ca[i,j] > -1
            return ca[i,j]
        elseif i == 1 && j == 1
            ca[i,j] = haversine_distance(P[1][2], P[1][1], Q[1][2], Q[1][1])
        elseif i == 1
            ca[i,j] = max(c(1, j-1), haversine_distance(P[1][2], P[1][1], Q[j][2], Q[j][1]))
        elseif j == 1
            ca[i,j] = max(c(i-1, 1), haversine_distance(P[i][2], P[i][1], Q[1][2], Q[1][1]))
        else
            ca[i,j] = max(min(c(i-1, j), c(i-1, j-1), c(i, j-1)),
                          haversine_distance(P[i][2], P[i][1], Q[j][2], Q[j][1]))
        end
        return ca[i,j]
    end
    return c(n, m)
end

# Compute cumulative arc-length (in meters) along a sequence of indices (from a ride)
function cumulative_distances(ref_indices::Vector{Int}, all_gps_data::Dict{Int,Dict{String,Any}})
    cum = [0.0]
    for i in 2:length(ref_indices)
        p1 = all_gps_data[ref_indices[i-1]]
        p2 = all_gps_data[ref_indices[i]]
        d = haversine_distance(p1["latitude"], p1["longitude"], p2["latitude"], p2["longitude"])
        push!(cum, cum[end] + d)
    end
    return cum
end

"""
    is_same_location(gps1::Dict{String,Any}, gps2::Dict{String,Any}; tolerance=0.0015) -> Bool

Checks if two GPS locations are the same within a specified tolerance.

# Arguments
- `gps1::Dict{String,Any}`: The first GPS location.
- `gps2::Dict{String,Any}`: The second GPS location.
- `tolerance=0.0015`: The tolerance for considering the locations as the same (default is 0.0015).

# Returns
- `Bool`: `true` if the locations are the same within the specified tolerance, `false` otherwise.
"""
function is_same_location(gps1::Dict{String,Any}, gps2::Dict{String,Any}; tolerance=0.0015)
    return norm(gps_to_point(gps1) - gps_to_point(gps2)) <= tolerance
end

