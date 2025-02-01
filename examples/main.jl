include("../src/TCX2Graph.jl")
using BenchmarkTools
using Base.Threads

# Check the number of threads available
println("Number of threads: ", Threads.nthreads())

function main()
    # Path to the folder containing the .tcx files
    tcx_folder_path = TCX2Graph.get_absolute_path("../example_data/files")

    # Get all .tcx files from the folder
    tcx_files = TCX2Graph.get_tcx_files_from_directory(tcx_folder_path)

    if isempty(tcx_files)
        error("No TCX files found in the folder: $tcx_folder_path")
    end

    println("Found $(length(tcx_files)) TCX files.")

    save_path = TCX2Graph.get_absolute_path("multi_tcx_graph_property.svg")

    # Check for file existence
    for file in tcx_files
        println("Checking file: $file")
        if !isfile(file)
            error("File not found: $file")
        end
    end

    # Create property graph and KDTree
    graph, gps_data, paths = TCX2Graph.create_property_graph(tcx_files, true)
    kdtree = TCX2Graph.create_kdtree_index(gps_data)



end

main()
