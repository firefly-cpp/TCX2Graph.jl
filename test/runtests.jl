using Test
using TCX2Graph
using Base.Filesystem: mktempdir
using Graphs: SimpleGraph

# Helper function to create a minimal TCX file for testing
function create_sample_tcx(file_path, lat, lon)
    open(file_path, "w") do io
        write(io, """
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
            <Activities>
                <Activity Sport="Running">
                    <Id>2023-01-01T00:00:00.000Z</Id>
                    <Lap StartTime="2023-01-01T00:00:00.000Z">
                        <TotalTimeSeconds>3600.0</TotalTimeSeconds>
                        <DistanceMeters>10000.0</DistanceMeters>
                        <MaximumSpeed>5.0</MaximumSpeed>
                        <Calories>500</Calories>
                        <AverageHeartRateBpm>
                            <Value>150</Value>
                        </AverageHeartRateBpm>
                        <MaximumHeartRateBpm>
                            <Value>180</Value>
                        </MaximumHeartRateBpm>
                        <Intensity>Active</Intensity>
                        <TriggerMethod>Manual</TriggerMethod>
                        <Track>
                            <Trackpoint>
                                <Time>2023-01-01T00:00:00.000Z</Time>
                                <Position>
                                    <LatitudeDegrees>$lat</LatitudeDegrees>
                                    <LongitudeDegrees>$lon</LongitudeDegrees>
                                </Position>
                                <AltitudeMeters>50.0</AltitudeMeters>
                                <DistanceMeters>0.0</DistanceMeters>
                                <HeartRateBpm>
                                    <Value>80</Value>
                                </HeartRateBpm>
                                <Extensions>
                                    <ns3:TPX xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                                        <ns3:Speed>2.0</ns3:Speed>
                                    </ns3:TPX>
                                </Extensions>
                            </Trackpoint>
                        </Track>
                    </Lap>
                </Activity>
            </Activities>
        </TrainingCenterDatabase>
        """)
    end
end

# Create a temporary directory for the test files
mktempdir() do tempdir
    sample_tcx_files = [
        joinpath(tempdir, "sample1.tcx"),
        joinpath(tempdir, "sample2.tcx")
    ]

    # Create sample TCX files
    create_sample_tcx(sample_tcx_files[1], 12.34, 56.78)
    create_sample_tcx(sample_tcx_files[2], 12.34, 56.78)

    # Tests for read_tcx_gps_points
    @testset "read_tcx_gps_points" begin
        gps_points = read_tcx_gps_points(sample_tcx_files[1])
        @test length(gps_points) == 1
        @test gps_points[1]["latitude"] == 12.34
        @test gps_points[1]["longitude"] == 56.78
    end

    # Tests for create_property_graph
    @testset "create_property_graph" begin
        graph, gps_data, paths = create_property_graph(sample_tcx_files)
        @test length(gps_data) == 2
        @test length(paths) == 2
        @test typeof(graph) == SimpleGraph{Int64}
    end

    # Tests for find_overlapping_points
    @testset "find_overlapping_points" begin
        _, gps_data, _ = create_property_graph(sample_tcx_files)
        overlapping_points = find_overlapping_points(gps_data)
        @test length(overlapping_points) == 1
    end

    # Tests for extract_features
    @testset "extract_features" begin
        _, gps_data, _ = create_property_graph(sample_tcx_files)
        overlapping_points = find_overlapping_points(gps_data)
        features = extract_features(gps_data, overlapping_points)
        @test length(features) == 1
        @test features[1]["latitude"] == 12.34
        @test features[1]["longitude"] == 56.78
    end

    # Tests for plot_property_graph
    @testset "plot_property_graph" begin
        _, gps_data, paths = create_property_graph(sample_tcx_files)
        save_path = joinpath(tempdir, "test_plot.svg")
        plot_property_graph(gps_data, paths, save_path)
        @test isfile(save_path)
        rm(save_path)
    end
end
