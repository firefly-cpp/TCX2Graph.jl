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
    overlapping_segments::Vector{Dict{String, Any}},
    save_dir::String
)
    # Iterate through each overlapping segment
    for (segment_idx, segment) in enumerate(overlapping_segments)
        start_idx = segment["start_idx"]
        end_idx = segment["end_idx"]
        involved_paths = segment["paths"]

        # Initialize a new plot for this segment
        p = plot(title="Overlapping Segment $segment_idx",
                 xlabel="Longitude", ylabel="Latitude",
                 size=(800, 600),
                 legend=:outertopright,
                 grid=false)

        # Plot all paths in gray for context
        for path in paths
            lats, lons = [], []
            for idx in path
                push!(lats, gps_data[idx]["latitude"])
                push!(lons, gps_data[idx]["longitude"])
            end
            plot!(p, lons, lats, lw=1, color=:gray, alpha=0.5, label="Path")
        end

        # Plot the segment in each involved path with a unique color
        path_colors = [:blue, :green, :orange, :purple, :yellow, :red, :pink, :brown]  # A list of colors for different paths

        for (k, path_idx) in enumerate(involved_paths)
            path = paths[path_idx]
            segment_lats, segment_lons = [], []

            for idx in start_idx:end_idx
                if idx in path
                    push!(segment_lats, gps_data[idx]["latitude"])
                    push!(segment_lons, gps_data[idx]["longitude"])
                end
            end

            # Plot the overlapping segment in a unique color
            plot!(p, segment_lons, segment_lats, lw=3, color=path_colors[mod(k - 1, length(path_colors)) + 1], label="Path $path_idx")
        end

        # Mark start and end points with distinct markers
        scatter!(p, [gps_data[start_idx]["longitude"]], [gps_data[start_idx]["latitude"]],
                 markershape=:utriangle, markersize=8, markercolor=:green, label="Start Point")
        scatter!(p, [gps_data[end_idx]["longitude"]], [gps_data[end_idx]["latitude"]],
                 markershape=:circle, markersize=8, markercolor=:red, label="End Point")

        # Display the paths involved in the overlap
        path_str = join(involved_paths, ", ")
        annotate!(p, gps_data[end_idx]["longitude"], gps_data[end_idx]["latitude"],
                  text("Paths involved: $path_str", :black))

        # Save the plot for this segment
        save_path = joinpath(save_dir, "segment_$segment_idx.svg")
        savefig(p, save_path)
        println("Visualization for segment $segment_idx saved to: $save_path")
    end
end
