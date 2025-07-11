using HTTP, JSON3, Dates, Base64

# ==== CONFIGURATION ====
const HEADERS = [
    "Content-Type" => "application/json",
    "Authorization" => "Basic " * base64encode("neo4j:password")
]
const FILE_PORT_MAP = Dict{String, Int}()

function neo4j_url(port::Int)
    return "http://100.109.162.39:$port/db/neo4j/tx/commit"
end

const weather_cache = Dict{Tuple{Float64, Float64, DateTime}, Dict{String, Any}}()
const WEATHER_KEYS = [
    "temperature_2m", "precipitation", "windspeed_10m", "winddirection_10m",
    "relative_humidity_2m", "cloudcover", "weathercode", "pressure_msl",
    "dewpoint_2m", "uv_index", "uv_index_clear_sky", "snowfall", "snow_depth",
    "shortwave_radiation", "direct_radiation", "diffuse_radiation",
    "evapotranspiration", "et0_fao_evapotranspiration"
]
const WEATHER_GRID_RESOLUTION = 0.5 # 0.5 degree grid for fewer API calls

# ==== UTILS ====
function round_coord(x::Float64, res::Float64=WEATHER_GRID_RESOLUTION)
    round(x / res) * res
end

function tryparse_datetime(dt)
    dt isa DateTime && return dt
    try
        return DateTime(dt)
    catch
        try
            return DateTime(dt, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")
        catch
            return nothing
        end
    end
end

function extract_number(filename::AbstractString)
    m = match(r"^(\d+)", filename)
    isnothing(m) ? typemax(Int) : parse(Int, m.captures[1])
end

# ==== NEO4J ACCESS ====
function fetch_tcx_filenames_from_neo4j()
    all_filenames = Set{String}()
    for port in 7471:7479
        url = neo4j_url(port)
        println("Checking Neo4j at $url")
        try
            query = """
            MATCH (t:Trackpoint)
            RETURN DISTINCT t.tcx_file
            """
            payload = JSON3.write(Dict("statements" => [Dict("statement" => query)]))
            response = HTTP.post(url, HEADERS, payload)
            parsed = JSON3.read(String(response.body))
            records = parsed[:results][1][:data]
            filenames = [record[:row][1] for record in records]
            for f in filenames
                FILE_PORT_MAP[f] = port
            end
            union!(all_filenames, filenames)
        catch e
            @warn "Failed to query Neo4j at $url: $e"
        end
    end
    # Natural sort (e.g., 1.tcx, 2.tcx, ..., 10.tcx, etc.)
    return sort(collect(all_filenames), by=extract_number)
end

function fetch_gps_data_from_neo4j(tcx_filename::String)::Vector{Dict{String, Any}}
    port = get(FILE_PORT_MAP, tcx_filename, 7474)
    url = neo4j_url(port)
    query = """
    MATCH (t:Trackpoint {tcx_file: \$tcx_file})
    RETURN t.id, t.latitude, t.longitude, t.time, t.altitude, t.distance,
           t.heart_rate, t.cadence, t.speed, t.watts, t.surface, t.smoothness,
           t.width, t.lit, t.maxspeed, t.incline, t.barrier, t.crossing,
           t.landuse, t.lane_markings
    ORDER BY t.time
    """
    payload = JSON3.write(Dict("statements" => [Dict("statement" => query, "parameters" => Dict("tcx_file" => tcx_filename))]))
    response = HTTP.post(url, HEADERS, payload)
    parsed = JSON3.read(String(response.body))
    gps_points = []
    for row in parsed["results"][1]["data"]
        if length(row["row"]) > 0
            push!(gps_points, Dict(
                "id" => row["row"][1],
                "latitude" => row["row"][2],
                "longitude" => row["row"][3],
                "time" => row["row"][4],
                "altitude" => row["row"][5],
                "distance" => row["row"][6],
                "heart_rate" => row["row"][7],
                "cadence" => row["row"][8],
                "speed" => row["row"][9],
                "watts" => row["row"][10],
                "surface" => row["row"][11],
                "smoothness" => row["row"][12],
                "width" => row["row"][13],
                "lit" => row["row"][14],
                "maxspeed" => row["row"][15],
                "incline" => row["row"][16],
                "barrier" => row["row"][17],
                "crossing" => row["row"][18],
                "landuse" => row["row"][19],
                "lane_markings" => row["row"][20],
                "file_name" => tcx_filename
            ))
        end
    end
    println("Fetched $(length(gps_points)) GPS points for file: $tcx_filename from port $port")
    return gps_points
end

function update_weather_bulk(trackpoints::Vector{Dict{String, Any}}, port::Int)
    url = neo4j_url(port)
    updates = []
    for tp in trackpoints
        d = Dict("id" => tp["id"], "tcx_file" => tp["file_name"])
        props = Dict{String, Any}()
        for k in WEATHER_KEYS
            props[k] = haskey(tp, k) ? tp[k] : missing
        end
        d["properties"] = props
        push!(updates, d)
    end
    query = """
    UNWIND \$updates AS u
    MATCH (n:Trackpoint {id: u.id, tcx_file: u.tcx_file})
    SET n += u.properties
    """
    payload = JSON3.write(Dict("statements" => [Dict("statement" => query, "parameters" => Dict("updates" => updates))]))
    response = HTTP.post(url, HEADERS, payload)
    println("Updated $(length(updates)) nodes in Neo4j.")
    println("Response: ", String(response.body))
end

# ==== WEATHER QUERY LOGIC ====
function unique_weather_queries(trackpoints)
    queries = Set{Tuple{Float64, Float64, DateTime}}()
    for tp in trackpoints
        if ismissing(tp["latitude"]) || ismissing(tp["longitude"]) || ismissing(tp["time"])
            continue
        end
        lat = round_coord(tp["latitude"])
        lon = round_coord(tp["longitude"])
        dt = tryparse_datetime(tp["time"])
        if isnothing(dt)
            continue
        end
        dt_hour = DateTime(year(dt), month(dt), day(dt), hour(dt))
        push!(queries, (lat, lon, dt_hour))
    end
    return queries
end

function match_api_time(api_times::Vector{String}, dt_hour::DateTime)
    # Returns the matching index or nothing
    for (i, t) in enumerate(api_times)
        try
            t_parsed = DateTime(t, dateformat"yyyy-mm-ddTHH:MM")
            if t_parsed == dt_hour
                return i
            end
        catch
            # ignore
        end
    end
    return nothing
end

function fetch_weather_safe(lat::Float64, lon::Float64, dt::DateTime)
    dt_hour = DateTime(year(dt), month(dt), day(dt), hour(dt))
    cache_key = (lat, lon, dt_hour)
    if haskey(weather_cache, cache_key)
        return weather_cache[cache_key], :cached
    end
    date_str = Dates.format(dt_hour, "yyyy-mm-dd")
    url = "https://archive-api.open-meteo.com/v1/archive?" *
        "latitude=$(lat)&longitude=$(lon)" *
        "&start_date=$(date_str)&end_date=$(date_str)" *
        "&hourly=" * join(WEATHER_KEYS, ",")
    for attempt in 1:3
        try
            r = HTTP.get(url)
            data = JSON3.read(String(r.body))
            api_times = haskey(data, "hourly") && haskey(data["hourly"], "time") ? data["hourly"]["time"] : String[]
            idx = match_api_time(collect(api_times), dt_hour)  # <-- FIXED HERE
            weather = Dict{String, Any}()
            if isnothing(idx)
                for k in WEATHER_KEYS
                    weather[k] = missing
                end
            else
                for k in WEATHER_KEYS
                    weather[k] = haskey(data["hourly"], k) ? data["hourly"][k][idx] : missing
                end
            end
            weather_cache[cache_key] = weather
            return weather, :fetched
        catch e
            if e isa HTTP.Exceptions.StatusError && e.status == 429
                println("Rate limited by Open-Meteo at lat=$(lat) lon=$(lon) time=$(dt_hour)")
                return nothing, :rate_limit
            elseif attempt < 3
                sleep(2^attempt)
            else
                rethrow(e)
            end
        end
    end
    return nothing, :failed
end

function enrich_file_weather!(trackpoints)
    queries = unique_weather_queries(trackpoints)
    for (lat, lon, dt_hour) in queries
        weather, status = fetch_weather_safe(lat, lon, dt_hour)
        if status == :rate_limit
            return false, (lat, lon, dt_hour)
        end
    end
    for tp in trackpoints
        if ismissing(tp["latitude"]) || ismissing(tp["longitude"]) || ismissing(tp["time"])
            continue
        end
        lat = round_coord(tp["latitude"])
        lon = round_coord(tp["longitude"])
        dt = tryparse_datetime(tp["time"])
        if isnothing(dt)
            continue
        end
        dt_hour = DateTime(year(dt), month(dt), day(dt), hour(dt))
        cache_key = (lat, lon, dt_hour)
        if haskey(weather_cache, cache_key)
            for (k, v) in weather_cache[cache_key]
                tp[k] = v
            end
        end
    end
    # Debug print
    println("Sample enriched trackpoint: ", trackpoints[1])
    return true, nothing
end

function append_to_processed_file(filename::String, processed_path="processed_files.txt")
    open(processed_path, "a") do io
        println(io, filename)
    end
end

# ==== MAIN ====
function main()
    tcx_files = fetch_tcx_filenames_from_neo4j()
    processed_path = "processed_files.txt"
    start_from = "" # set to file to resume, or "" to start from beginning
    found = (start_from == "") ? true : false
    already = Set{String}()
    if isfile(processed_path)
        already = Set(strip.(readlines(processed_path)))
    end
    for f in tcx_files
        if f in already
            println("Skipping already processed: $f")
            continue
        end
        if !found
            if f == start_from
                found = true
            else
                continue
            end
        end
        println("Processing file: $f")
        while true
            gps_points = fetch_gps_data_from_neo4j(f)
            ok, where = enrich_file_weather!(gps_points)
            if ok
                port = get(FILE_PORT_MAP, f, 7474)
                update_weather_bulk(gps_points, port)
                println("Finished updating Neo4j for file: $f")
                append_to_processed_file(f, processed_path)
                break
            else
                println("API rate limit hit while processing $f at $where. Waiting 90 seconds before retrying...")
                sleep(90)
            end
        end
    end
    println("Done. Last processed file saved in $processed_path.")
end

main()
