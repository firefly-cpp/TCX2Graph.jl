import PlotlyJS
using Plots

export plot_path_with_segments

"""
    plot_path_with_segments(
        gps_data::Dict{Int, Dict{String, Any}},
        paths::Vector{UnitRange{Int64}},
        path_segments::Vector{Dict{String,Any}},
        save_path::AbstractString,
    )

Interactively plots the computed path. The full rides that contribute to the path are drawn
in light gray for context. The final path, constructed from the reference range of each segment,
is overlaid in a distinct color. The PlotlyJS backend is used, so saving to an `.html` file
produces an interactive view.
"""
function plot_path_with_segments(
    gps_data::Dict{Int, Dict{String, Any}},
    paths::Vector{UnitRange{Int64}},
    path_segments::Vector{Dict{String,Any}},
    save_path::AbstractString,
)
    plotlyjs()

    involved_ride_indices = Set{Int}()
    for seg in path_segments
        for rid in keys(seg["run_ranges"])
            push!(involved_ride_indices, rid)
        end
    end

    p = plot(
        title = "Computed Path with Segments",
        xlabel = "Longitude",
        ylabel = "Latitude",
        legend = :outertopright,
        size=(1200, 800)
    )

    for rid in involved_ride_indices
        path_range = paths[rid]
        lons = [gps_data[idx]["longitude"] for idx in path_range]
        lats = [gps_data[idx]["latitude"] for idx in path_range]
        plot!(p, lons, lats; color = :lightgray, lw = 1.5, alpha=0.7, label = "Ride $rid context")
    end

    segment_colors = palette(:viridis, length(path_segments))
    for (i, seg) in enumerate(path_segments)
        color = segment_colors[i]
        ref_range = seg["ref_range"]
        orientation = get(seg, "orientation", :forward)

        lons = [gps_data[idx]["longitude"] for idx in ref_range]
        lats = [gps_data[idx]["latitude"] for idx in ref_range]

        if orientation == :reversed
            reverse!(lons)
            reverse!(lats)
        end

        plot!(p, lons, lats; color = color, lw = 4, label = "Segment $(seg["segment_index"]) ($orientation)")

        scatter!(p, [lons[1]], [lats[1]]; color = color, markershape = :utriangle, markersize=6, label = "")
        scatter!(p, [lons[end]], [lats[end]]; color = color, markershape = :circle, markersize=6, label = "")
    end

    savefig(p, save_path)
    println("Path visualization saved to: $save_path")
    return nothing
end