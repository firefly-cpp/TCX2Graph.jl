using HTTP, JSON3, Base64

const HEADERS = [
    "Content-Type" => "application/json",
    "Authorization" => "Basic " * base64encode("neo4j:password")
]

function neo4j_url(port::Int)
    return "http://100.109.162.39:$port/db/neo4j/tx/commit"
end

const FILE_PORT_MAP = Dict{String, Int}()

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

    return collect(all_filenames)
end

function fetch_gps_data_from_neo4j(tcx_filename::String)::Vector{Dict{String, Any}}
    port = get(FILE_PORT_MAP, tcx_filename, 7474)  # fallback if unknown
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
