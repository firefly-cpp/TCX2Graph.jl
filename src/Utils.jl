function round_coord(coord::Float64, decimals::Int)
    factor = 10.0^decimals
    return round(coord * factor) / factor
end