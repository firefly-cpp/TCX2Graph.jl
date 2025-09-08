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

function process_run_level_transitions_global(
    overlapping_segments::Vector{Dict{String,Any}},
    gps_data::Dict{Int, Dict{String,Any}};
    max_dist_m::Float64 = 300.0,
    max_gap_s::Float64 = 3600.0,
    missing_threshold::Float64 = 99.0
)::DataFrame

    local function _epoch_seconds_any(x)
        if x === nothing || ismissing(x) return missing end
        x isa Number && return Float64(x)
        x isa DateTime && return Dates.value(x - DateTime(1970,1,1)) / 1000.0
        x isa String && return convert_time(x)
        return missing
    end

    local function summarize_run(run_data::Vector{Dict{String,Any}})
        isempty(run_data) && return nothing

        spt = run_data[1]; ept = run_data[end]
        fn  = get(spt, "file_name", missing)
        st  = _epoch_seconds_any(get(spt, "time", missing))
        et  = _epoch_seconds_any(get(ept, "time", missing))
        s_lat = get(spt, "latitude", missing); s_lon = get(spt, "longitude", missing)
        e_lat = get(ept, "latitude", missing); e_lon = get(ept, "longitude", missing)

        df = DataFrame(run_data)
        row = Dict{String,Any}()
        row["file_name"] = fn
        row["start_time"] = st
        row["end_time"] = et
        row["start_lat"] = s_lat
        row["start_lon"] = s_lon
        row["end_lat"] = e_lat
        row["end_lon"] = e_lon
        row["num_trackpoints"] = nrow(df)

        for col in names(df)
            if col in ["file_name","latitude","longitude","time"]
                continue
            end
            colvec = df[!, col]
            nm = collect(skipmissing(colvec))
            isempty(nm) && continue
            if nonmissingtype(eltype(colvec)) <: Number
                row["$(col)_mean"] = mean(nm)
            elseif nonmissingtype(eltype(colvec)) <: AbstractString
                filtered = filter(x -> x != "unknown", nm)
                row["$(col)_mode"] = isempty(filtered) ? "unknown" : mode(filtered)
            end
        end
        return row
    end

    runs_by_ride = Dict{String, Vector{Dict{String,Any}}}()
    for (seg_idx, seg) in enumerate(overlapping_segments)
        seg_runs = extract_single_segment_runs(seg, gps_data)
        for run in seg_runs
            rsum = summarize_run(run["run_data"])
            rsum === nothing && continue
            rsum["segment_index"] = get(seg, "segment_index", seg_idx)
            fn = get(rsum, "file_name", missing)
            ismissing(fn) && continue
            push!(get!(runs_by_ride, fn, Vector{Dict{String,Any}}()), rsum)
        end
    end

    rows = Vector{Dict{String,Any}}()
    for (fn, rvec) in runs_by_ride
        have_time = filter(r -> !ismissing(get(r, "start_time", missing)), rvec)
        isempty(have_time) && continue
        sort!(have_time, by = r -> r["start_time"])
        for i in 1:(length(have_time)-1)
            from_run = have_time[i]; to_run = have_time[i+1]

            dist = (haskey(from_run, "end_lat") && haskey(from_run, "end_lon") &&
                    haskey(to_run, "start_lat") && haskey(to_run, "start_lon") &&
                    !(ismissing(from_run["end_lat"]) || ismissing(from_run["end_lon"]) ||
                      ismissing(to_run["start_lat"]) || ismissing(to_run["start_lon"]))) ?
                haversine_distance(from_run["end_lat"], from_run["end_lon"], to_run["start_lat"], to_run["start_lon"]) :
                missing

            gap = (ismissing(from_run["end_time"]) || ismissing(to_run["start_time"])) ? missing :
                  (to_run["start_time"] - from_run["end_time"])

            if !(ismissing(dist)) && dist > max_dist_m
                continue
            end
            if !(ismissing(gap)) && abs(gap) > max_gap_s
                continue
            end

            row = Dict{String,Any}(
                "file_name" => fn,
                "order_index_in_file" => i,
                "from_segment_index" => from_run["segment_index"],
                "to_segment_index" => to_run["segment_index"],
                "transition_distance_m" => dist,
                "transition_time_gap_s" => gap,
            )

            all_keys = union(collect(keys(from_run)), collect(keys(to_run)))
            for k in all_keys
                if endswith(k, "_mean") || endswith(k, "_mode")
                    row["from_$(k)"] = get(from_run, k, missing)
                    row["to_$(k)"]   = get(to_run,   k, missing)
                end
            end
            for k in all_keys
                if endswith(k, "_mean")
                    base = first(split(k, "_mean"))
                    fv = get(from_run, k, missing)
                    tv = get(to_run,   k, missing)
                    if !(ismissing(fv) || ismissing(tv))
                        row["delta_$(base)_mean"] = tv - fv
                    end
                end
            end

            push!(rows, row)
        end
    end

    isempty(rows) && return DataFrame()

    out = DataFrame()
    for r in rows
        push!(out, r, cols = :union)
    end

    println("Global transitions (run-level) initial size: ", size(out))
    out = remove_fully_missing_features(out)
    out = remove_high_missing_features(out, missing_threshold)
    println("Global transitions size after feature removal: ", size(out))
    remove_constant_unknown_features!(out)
    check_and_fix_dataframe!(out)
    println("Global transitions final size: ", size(out))
    return out
end
