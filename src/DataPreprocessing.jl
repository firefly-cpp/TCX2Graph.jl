using JSON, CSV, DataFrames, Statistics, StatsBase

function something(x, default)
    if x === nothing || ismissing(x)
        return default
    else
        return x
    end
end

function json_to_dataframe(json_data)
    records = []
    for segment in json_data
        path_index = segment["path_index"]
        run_start = segment["run_start"]
        for trackpoint in segment["run_data"]
            push!(records, Dict(
                "file_name"     => something(get(trackpoint, "file_name", missing), missing),
                "path_index"    => path_index,
                "run_start"     => run_start,
                "time"          => something(get(trackpoint, "time", "unknown"), "unknown"),
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
                "incline"       => something(get(trackpoint, "incline", missing), missing),
                "barrier"       => something(get(trackpoint, "barrier", "unknown"), "unknown"),
                "crossing"      => something(get(trackpoint, "crossing", "unknown"), "unknown"),
                "landuse"       => something(get(trackpoint, "landuse", "unknown"), "unknown"),
                "lane_markings" => something(get(trackpoint, "lane_markings", "unknown"), "unknown")
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

function process_json_data(json_data::Vector{Dict}, missing_threshold::Float64)
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
