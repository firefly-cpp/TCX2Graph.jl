using JSON, CSV, DataFrames, Statistics, StatsBase, Dates

function convert_time(s)
    if s === nothing || ismissing(s) || s == "unknown"
        return missing
    end

    local dt::DateTime
    if isa(s, String)
        dt = DateTime(s, dateformat"yyyy-mm-ddTHH:MM:SS.s")
    elseif isa(s, DateTime)
        dt = s
    else
        return missing
    end

    return Dates.value(dt - DateTime(1970,1,1)) / 1000.0
end

function something(x, default)
    if x === nothing || ismissing(x)
        return default
    else
        return x
    end
end

function json_to_dataframe(json_data::Vector{Dict{String, Any}})
    records = []
    for segment in json_data
        path_index = segment["path_index"]
        run_start = segment["run_start"]
        seg_idx_opt = get(segment, "segment_index", missing)
        for trackpoint in segment["run_data"]
            push!(records, Dict(
                "file_name"     => something(get(trackpoint, "file_name", missing), missing),
                "segment_index" => seg_idx_opt,
                "path_index"    => path_index,
                "run_start"     => run_start,
                "time"          => convert_time(get(trackpoint, "time", "unknown")),
                "altitude"      => something(get(trackpoint, "altitude", missing), missing),
                "distance"      => something(get(trackpoint, "distance", missing), missing),
                "heart_rate"    => something(get(trackpoint, "heart_rate", missing), missing),
                "cadence"       => something(get(trackpoint, "cadence", missing), missing),
                "speed"         => something(get(trackpoint, "speed", missing), missing),
                "watts"         => something(get(trackpoint, "watts", missing), missing),
                "maxspeed"      => something(get(trackpoint, "maxspeed", missing), missing),
                "latitude"      => something(get(trackpoint, "latitude", missing), missing),
                "longitude"     => something(get(trackpoint, "longitude", missing), missing),
                "surface"       => something(get(trackpoint, "surface", "unknown"), "unknown"),
                "smoothness"    => something(get(trackpoint, "smoothness", "unknown"), "unknown"),
                "width"         => something(get(trackpoint, "width", missing), missing),
                "lit"           => something(get(trackpoint, "lit", "unknown"), "unknown"),
                "incline"       => something(get(trackpoint, "incline", "unknown"), "unknown"),
                "barrier"       => something(get(trackpoint, "barrier", "unknown"), "unknown"),
                "crossing"      => something(get(trackpoint, "crossing", "unknown"), "unknown"),
                "landuse"       => something(get(trackpoint, "landuse", "unknown"), "unknown"),
                "lane_markings" => something(get(trackpoint, "lane_markings", "unknown"), "unknown"),
                "temperature_2m" => something(get(trackpoint, "temperature_2m", missing), missing),
                "precipitation" => something(get(trackpoint, "precipitation", missing), missing),
                "windspeed_10m" => something(get(trackpoint, "windspeed_10m", missing), missing),
                "winddirection_10m" => something(get(trackpoint, "winddirection_10m", missing), missing),
                "relative_humidity_2m" => something(get(trackpoint, "relative_humidity_2m", missing), missing),
                "cloudcover" => something(get(trackpoint, "cloudcover", missing), missing),
                "weathercode" => something(get(trackpoint, "weathercode", missing), missing),
                "pressure_msl" => something(get(trackpoint, "pressure_msl", missing), missing),
                "dewpoint_2m" => something(get(trackpoint, "dewpoint_2m", missing), missing),
                "uv_index" => something(get(trackpoint, "uv_index", missing), missing),
                "uv_index_clear_sky" => something(get(trackpoint, "uv_index_clear_sky", missing), missing),
                "snowfall" => something(get(trackpoint, "snowfall", missing), missing),
                "snow_depth" => something(get(trackpoint, "snow_depth", missing), missing),
                "shortwave_radiation" => something(get(trackpoint, "shortwave_radiation", missing), missing),
                "direct_radiation" => something(get(trackpoint, "direct_radiation", missing), missing),
                "diffuse_radiation" => something(get(trackpoint, "diffuse_radiation", missing), missing),
                "evapotranspiration" => something(get(trackpoint, "evapotranspiration", missing), missing),
                "et0_fao_evapotranspiration" => something(get(trackpoint, "et0_fao_evapotranspiration", missing), missing)
            ))
        end
    end
    return DataFrame(records)
end

function remove_fully_missing_features(df::DataFrame)
    println("Checking for columns with only missing values...")
    keep_cols = [col for col in names(df) if any(x -> !ismissing(x), df[:, col])]
    println("Keeping columns: ", keep_cols)
    return df[:, keep_cols]
end

function calculate_missing_percentage(df::DataFrame)
    return Dict(col => mean(ismissing.(df[:, col])) * 100 for col in names(df))
end

function remove_high_missing_features(df::DataFrame, threshold::Float64)
    missing_percentages = calculate_missing_percentage(df)
    keep_cols = [col for col in names(df) if missing_percentages[col] <= threshold]
    println("Keeping columns with missing values below threshold ($threshold%): ", keep_cols)
    return df[:, keep_cols]
end

function fix_missing_values!(df::DataFrame)
    println("Filling missing values for each run using run-specific medians/modes...")
    global_medians = Dict{String,Any}()
    global_modes   = Dict{String,Any}()
    for col in names(df)
        col_data = [x for x in skipmissing(df[:, col]) if !(nonmissingtype(eltype(df[:, col])) <: AbstractString && x == "unknown")]
        if !isempty(col_data) && nonmissingtype(eltype(df[:, col])) <: Number
            global_medians[col] = median(col_data)
        elseif !isempty(col_data) && nonmissingtype(eltype(df[:, col])) <: AbstractString
            global_modes[col] = mode(col_data)
        end
    end
    grouped = groupby(df, :file_name)
    for group in grouped
        for col in names(df)
            if nonmissingtype(eltype(df[:, col])) <: Number
                col_data = collect(skipmissing(group[:, col]))
                fill_val = isempty(col_data) ? get(global_medians, col, 0.0) : median(col_data)
                for row in eachrow(group)
                    if ismissing(row[col])
                        row[col] = fill_val
                    end
                end
            elseif nonmissingtype(eltype(df[:, col])) <: AbstractString
                col_data = [x for x in group[:, col] if x != "unknown" && !ismissing(x)]
                fill_val = isempty(col_data) ? get(global_modes, col, "unknown") : mode(col_data)
                for row in eachrow(group)
                    if row[col] == "unknown" || ismissing(row[col])
                        row[col] = fill_val
                    end
                end
            end
        end
    end
end

function remove_constant_unknown_features!(df::DataFrame)
    to_remove = []
    for col in names(df)
        if nonmissingtype(eltype(df[:, col])) <: AbstractString && all(x -> x == "unknown", df[:, col])
            push!(to_remove, col)
        end
    end
    if !isempty(to_remove)
        println("Removing features with all 'unknown' values: ", to_remove)
        select!(df, Not(to_remove))
    end
end

function check_and_fix_dataframe!(df::DataFrame)
    for col in names(df)
        if any(ismissing.(df[:, col]))
            println("Warning: Missing values found in column $col. Replacing with defaults...")
            if nonmissingtype(eltype(df[:, col])) <: Number
                df[:, col] .= coalesce.(df[:, col], 0.0)
            elseif nonmissingtype(eltype(df[:, col])) <: AbstractString
                df[:, col] .= coalesce.(df[:, col], "unknown")
            elseif nonmissingtype(eltype(df[:, col])) <: Bool
                df[:, col] .= coalesce.(df[:, col], false)
            end
        end
    end
end

function process_json_data(json_data::Vector{Dict{String, Any}}, missing_threshold::Float64)
    df = json_to_dataframe(json_data)
    println("Initial dataset size: ", size(df))
    df = remove_fully_missing_features(df)
    df = remove_high_missing_features(df, missing_threshold)
    println("Dataset size after feature removal: ", size(df))
    fix_missing_values!(df)
    remove_constant_unknown_features!(df)
    println("Final dataset size: ", size(df))
    check_and_fix_dataframe!(df)
    return df
end

function process_segments_aggregated(
    segments::Vector{Dict{String, Any}},
    gps_data::Dict{Int, Dict{String, Any}},
    missing_threshold::Float64 = 99.0
)::DataFrame
    function collect_segment_trackpoints(seg::Dict{String, Any})
        runs = extract_single_segment_runs(seg, gps_data)
        vcat([run["run_data"] for run in runs]...)
    end

    rows = Vector{Dict{String, Any}}()
    for (seg_idx, seg) in enumerate(segments)
        all_tps = collect_segment_trackpoints(seg)
        if isempty(all_tps)
            continue
        end

        df = DataFrame(all_tps)

        ref_range = get(seg, "ref_range", nothing)
        ref_start = ref_range === nothing ? missing : first(ref_range)
        ref_end   = ref_range === nothing ? missing : last(ref_range)
        ref_file  = (ref_start !== missing && haskey(gps_data, ref_start) && haskey(gps_data[ref_start], "file_name")) ?
                    gps_data[ref_start]["file_name"] : missing

        file_names_col = names(df) |> x -> ("file_name" in x ? df[!, "file_name"] : Vector{Union{Missing,String}}(undef, 0))
        uniq_files = isempty(file_names_col) ? String[] : unique([f for f in file_names_col if !ismissing(f)])
        files_joined = isempty(uniq_files) ? missing : join(uniq_files, ';')

        lat_vals = names(df) |> x -> ("latitude" in x ? collect(skipmissing(df[!, "latitude"])) : Float64[])
        lon_vals = names(df) |> x -> ("longitude" in x ? collect(skipmissing(df[!, "longitude"])) : Float64[])
        lat_min = isempty(lat_vals) ? missing : minimum(lat_vals)
        lat_max = isempty(lat_vals) ? missing : maximum(lat_vals)
        lon_min = isempty(lon_vals) ? missing : minimum(lon_vals)
        lon_max = isempty(lon_vals) ? missing : maximum(lon_vals)
        lat_centroid = (lat_min === missing || lat_max === missing) ? missing : (lat_min + lat_max) / 2
        lon_centroid = (lon_min === missing || lon_max === missing) ? missing : (lon_min + lon_max) / 2

        row = Dict{String, Any}()
        row["segment_index"] = get(seg, "segment_index", seg_idx)
        row["segment_name"] = "segment_$(row["segment_index"])"
        row["ref_tcx_file"] = ref_file
        row["ref_start_idx"] = ref_start
        row["ref_end_idx"] = ref_end
        row["files_involved"] = files_joined
        row["num_files_involved"] = length(uniq_files)
        row["num_runs"] = haskey(seg, "run_ranges") ? length(seg["run_ranges"]) : missing
        row["num_trackpoints"] = nrow(df)
        row["candidate_length"] = get(seg, "candidate_length", missing)
        row["lat_min"] = lat_min
        row["lat_max"] = lat_max
        row["lon_min"] = lon_min
        row["lon_max"] = lon_max
        row["latitude"] = lat_centroid
        row["longitude"] = lon_centroid

        for col in names(df)
            if col in ["file_name", "latitude", "longitude", "time"]
                continue
            end
            col_data_nm = collect(skipmissing(df[!, col]))
            isempty(col_data_nm) && continue

            if nonmissingtype(eltype(df[!, col])) <: Number
                row[col * "_mean"] = mean(col_data_nm)
                row[col * "_median"] = median(col_data_nm)
                row[col * "_std"] = std(col_data_nm)
                row[col * "_min"] = minimum(col_data_nm)
                row[col * "_max"] = maximum(col_data_nm)
            elseif nonmissingtype(eltype(df[!, col])) <: AbstractString
                filtered = filter(x -> x != "unknown", col_data_nm)
                row[col * "_mode"] = isempty(filtered) ? "unknown" : mode(filtered)
            end
        end

        push!(rows, row)
    end

    if isempty(rows)
        return DataFrame()
    end

    out = DataFrame()
    for r in rows
        push!(out, r, cols = :union)
    end

    println("CS2 initial segment-level dataset size: ", size(out))
    out = remove_fully_missing_features(out)
    out = remove_high_missing_features(out, missing_threshold)
    println("CS2 dataset size after feature removal: ", size(out))
    remove_constant_unknown_features!(out)
    check_and_fix_dataframe!(out)
    println("CS2 final segment-level dataset size: ", size(out))

    return out
end

local function _epoch_seconds(t)
    if t === nothing || ismissing(t)
        return missing
    elseif t isa DateTime
        return Dates.value(t - DateTime(1970,1,1)) / 1000.0
    elseif t isa Number
        return Float64(t)
    else
        return missing
    end
end

function process_segment_transitions(
    path_segments::Vector{Dict{String, Any}},
    gps_data::Dict{Int, Dict{String, Any}},
    missing_threshold::Float64 = 99.0
)::DataFrame
    seg_df = process_segments_aggregated(path_segments, gps_data, missing_threshold)
    if isempty(seg_df)
        return DataFrame()
    end

    seg_map = Dict{Int, Dict{String,Any}}()
    for r in eachrow(seg_df)
        idx = Int(r[:segment_index])
        seg_map[idx] = Dict(Symbol(k) => r[k] for k in names(seg_df))
    end

    function oriented_endpoints(seg::Dict{String,Any})
        ref_range = seg["ref_range"]
        orientation = get(seg, "orientation", :forward)
        if orientation == :forward
            sidx, eidx = first(ref_range), last(ref_range)
        else
            sidx, eidx = last(ref_range), first(ref_range)
        end
        spt, ept = gps_data[sidx], gps_data[eidx]
        return (spt, ept)
    end

    rows = Vector{Dict{String,Any}}()
    for i in 1:(length(path_segments)-1)
        seg_from = path_segments[i]
        seg_to   = path_segments[i+1]

        idx_from = get(seg_from, "segment_index", i)
        idx_to   = get(seg_to, "segment_index", i+1)

        from_row = get(seg_map, idx_from, Dict{Symbol,Any}())
        to_row   = get(seg_map, idx_to, Dict{Symbol,Any}())

        row = Dict{String,Any}()
        row["order_index"]        = i
        row["from_segment_index"] = idx_from
        row["to_segment_index"]   = idx_to
        row["from_segment_name"]  = "segment_$(idx_from)"
        row["to_segment_name"]    = "segment_$(idx_to)"

        row["from_ref_tcx_file"]  = get(from_row, :ref_tcx_file, missing)
        row["to_ref_tcx_file"]    = get(to_row, :ref_tcx_file, missing)
        row["from_ref_start_idx"] = get(from_row, :ref_start_idx, missing)
        row["from_ref_end_idx"]   = get(from_row, :ref_end_idx, missing)
        row["to_ref_start_idx"]   = get(to_row, :ref_start_idx, missing)
        row["to_ref_end_idx"]     = get(to_row, :ref_end_idx, missing)

        latmins = [get(from_row, :lat_min, missing), get(to_row, :lat_min, missing)]
        latmaxs = [get(from_row, :lat_max, missing), get(to_row, :lat_max, missing)]
        lonmins = [get(from_row, :lon_min, missing), get(to_row, :lon_min, missing)]
        lonmaxs = [get(from_row, :lon_max, missing), get(to_row, :lon_max, missing)]

        if any(ismissing, latmins) || any(ismissing, latmaxs) || any(ismissing, lonmins) || any(ismissing, lonmaxs)
            row["lat_min"] = missing; row["lat_max"] = missing
            row["lon_min"] = missing; row["lon_max"] = missing
            row["latitude"]  = missing; row["longitude"] = missing
        else
            row["lat_min"] = minimum(latmins)
            row["lat_max"] = maximum(latmaxs)
            row["lon_min"] = minimum(lonmins)
            row["lon_max"] = maximum(lonmaxs)
            row["latitude"]  = (row["lat_min"] + row["lat_max"]) / 2
            row["longitude"] = (row["lon_min"] + row["lon_max"]) / 2
        end

        (from_spt, from_ept) = oriented_endpoints(seg_from)
        (to_spt, _to_ept)    = oriented_endpoints(seg_to)
        if haskey(from_ept, "latitude") && haskey(to_spt, "latitude")
            row["transition_distance_m"] = haversine_distance(
                from_ept["latitude"], from_ept["longitude"], to_spt["latitude"], to_spt["longitude"]
            )
        else
            row["transition_distance_m"] = missing
        end
        t_from_end = haskey(from_ept, "time") ? _epoch_seconds(from_ept["time"]) : missing
        t_to_start = haskey(to_spt, "time")   ? _epoch_seconds(to_spt["time"])   : missing
        row["transition_time_gap_s"] = (ismissing(t_from_end) || ismissing(t_to_start)) ? missing : (t_to_start - t_from_end)

        for col in names(seg_df)
            if endswith(col, "_mean")
                row["from_$(col)"] = get(from_row, Symbol(col), missing)
                row["to_$(col)"]   = get(to_row,   Symbol(col), missing)
            end
            if endswith(col, "_mode")
                row["from_$(col)"] = get(from_row, Symbol(col), missing)
                row["to_$(col)"]   = get(to_row,   Symbol(col), missing)
            end
        end

        for col in names(seg_df)
            if endswith(col, "_mean")
                base = first(split(col, "_mean"))
                from_val = get(from_row, Symbol(col), missing)
                to_val   = get(to_row, Symbol(col), missing)
                if !(ismissing(from_val) || ismissing(to_val))
                    row["delta_$(base)_mean"] = to_val - from_val
                end
            end
        end

        push!(rows, row)
    end

    if isempty(rows)
        return DataFrame()
    end

    out = DataFrame()
    for r in rows
        push!(out, r, cols=:union)
    end

    println("CS3 initial transition-level dataset size: ", size(out))
    out = remove_fully_missing_features(out)
    out = remove_high_missing_features(out, missing_threshold)
    println("CS3 dataset size after feature removal: ", size(out))
    remove_constant_unknown_features!(out)
    check_and_fix_dataframe!(out)
    println("CS3 final transition-level dataset size: ", size(out))

    return out
end
