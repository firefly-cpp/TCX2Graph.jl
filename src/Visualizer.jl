using Plots

"""
    plot_property_graph(gps_data::Dict{Int, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, save_path::String)

Visualizes a property graph of multiple TCX paths and saves the plot as an SVG file.

# Arguments
- `gps_data::Dict{Int, Dict{String, Any}}`: A dictionary containing GPS data for each vertex, where the key is the vertex index and the value is a dictionary of properties (e.g., latitude, longitude).
- `paths::Vector{UnitRange{Int64}}`: A vector of ranges representing different paths, where each range corresponds to a sequence of GPS points.
- `save_path::String`: The file path where the resulting SVG image will be saved.

# Details
This function generates a plot of multiple TCX paths, assigning each path a different color for visual distinction. The paths are displayed on a plot with longitude as the x-axis and latitude as the y-axis. The resulting plot is saved as an SVG file at the specified location. The function uses a preset list of colors to differentiate paths, and the plot is configured for large-scale, high-resolution output.
"""
function plot_property_graph(gps_data::Dict{Int, Dict{String, Any}}, paths::Vector{UnitRange{Int64}}, save_path::String)
    colors = [:red, :blue, :green, :orange, :purple, :cyan]
    p = plot(title="Multiple TCX Paths (Property Graph)",
             xlabel="Longitude", ylabel="Latitude",
             size=(2000, 1600),
             legendfont=font(24),
             guidefont=font(18),
             tickfont=font(18),
             titlefont=font(16))

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
