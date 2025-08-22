using Plots
import PlotlyJS

export plot_individual_overlapping_segments, plot_all_segments_on_map

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

    for (segment_idx, segment) in enumerate(overlapping_segments)
        run_ranges = get(segment, "run_ranges", Dict{Int,UnitRange{Int64}}())
        involved_paths = keys(run_ranges)

        all_lats = Float64[]
        all_lons = Float64[]
        for p in involved_paths
            for idx in run_ranges[p]
                push!(all_lats, gps_data[idx]["latitude"])
                push!(all_lons, gps_data[idx]["longitude"])
            end
        end

        margin = 0.0005
        lat_min = minimum(all_lats) - margin
        lat_max = maximum(all_lats) + margin
        lon_min = minimum(all_lons) - margin
        lon_max = maximum(all_lons) + margin

        p_plot = plot(title="Overlapping Segment $segment_idx",
                      xlabel="Longitude", ylabel="Latitude",
                      size=(800, 600),
                      legend=:outertopright,
                      grid=false,
                      xlims=(lon_min, lon_max),
                      ylims=(lat_min, lat_max))

        for (i, path_range) in enumerate(paths)
            lats = [gps_data[idx]["latitude"] for idx in path_range]
            lons = [gps_data[idx]["longitude"] for idx in path_range]
            plot!(p_plot, lons, lats, lw=0.5, color=:gray, alpha=0.3, label=i == 1 ? "Full Paths" : "")
        end

        path_colors = [:blue, :green, :orange, :purple, :red, :pink, :brown, :cyan]
        i = 1

        for p in sort(collect(involved_paths))
            range = run_ranges[p]
            lats = [gps_data[idx]["latitude"] for idx in range]
            lons = [gps_data[idx]["longitude"] for idx in range]
            plot!(p_plot, lons, lats, lw=3, color=path_colors[mod(i-1, length(path_colors))+1],
                  label="Ride $p")
            i += 1
        end

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

"""
    plot_all_segments_on_map(
        gps_data::Dict{Int, Dict{String, Any}},
        paths::Vector{UnitRange{Int64}},
        overlapping_segments::Vector{Dict{String, Any}},
        close_ride_indices::Vector{Int},
        save_path::String
    )

Visualizes all detected overlapping segments on a single map containing all TCX file routes.
Full routes are drawn in light gray for context, and each overlapping segment is highlighted
with a unique color. This provides a complete overview for manual path finding.
"""
function plot_all_segments_on_map(
    gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    overlapping_segments::Vector{Dict{String, Any}},
    close_ride_indices::Vector{Int},
    save_path::String
)
    plotlyjs()

    p = plot(
        title="All Detected Overlapping Segments",
        xlabel="Longitude",
        ylabel="Latitude",
        legend=false,
        size=(1200, 800)
    )

    for ride_idx in close_ride_indices
        path_range = paths[ride_idx]
        lats = [gps_data[idx]["latitude"] for idx in path_range]
        lons = [gps_data[idx]["longitude"] for idx in path_range]
        plot!(p, lons, lats, lw=1, color=:gray, alpha=0.5, label="")
    end

    segment_colors = palette(:rainbow, length(overlapping_segments))

    for (segment_idx, segment) in enumerate(overlapping_segments)
        color = segment_colors[segment_idx]
        ref_range = get(segment, "ref_range", nothing)
        if ref_range !== nothing
            lons = [gps_data[idx]["longitude"] for idx in ref_range]
            lats = [gps_data[idx]["latitude"] for idx in ref_range]
            plot!(p, lons, lats, lw=3, color=color, label="Segment $segment_idx")
        end
    end

    savefig(p, save_path)
    println("Visualization of all segments saved to: $save_path")
end
