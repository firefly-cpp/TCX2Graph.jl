include("../src/TCX2Graph.jl")
using Base.Threads
using Base.Filesystem
using HTTP, JSON3, Base64
using Graphs

const NEO4J_URL = "http://localhost:7474/db/neo4j/tx/commit"
const HEADERS = [
    "Content-Type" => "application/json",
    "Authorization" => "Basic " * base64encode("neo4j:password")
]

function insert_nodes_bulk(node_data)
    if isempty(node_data)
        return
    end

    query = """
    UNWIND \$nodes AS node
    MERGE (n:Trackpoint {id: node.id, tcx_file: node.tcx_file})
    SET n += node.properties
    """

    payload = JSON3.write(Dict("statements" => [Dict("statement" => query, "parameters" => Dict("nodes" => node_data))]))
    response = HTTP.post(NEO4J_URL, HEADERS, payload)

    println("Nodes inserted: $(length(node_data))")
    println("Neo4j Response: ", String(response.body))
end

function insert_relationships_bulk(rel_data)
    if isempty(rel_data)
        return
    end

    query = """
    UNWIND \$rels AS rel
    MATCH (a:Trackpoint {id: rel.source, tcx_file: rel.tcx_file})
    MATCH (b:Trackpoint {id: rel.target, tcx_file: rel.tcx_file})
    MERGE (a)-[:CONNECTED_TO]->(b)
    """

    payload = JSON3.write(Dict("statements" => [Dict("statement" => query, "parameters" => Dict("rels" => rel_data))]))
    response = HTTP.post(NEO4J_URL, HEADERS, payload)

    println("Relationships inserted: $(length(rel_data))")
    println("Neo4j Response: ", String(response.body))
end

function store_to_neo4j_http(graph::Graphs.SimpleGraph, gps_data::Dict{Int, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, tcx_files::Vector{String})
    println("Graph Stats: $(nv(graph)) nodes, $(ne(graph)) edges")

    if nv(graph) == 0
        return
    end

    trackpoint_to_tcx = Dict()
    for (i, path_range) in enumerate(paths)
        for vertex in path_range
            trackpoint_to_tcx[vertex] = basename(tcx_files[i])
        end
    end

    nodes = [
        Dict(
            "id" => v,
            "tcx_file" => get(trackpoint_to_tcx, v, "unknown"),
            "properties" => gps_data[v]
        )
        for v in Graphs.vertices(graph)
    ]

    edges = [
        Dict(
            "source" => Graphs.src(e),
            "target" => Graphs.dst(e),
            "tcx_file" => get(trackpoint_to_tcx, Graphs.src(e), "unknown")
        )
        for e in Graphs.edges(graph) if haskey(trackpoint_to_tcx, Graphs.src(e)) && haskey(trackpoint_to_tcx, Graphs.dst(e))
    ]

    insert_nodes_bulk(nodes)
    insert_relationships_bulk(edges)

    println("Bulk Insert: Stored $(length(nodes)) nodes and $(length(edges)) edges in Neo4j")
end

function main()
    tcx_folder_path = TCX2Graph.get_absolute_path("../example_data/9")
    tcx_files = TCX2Graph.get_tcx_files_from_directory(tcx_folder_path)

    if isempty(tcx_files)
        error("No TCX files found in the folder: $tcx_folder_path")
    end

    println("Found $(length(tcx_files)) TCX files.")
    batch_size = 4

    Threads.@threads for i in 1:batch_size:length(tcx_files)
        batch_files = tcx_files[i:min(i+batch_size-1, length(tcx_files))]
        println("Thread $(Threads.threadid()): Processing batch $(i) - $(i + batch_size - 1)")

        graph, gps_data, paths = TCX2Graph.create_property_graph(batch_files, true)

        store_to_neo4j_http(graph, gps_data, paths, batch_files)

        println("Thread $(Threads.threadid()): Batch $(i) - $(i + batch_size - 1) processed and saved to Neo4j")
    end

    println("All TCX files processed successfully!")
end

main()
