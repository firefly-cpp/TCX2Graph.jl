using Plots

"""
    plot_individual_overlapping_segments(gps_data::Dict{Int, Dict{String, Any}},
                                         paths::Vector{UnitRange{Int64}},
                                         overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}},
                                         save_dir::String)

Visualize each overlapping segment in a separate plot and save as individual SVG files.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: GPS data for each point.
- `paths::Vector{UnitRange{Int64}}`: The paths represented as ranges of indices.
- `overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}}`: The overlapping segments.
- `save_dir::String`: Directory where individual SVG files will be saved.
"""
function plot_individual_overlapping_segments(
    gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    overlapping_segments::Vector{Tuple{Tuple{Int, Int}, Tuple{Int, Int}}},
    save_dir::String
)
    # Iterate through each overlapping segment
    for (segment_idx, ((start_idx1, start_idx2), (end_idx1, end_idx2))) in enumerate(overlapping_segments)

        # Initialize a new plot for this segment
        p = plot(title="Overlapping Segment $segment_idx",
                 xlabel="Longitude", ylabel="Latitude",
                 size=(800, 600),
                 legend=:outertopright,
                 grid=false)

        # Plot the paths involved in this segment in gray (for context)
        for path in paths
            lats, lons = [], []
            for idx in path
                push!(lats, gps_data[idx]["latitude"])
                push!(lons, gps_data[idx]["longitude"])
            end
            plot!(p, lons, lats, lw=1, color=:gray, alpha=0.5, label="Path")
        end

        # Plot the overlapping segment itself with distinct colors
        segment_lats, segment_lons = [], []

        # Plot the segment from the first path
        for idx in start_idx1:end_idx1
            push!(segment_lats, gps_data[idx]["latitude"])
            push!(segment_lons, gps_data[idx]["longitude"])
        end
        plot!(p, segment_lons, segment_lats, lw=3, color=:red, label="Segment in Path 1")

        # Plot the segment from the second path
        segment_lats, segment_lons = [], []
        for idx in start_idx2:end_idx2
            push!(segment_lats, gps_data[idx]["latitude"])
            push!(segment_lons, gps_data[idx]["longitude"])
        end
        plot!(p, segment_lons, segment_lats, lw=3, color=:blue, label="Segment in Path 2")

        # Mark start and end points for each path with distinct markers
        scatter!(p, [gps_data[start_idx1]["longitude"]], [gps_data[start_idx1]["latitude"]],
                 markershape=:utriangle, markersize=8, markercolor=:red, label="Start (Path 1)")
        scatter!(p, [gps_data[start_idx2]["longitude"]], [gps_data[start_idx2]["latitude"]],
                 markershape=:utriangle, markersize=8, markercolor=:blue, label="Start (Path 2)")
        scatter!(p, [gps_data[end_idx1]["longitude"]], [gps_data[end_idx1]["latitude"]],
                 markershape=:circle, markersize=8, markercolor=:red, label="End (Path 1)")
        scatter!(p, [gps_data[end_idx2]["longitude"]], [gps_data[end_idx2]["latitude"]],
                 markershape=:circle, markersize=8, markercolor=:blue, label="End (Path 2)")

        # Save each plot as a separate SVG file
        save_path = joinpath(save_dir, "segment_$segment_idx.svg")
        savefig(p, save_path)
        println("Visualization for segment $segment_idx saved to: $save_path")
    end
end
