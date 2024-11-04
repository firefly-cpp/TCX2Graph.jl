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
    euclidean_distance(point1::Tuple{Float64, Float64}, point2::Tuple{Float64, Float64}) -> Float64

Calculates the Euclidean distance between two points in 2D space.

# Arguments
- `point1::Tuple{Float64, Float64}`: The first point as a tuple (longitude, latitude).
- `point2::Tuple{Float64, Float64}`: The second point as a tuple (longitude, latitude).

# Returns
- `Float64`: The Euclidean distance between the two points.
"""
function euclidean_distance(point1::Tuple{Float64, Float64}, point2::Tuple{Float64, Float64}) :: Float64
    return norm(SVector(point1...) - SVector(point2...))
end
