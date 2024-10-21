using Test
using NearestNeighbors
include("../src/TCX2Graph.jl")

@testset "TCX2Graph Tests" begin
    # Test for get_absolute_path
    @testset "get_absolute_path function" begin
        relative_path = "../src/examples/data/file.tcx"
        absolute_path = abspath(joinpath(@__DIR__, relative_path))
        @test TCX2Graph.get_absolute_path(relative_path) == absolute_path
    end

    # Test for get_tcx_files_from_directory
    @testset "get_tcx_files_from_directory function" begin
        tempdir = mktempdir()  # Create a temporary directory for testing

        # Create mock TCX files in the temp directory
        file1 = joinpath(tempdir, "file1.tcx")
        file2 = joinpath(tempdir, "file2.tcx")
        open(file1, "w") do f; write(f, "mock tcx data") end
        open(file2, "w") do f; write(f, "mock tcx data") end

        tcx_files = TCX2Graph.get_tcx_files_from_directory(tempdir)

        @test length(tcx_files) == 2
        @test file1 in tcx_files
        @test file2 in tcx_files

        # Cleanup
        rm(tempdir, recursive=true)
    end

    # Test for create_property_graph
    @testset "create_property_graph function" begin
        @test true  # Placeholder for actual TCX file test
    end

    # Test for create_kdtree_index
    @testset "create_kdtree_index function" begin
        gps_data = Dict(
            1 => Dict{String, Any}("latitude" => 48.8566, "longitude" => 2.3522),
            2 => Dict{String, Any}("latitude" => 48.8570, "longitude" => 2.3530)
        )
        kdtree = TCX2Graph.create_kdtree_index(gps_data)
        @test kdtree isa KDTree  # Correct the test to check the type
    end

    # Test for find_overlapping_segments_across_paths
    @testset "find_overlapping_segments_across_paths function" begin
        # Simulate GPS data with overlapping paths
        gps_data = Dict(
            1 => Dict{String, Any}("latitude" => 48.8566, "longitude" => 2.3522),
            2 => Dict{String, Any}("latitude" => 48.8567, "longitude" => 2.3523),
            3 => Dict{String, Any}("latitude" => 48.8568, "longitude" => 2.3524),
            4 => Dict{String, Any}("latitude" => 48.8567, "longitude" => 2.3523) # Overlap at point 2
        )

        # Simulate two paths that have overlap at point 2
        paths = [1:3, 2:4]  # The paths overlap at GPS point 2

        # Create a KDTree based on GPS data
        kdtree = TCX2Graph.create_kdtree_index(gps_data)

        # Find overlapping segments
        overlapping_segments = TCX2Graph.find_overlapping_segments_across_paths(gps_data, paths, kdtree)

        # Expect some overlaps
        @test length(overlapping_segments) > 0
    end

    # Test for plot_individual_overlapping_segments
    @testset "plot_individual_overlapping_segments function" begin
        gps_data = Dict(
            1 => Dict{String, Any}("latitude" => 48.8566, "longitude" => 2.3522),
            2 => Dict{String, Any}("latitude" => 48.8570, "longitude" => 2.3530)
        )
        paths = [1:2]
        overlapping_segments = [Dict("start_idx" => 1, "end_idx" => 2, "paths" => [1])]

        # Ensure the output directory exists
        save_dir = "./test_output/"
        if !isdir(save_dir)
            mkdir(save_dir)
        end

        TCX2Graph.plot_individual_overlapping_segments(gps_data, paths, overlapping_segments, save_dir)
        @test isfile(joinpath(save_dir, "segment_1.svg"))

        # Cleanup
        rm(save_dir, recursive=true)
    end

    # Test for compute_segment_characteristics
    @testset "compute_segment_characteristics function" begin
        gps_data = Dict(
            1 => Dict{String, Any}("latitude" => 48.8566, "longitude" => 2.3522, "altitude" => 35.0),
            2 => Dict{String, Any}("latitude" => 48.8570, "longitude" => 2.3530, "altitude" => 45.0)
        )
        overlapping_segments = [Dict("start_idx" => 1, "end_idx" => 2)]

        total_distance, total_ascent, total_descent, total_vertical_meters, max_gradient, avg_gradient =
            TCX2Graph.compute_segment_characteristics(1, gps_data, overlapping_segments)

        @test total_distance > 0
        @test total_ascent == 10.0
        @test total_descent == 0.0
    end

    # Test for plot_property_graph
    @testset "plot_property_graph function" begin
        gps_data = Dict(
            1 => Dict{String, Any}("latitude" => 48.8566, "longitude" => 2.3522),
            2 => Dict{String, Any}("latitude" => 48.8570, "longitude" => 2.3530)
        )
        paths = [1:2]

        # Ensure the output directory exists
        save_path = "./test_output/multi_tcx_graph_property.svg"
        save_dir = dirname(save_path)
        if !isdir(save_dir)
            mkdir(save_dir)
        end

        TCX2Graph.plot_property_graph(gps_data, paths, save_path)
        @test isfile(save_path)

        # Cleanup
        rm(save_dir, recursive=true)
    end
end
