using HTTP, JSON3, Base64

const NEO4J_URL = "http://100.109.162.39:7474/db/neo4j/tx/commit"
const HEADERS = [
    "Content-Type" => "application/json",
    "Authorization" => "Basic " * base64encode("neo4j:password")
]

function fetch_tcx_filenames_from_neo4j()
    query = """
    MATCH (t:Trackpoint)
    RETURN DISTINCT t.tcx_file
    """

    payload = JSON3.write(Dict("statements" => [Dict("statement" => query)]))
    response = HTTP.post(NEO4J_URL, HEADERS, payload)

    # Parse response
    parsed_response = JSON3.read(String(response.body))

    # Debugging output
    println("Neo4j Response: ", parsed_response)

    # Extract filenames safely
    try
        records = parsed_response[:results][1][:data]
        filenames = [record[:row][1] for record in records]
        return filenames
    catch e
        error("Error extracting filenames from Neo4j response: ", e)
    end
end

function fetch_gps_data_from_neo4j(tcx_filename::String)::Vector{Dict{String, Any}}
    query = """
    MATCH (t:Trackpoint {tcx_file: \$tcx_file})
    RETURN t.id, t.latitude, t.longitude, t.time, t.altitude, t.distance,
           t.heart_rate, t.cadence, t.speed, t.watts, t.surface, t.smoothness,
           t.width, t.lit, t.maxspeed, t.incline, t.barrier, t.crossing,
           t.landuse, t.lane_markings
    ORDER BY t.time
    """

    payload = JSON3.write(Dict("statements" => [Dict("statement" => query, "parameters" => Dict("tcx_file" => tcx_filename))]))
    response = HTTP.post(NEO4J_URL, HEADERS, payload)

    parsed_response = JSON3.read(String(response.body))

    # Extract and format GPS points
    gps_points = []
    for row in parsed_response["results"][1]["data"]
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

    println("Fetched $(length(gps_points)) GPS points for file: $tcx_filename")

    return gps_points
end
