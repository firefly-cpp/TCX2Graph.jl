using Statistics: mean

export compute_unique_coverage_km, find_best_ref_ride

"""
    compute_unique_coverage_km(all_gps_data::Dict{Int,Dict{String,Any}},
                               paths::Vector{UnitRange{Int64}}; quantize_m::Float64 = 1.0)

Compute the total unique length (coverage) of the property graph.

- `all_gps_data`: global mapping vertex_index -> Dict with at least "latitude", "longitude".
- `paths`: vector of ride index ranges (UnitRange) describing ordered sequences per ride.
- `quantize_m`: grid cell size in meters used to collapse nearby points (default 1.0 m).

Returns a Dict with keys:
  - `total_meters`, `total_kilometers`, `unique_nodes`, `unique_edges`.
"""
function compute_unique_coverage_km(all_gps_data::Dict{Int,Dict{String,Any}},
                                    paths::Vector{UnitRange{Int64}}; quantize_m::Float64 = 1000.0)

    lats = Float64[]
    for v in values(all_gps_data)
        if haskey(v, "latitude") && haskey(v, "longitude")
            lat = v["latitude"]; lon = v["longitude"]
            if !(ismissing(lat) || ismissing(lon)) && isa(lat, Number) && isa(lon, Number)
                push!(lats, lat)
            end
        end
    end
    if isempty(lats)
        return Dict("total_meters" => 0.0, "total_kilometers" => 0.0, "unique_nodes" => 0, "unique_edges" => 0)
    end

    mean_lat_rad = deg2rad(mean(lats))
    lat_scale = 111000.0
    lon_scale = cos(mean_lat_rad) * 111000.0

    quantize_key(lat::Float64, lon::Float64) = begin
        x = lon * lon_scale
        y = lat * lat_scale
        qx = Int(round(x / quantize_m))
        qy = Int(round(y / quantize_m))
        return (qx, qy)
    end

    rep_coord = Dict{Tuple{Int,Int}, Tuple{Float64,Float64}}()

    edges = Set{Tuple{Tuple{Int,Int},Tuple{Int,Int}}}()

    for ride_range in paths
        indices = collect(ride_range)
        if length(indices) < 2
            continue
        end
        prev_key = nothing
        for idx in indices
            if !haskey(all_gps_data, idx)
                prev_key = nothing
                continue
            end
            tp = all_gps_data[idx]
            if !(haskey(tp, "latitude") && haskey(tp, "longitude"))
                prev_key = nothing
                continue
            end
            lat = tp["latitude"]; lon = tp["longitude"]
            if ismissing(lat) || ismissing(lon) || !(isa(lat, Number) && isa(lon, Number))
                prev_key = nothing
                continue
            end

            k = quantize_key(lat, lon)
            if !haskey(rep_coord, k)
                rep_x = k[1] * quantize_m
                rep_y = k[2] * quantize_m
                rep_lon = rep_x / lon_scale
                rep_lat = rep_y / lat_scale
                rep_coord[k] = (rep_lat, rep_lon)
            end

            if prev_key !== nothing && prev_key != k
                a, b = prev_key, k
                edge = a < b ? (a,b) : (b,a)
                push!(edges, edge)
            end
            prev_key = k
        end
    end

    total_m = 0.0
    for (k1, k2) in edges
        lat1, lon1 = rep_coord[k1]
        lat2, lon2 = rep_coord[k2]
        total_m += haversine_distance(lat1, lon1, lat2, lon2)
    end

    return Dict(
        "total_meters" => total_m,
        "total_kilometers" => total_m / 1000.0,
        "unique_nodes" => length(keys(rep_coord)),
        "unique_edges" => length(edges)
    )
end

"""
    find_best_ref_ride(all_gps_data, paths; grid_size_m, min_reps_for_hotspot)

Find the best reference ride by identifying which ride passes through the most "hotspots".

- `all_gps_data`: Global mapping vertex_index -> Dict with GPS data.
- `paths`: Vector of ride index ranges.
- `grid_size_m`: The size of the grid cells in meters to determine hotspots.
- `min_reps_for_hotspot`: The minimum number of unique rides that must pass through a cell for it to be a hotspot.

Returns the index of the best reference ride.
"""
function find_best_ref_ride(
    all_gps_data::Dict{Int,Dict{String,Any}},
    paths::Vector{UnitRange{Int64}};
    grid_size_m::Float64 = 50.0,
    min_reps_for_hotspot::Int = 10
)
    println("Finding best reference ride...")
    lats = [v["latitude"] for v in values(all_gps_data) if haskey(v, "latitude") && isa(v["latitude"], Number)]
    if isempty(lats)
        @warn "No latitude data available, returning ride 1 as default."
        return 1
    end

    mean_lat_rad = deg2rad(mean(lats))
    lat_scale = 111000.0
    lon_scale = cos(mean_lat_rad) * 111000.0

    quantize_key(lat, lon) = (Int(round(lon * lon_scale / grid_size_m)), Int(round(lat * lat_scale / grid_size_m)))

    cell_to_rides = Dict{Tuple{Int,Int}, Set{Int}}()
    for (p_idx, ride_range) in enumerate(paths)
        processed_cells_for_ride = Set{Tuple{Int,Int}}()
        for pt_idx in ride_range
            try
                tp = all_gps_data[pt_idx]
                lat, lon = tp["latitude"], tp["longitude"]
                if ismissing(lat) || ismissing(lon) continue end

                key = quantize_key(lat, lon)
                if !(key in processed_cells_for_ride)
                    push!(get!(cell_to_rides, key, Set{Int}()), p_idx)
                    push!(processed_cells_for_ride, key)
                end
            catch
                continue
            end
         end
     end

    hot_cells = Set{Tuple{Int,Int}}()
    for (cell, rides) in cell_to_rides
        if length(rides) >= min_reps_for_hotspot
            push!(hot_cells, cell)
        end
    end
    println("Found $(length(hot_cells)) hotspots (cells with at least $min_reps_for_hotspot rides).")
    if isempty(hot_cells)
        @warn "No hotspots found. Consider lowering `min_reps_for_hotspot`. Defaulting to ride 1."
        return 1
    end

    ride_scores = zeros(Int, length(paths))
    for (p_idx, ride_range) in enumerate(paths)
         for pt_idx in ride_range
            try
                tp = all_gps_data[pt_idx]
                lat, lon = tp["latitude"], tp["longitude"]
                if ismissing(lat) || ismissing(lon) continue end

                key = quantize_key(lat, lon)
                if key in hot_cells
                    ride_scores[p_idx] += 1
                end
            catch
                continue
            end
         end
     end

    best_ref_idx = argmax(ride_scores)
    println("Best reference ride is index $best_ref_idx with a score of $(maximum(ride_scores)).")
    return best_ref_idx
end
