using Plots

"""
    plot_individual_overlapping_segments(gps_data::Dict{Int, Dict{String, Any}},
                                         paths::Vector{UnitRange{Int64}},
                                         overlapping_segments::Vector{Dict{String, Any}},
                                         save_dir::String)

Visualizes the overlapping segments in the paths on a map, with each segment highlighted in unique colors, and saves the visualizations as individual files.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data for each point, with indices as keys and dictionaries of properties (e.g., latitude, longitude) as values.
- `paths::Vector{UnitRange{Int64}}`: A vector of ranges, where each range represents the indices of GPS points in a specific path.
- `overlapping_segments::Vector{Dict{String, Any}}`: A vector of dictionaries where each dictionary represents an overlapping segment, with keys for the start index, end index, and paths involved.
- `save_dir::String`: The directory where the visualization files will be saved.

# Details
This function generates visualizations of overlapping segments by plotting all paths in gray for context and highlighting the overlapping segments in unique colors. For each segment, the start and end points are marked with distinct markers (green triangle for the start and red circle for the end), and the paths involved in the overlap are annotated. The visualizations are saved as SVG files, with one file per overlapping segment.
"""
function plot_individual_overlapping_segments(
    gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    overlapping_segments::Vector{Dict{String, Any}},
    save_dir::String
)
    for (segment_idx, segment) in enumerate(overlapping_segments)
        start_idx = segment["start_idx"]
        end_idx = segment["end_idx"]
        involved_paths = segment["paths"]

        p = plot(title="Overlapping Segment $segment_idx",
                 xlabel="Longitude", ylabel="Latitude",
                 size=(800, 600),
                 legend=:outertopright,
                 grid=false)

        for path in paths
            lats, lons = [], []
            for idx in path
                push!(lats, gps_data[idx]["latitude"])
                push!(lons, gps_data[idx]["longitude"])
            end
            plot!(p, lons, lats, lw=1, color=:gray, alpha=0.5, label="Path")
        end

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

            plot!(p, segment_lons, segment_lats, lw=3, color=path_colors[mod(k - 1, length(path_colors)) + 1], label="Path $path_idx")
        end

        scatter!(p, [gps_data[start_idx]["longitude"]], [gps_data[start_idx]["latitude"]],
                 markershape=:utriangle, markersize=8, markercolor=:green, label="Start Point")
        scatter!(p, [gps_data[end_idx]["longitude"]], [gps_data[end_idx]["latitude"]],
                 markershape=:circle, markersize=8, markercolor=:red, label="End Point")

        path_str = join(involved_paths, ", ")

        annotate!(p, gps_data[end_idx]["longitude"], gps_data[end_idx]["latitude"],
                  text("   Paths involved: $path_str", 12, :left, :bottom))

        save_path = joinpath(save_dir, "segment_$segment_idx.svg")
        savefig(p, save_path)
        println("Visualization for segment $segment_idx saved to: $save_path")
    end
end
