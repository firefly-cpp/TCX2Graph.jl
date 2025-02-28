using Plots

export plot_individual_overlapping_segments

"""
    plot_individual_overlapping_segments(gps_data::Dict{Int, Dict{String, Any}},
                                         paths::Vector{UnitRange{Int64}},
                                         overlapping_segments::Vector{Dict{String, Any}},
                                         save_dir::String)

Visualizes only the overlapping segments (as determined by run_ranges) for each ride.
It also shows the full paths in gray for context, but then overlays just the overlapping portion for each ride in distinct colors.
The function zooms in on the overlapping region.
"""
function plot_individual_overlapping_segments(
    gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    overlapping_segments::Vector{Dict{String, Any}},
    save_dir::String
)
    # For each overlapping segment
    for (segment_idx, segment) in enumerate(overlapping_segments)
        run_ranges = get(segment, "run_ranges", Dict{Int,UnitRange{Int64}}())
        involved_paths = keys(run_ranges)

        # Gather all points (from all rides) in the overlapping segment to compute a bounding box.
        all_lats = Float64[]
        all_lons = Float64[]
        for p in involved_paths
            for idx in run_ranges[p]
                push!(all_lats, gps_data[idx]["latitude"])
                push!(all_lons, gps_data[idx]["longitude"])
            end
        end

        # Determine the bounding box with some margin.
        margin = 0.0005
        lat_min = minimum(all_lats) - margin
        lat_max = maximum(all_lats) + margin
        lon_min = minimum(all_lons) - margin
        lon_max = maximum(all_lons) + margin

        # Create plot, set limits to zoom into the overlapping segment.
        p_plot = plot(title="Overlapping Segment $segment_idx",
                      xlabel="Longitude", ylabel="Latitude",
                      size=(800, 600),
                      legend=:outertopright,
                      grid=false,
                      xlims=(lon_min, lon_max),
                      ylims=(lat_min, lat_max))

        # Plot each full ride in light gray for context (optional).
        for (i, path_range) in enumerate(paths)
            lats = [gps_data[idx]["latitude"] for idx in path_range]
            lons = [gps_data[idx]["longitude"] for idx in path_range]
            plot!(p_plot, lons, lats, lw=0.5, color=:gray, alpha=0.3, label=i == 1 ? "Full Paths" : "")
        end

        # Choose a list of colors for the overlapping segments.
        path_colors = [:blue, :green, :orange, :purple, :red, :pink, :brown, :cyan]
        i = 1
        # Plot only the overlapping portion from each ride.
        for p in sort(collect(involved_paths))
            range = run_ranges[p]
            lats = [gps_data[idx]["latitude"] for idx in range]
            lons = [gps_data[idx]["longitude"] for idx in range]
            plot!(p_plot, lons, lats, lw=3, color=path_colors[mod(i-1, length(path_colors))+1],
                  label="Ride $p")
            i += 1
        end

        # Mark the start and end of the overlapping segment using the candidate (reference) indices,
        # if available. Otherwise, you could choose to mark the first and last points of each run.
        ref_range = get(segment, "ref_range", nothing)
        if ref_range !== nothing
            scatter!(p_plot, [gps_data[ref_range[1]]["longitude"]],
                     [gps_data[ref_range[1]]["latitude"]],
                     markershape=:utriangle, markersize=10, markercolor=:black, label="Ref Start")
            scatter!(p_plot, [gps_data[ref_range[end]]["longitude"]],
                     [gps_data[ref_range[end]]["latitude"]],
                     markershape=:circle, markersize=10, markercolor=:black, label="Ref End")
        end

        save_path = joinpath(save_dir, "segment_$segment_idx.svg")
        savefig(p_plot, save_path)
        println("Visualization for segment $segment_idx saved to: $save_path")
    end
end
