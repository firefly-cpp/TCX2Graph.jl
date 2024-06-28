"""
    round_coord(coord::Float64, decimals::Int) -> Float64

Round a coordinate to a specified number of decimal places.

# Arguments
- `coord::Float64`: The coordinate value to be rounded.
- `decimals::Int`: The number of decimal places to round to.

# Returns
- `Float64`: The rounded coordinate value.
"""
function round_coord(coord::Float64, decimals::Int)
    factor = 10.0^decimals
    return round(coord * factor) / factor
end
