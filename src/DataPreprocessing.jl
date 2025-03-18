using JSON, CSV, DataFrames, Statistics, StatsBase

export process_json_data

function json_to_dataframe(json_data)
    records = []
    for segment in json_data
        path_index = segment["path_index"]
        run_start = segment["run_start"]
        for trackpoint in segment["run_data"]
            push!(records, Dict(
                "file_name" => something(get(trackpoint, "file_name", missing), missing),
                "path_index" => path_index,
                "run_start" => run_start,
                "time" => something(get(trackpoint, "time", missing), missing),
                "altitude" => something(get(trackpoint, "altitude", missing), missing),
                "distance" => something(get(trackpoint, "distance", missing), missing),
                "heart_rate" => something(get(trackpoint, "heart_rate", missing), missing),
                "cadence" => something(get(trackpoint, "cadence", missing), missing),
                "speed" => something(get(trackpoint, "speed", missing), missing),
                "watts" => something(get(trackpoint, "watts", missing), missing),
                "maxspeed" => something(get(trackpoint, "maxspeed", missing), missing),
                "latitude" => something(get(trackpoint, "latitude", missing), missing),
                "longitude" => something(get(trackpoint, "longitude", missing), missing),
                "surface" => something(get(trackpoint, "surface", missing), "unknown"),
                "smoothness" => something(get(trackpoint, "smoothness", missing), "unknown"),
                "width" => something(get(trackpoint, "width", missing), missing),
                "lit" => something(get(trackpoint, "lit", missing), false),
                "incline" => something(get(trackpoint, "incline", missing), missing),
                "barrier" => something(get(trackpoint, "barrier", missing), "unknown"),
                "crossing" => something(get(trackpoint, "crossing", missing), "unknown"),
                "landuse" => something(get(trackpoint, "landuse", missing), "unknown"),
                "lane_markings" => something(get(trackpoint, "lane_markings", missing), "unknown")
            ))
        end
    end
    return DataFrame(records)
end

function remove_fully_missing_features(df::DataFrame)
    return df[:, [col for col in names(df) if any(.!ismissing.(df[:, col]))]]
end

function calculate_missing_percentage(df::DataFrame)
    return Dict(col => mean(ismissing.(df[:, col])) * 100 for col in names(df))
end

function remove_high_missing_features(df::DataFrame, threshold::Float64)
    missing_percentages = calculate_missing_percentage(df)
    return df[:, [col for col in names(df) if missing_percentages[col] <= threshold]]
end

function fill_missing_values_per_run!(df::DataFrame)
    grouped = groupby(df, [:path_index, :run_start])

    global_medians = Dict(col => median(skipmissing(df[:, col])) for col in names(df) if eltype(df[:, col]) <: Number)
    global_modes = Dict(col => mode(skipmissing(df[:, col])) for col in names(df) if eltype(df[:, col]) <: AbstractString)

    for col in names(df)
        df[:, col] .= coalesce.(df[:, col], missing)

        for group in grouped
            indices = findall(row -> row.path_index == group[1, :path_index] && row.run_start == group[1, :run_start], eachrow(df))

            if eltype(df[:, col]) <: Number
                median_val = median(skipmissing(group[:, col]))
                if ismissing(median_val)
                    median_val = get(global_medians, col, missing)
                end
                df[indices, col] .= coalesce.(df[indices, col], median_val)

            elseif eltype(df[:, col]) <: AbstractString
                mode_val = mode(skipmissing(group[:, col]))
                if ismissing(mode_val)
                    mode_val = get(global_modes, col, "unknown")
                end
                df[indices, col] .= coalesce.(df[indices, col], mode_val)
            end
        end
    end
end

function fix_missing_heart_rate!(df::DataFrame)
    missing_hr_files = unique(df[df.heart_rate .=== missing, :file_name])

    if !isempty(missing_hr_files)
        println("Fixing heart rate for missing files: ", missing_hr_files)

        file_medians = Dict(
            file => median(skipmissing(df[df.file_name .== file, "heart_rate"]))
            for file in unique(df.file_name) if any(.!ismissing.(df[df.file_name .== file, "heart_rate"]))
        )

        global_median = median(skipmissing(df[:, "heart_rate"]))

        for file in missing_hr_files
            if haskey(file_medians, file)
                df[df.file_name .== file, "heart_rate"] .= coalesce.(df[df.file_name .== file, "heart_rate"], file_medians[file])
            else
                df[df.file_name .== file, "heart_rate"] .= coalesce.(df[df.file_name .== file, "heart_rate"], global_median)
            end
        end
    end
end

function remove_constant_unknown_features!(df::DataFrame)
    for col in names(df)
        if eltype(df[:, col]) <: AbstractString && all(df[:, col] .== "unknown")
            println("Removing feature with all unknown values: ", col)
            select!(df, Not(col))
        end
    end
end

function check_and_fix_dataframe!(df::DataFrame)
    for col in names(df)
        if any(ismissing.(df[:, col]))
            println("Warning: Missing values found in column $col. Replacing...")
            if eltype(df[:, col]) <: Number
                df[:, col] .= coalesce.(df[:, col], 0.0)
            elseif eltype(df[:, col]) <: AbstractString
                df[:, col] .= coalesce.(df[:, col], "unknown")
            elseif eltype(df[:, col]) <: Bool
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

    fix_missing_heart_rate!(df)
    fill_missing_values_per_run!(df)

    remove_constant_unknown_features!(df)

    println("Final dataset size: ", size(df))

    check_and_fix_dataframe!(df)

    return df
end
