using Plots

function plot_property_graph(gps_data::Dict{Int, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, save_path::String)
    colors = [:red, :blue, :green, :orange, :purple, :cyan]
    p = plot(title="Multiple TCX Paths (Property Graph)",
             xlabel="Longitude", ylabel="Latitude",
             size=(1600, 1200),
             legendfont=font(12),
             guidefont=font(14),
             tickfont=font(10),
             titlefont=font(16))

    # Group paths and plot them separately
    path_index = 1
    for path in paths
        color = colors[(path_index - 1) % length(colors) + 1]
        longs, lats = [], []

        for vertex in path
            coord = gps_data[vertex]
            push!(longs, coord["longitude"])
            push!(lats, coord["latitude"])
        end

        plot!(p, longs, lats, color=color, label="Path $path_index", lw=2)
        path_index += 1
    end

    savefig(p, save_path)
end