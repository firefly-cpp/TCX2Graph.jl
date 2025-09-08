using HTTP, JSON3, Base64

const HEADERS = [
	"Content-Type" => "application/json",
	"Authorization" => "Basic " * base64encode("neo4j:password"),
]

function neo4j_url(port::Int)
	return "http://localhost:$port/db/neo4j/tx/commit"
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
			response = HTTP.post(url, HEADERS, payload; readtimeout=300, reuse_limit=0, retry=false)
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
		   t.landuse, t.lane_markings,
		   t.temperature_2m, t.precipitation, t.windspeed_10m, t.winddirection_10m,
	       t.relative_humidity_2m, t.cloudcover, t.weathercode, t.pressure_msl,
	       t.dewpoint_2m, t.uv_index, t.uv_index_clear_sky, t.snowfall, t.snow_depth,
	       t.shortwave_radiation, t.direct_radiation, t.diffuse_radiation,
	       t.evapotranspiration, t.et0_fao_evapotranspiration
	ORDER BY t.time
	"""

	payload = JSON3.write(Dict("statements" => [Dict("statement" => query, "parameters" => Dict("tcx_file" => tcx_filename))]))
	response = HTTP.post(url, HEADERS, payload; reuse_limit=0, readtimeout=300, retry=false)
	parsed = JSON3.read(String(response.body))

	gps_points = []
	for row in parsed["results"][1]["data"]
		if length(row["row"]) > 0
			push!(
				gps_points,
				Dict(
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
					"temperature_2m" => row["row"][21],
					"precipitation" => row["row"][22],
					"windspeed_10m" => row["row"][23],
					"winddirection_10m" => row["row"][24],
					"relative_humidity_2m" => row["row"][25],
					"cloudcover" => row["row"][26],
					"weathercode" => row["row"][27],
					"pressure_msl" => row["row"][28],
					"dewpoint_2m" => row["row"][29],
					"uv_index" => row["row"][30],
					"uv_index_clear_sky" => row["row"][31],
					"snowfall" => row["row"][32],
					"snow_depth" => row["row"][33],
					"shortwave_radiation" => row["row"][34],
					"direct_radiation" => row["row"][35],
					"diffuse_radiation" => row["row"][36],
					"evapotranspiration" => row["row"][37],
					"et0_fao_evapotranspiration" => row["row"][38],
					"file_name" => tcx_filename,
				),
			)
		end
	end

	println("Fetched $(length(gps_points)) GPS points for file: $tcx_filename from port $port")
	return gps_points
end
