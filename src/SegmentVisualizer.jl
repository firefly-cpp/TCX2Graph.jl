using Plots

"""
    visualize_overlapping_segments(gps_data::Dict{Int, Dict{String, Any}},
                                   paths::Vector{UnitRange{Int64}},
                                   overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}},
                                   save_path::String)

Visualize the overlapping segments in red directly on the map.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: GPS data for each point.
- `paths::Vector{UnitRange{Int64}}`: The paths represented as ranges of indices.
- `overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}}`: The overlapping segments.
- `save_path::String`: The file path to save the final visualization.
"""
function plot_individual_overlapping_segments(
    gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}},
    save_path::String
)

    # Initialize the map with the base paths
    p = plot(title="Map with Overlapping Segments",
             xlabel="Longitude", ylabel="Latitude",
             size=(1200, 800),
             legend=:outertopright,
             grid=false)

    # Plot each path in gray for context
    for path in paths
        lats, lons = [], []
        for idx in path
            push!(lats, gps_data[idx]["latitude"])
            push!(lons, gps_data[idx]["longitude"])
        end
        plot!(p, lons, lats, lw=1, color=:gray, alpha=0.5, label="Path")
    end

    # Plot the overlapping segments in red
    for ((start_idx1, start_idx2), (end_idx1, end_idx2)) in overlapping_segments
        segment_lats, segment_lons = [], []

        # Segment from the first path
        for idx in start_idx1:end_idx1
            push!(segment_lats, gps_data[idx]["latitude"])
            push!(segment_lons, gps_data[idx]["longitude"])
        end
        plot!(p, segment_lons, segment_lats, lw=3, color=:red, label="Overlapping Segment", legend=false)
    end

    # Save the plot as an image
    savefig(p, save_path)
    println("Visualization saved to: $save_path")
end
