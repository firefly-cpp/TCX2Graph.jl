"""
    find_path_between_segments(
        start_segment::Dict{String, Any},
        end_segment::Dict{String, Any},
        overlap_segments::Vector{Dict{String, Any}},
        all_gps_data::Dict{Int, Dict{String, Any}};
        min_length::Int=3,
        min_paths::Int=2,
        tolerance::Float64=0.001
    ) -> Vector{Dict{String, Any}}

Finds a path between two segments by concatenating overlapping segments that meet specified criteria, such as a minimum path length
and the minimum number of paths each segment must appear in. Each segment in the resulting path includes an added `"segment_index"`
field to indicate its index position within `overlap_segments`.

# Arguments
- `start_segment::Dict{String, Any}`: The starting segment dictionary, containing `start_idx`, `end_idx`, and `paths` fields.
- `end_segment::Dict{String, Any}`: The ending segment dictionary, containing `start_idx`, `end_idx`, and `paths` fields.
- `overlap_segments::Vector{Dict{String, Any}}`: A list of overlapping segments to search through.
- `all_gps_data::Dict{Int, Dict{String, Any}}`: A dictionary of GPS data, indexed by start and end points (`start_idx` and `end_idx`), each entry holding GPS attributes like longitude and latitude.
- `min_length::Int`: The minimum number of segments (including start and end) required in the resulting path.
- `min_paths::Int`: The minimum number of paths in which each segment must appear to be considered.
- `tolerance::Float64`: The maximum Euclidean distance allowed between segments for them to be considered connected.

# Returns
- `Vector{Dict{String, Any}}`: A vector of dictionaries, each representing a segment in the path. Each segment includes an added
  `"segment_index"` field showing its index within `overlap_segments`.

# Throws
- `ErrorException`: If no valid path is found between the provided `start_segment` and `end_segment`, or if the final path
  does not meet `min_length`.

# Details
The function begins at `start_segment` and attempts to find successive segments within `overlap_segments` that satisfy both the
distance `tolerance` and `min_paths` requirements. The search continues until the path can connect to `end_segment`. If a valid
path is found, the segments in the path will each include `"segment_index"` fields corresponding to their indices in `overlap_segments`.
"""
function find_path_between_segments(
    start_segment::Dict{String, Any},
    end_segment::Dict{String, Any},
    overlap_segments::Vector{Dict{String, Any}},
    all_gps_data::Dict{Int, Dict{String, Any}};
    min_length::Int=3,
    min_paths::Int=2,
    tolerance::Float64=0.001
) :: Vector{Dict{String, Any}}
    # Find the index of the start and end segments in the overlap_segments
    start_segment_index = findfirst(s -> s == start_segment, overlap_segments)
    end_segment_index = findfirst(s -> s == end_segment, overlap_segments)

    # Initialize the path with the start segment and set its index
    path_segments = [merge(start_segment, Dict("segment_index" => start_segment_index))]
    current_segment = start_segment

    # Define the set of visited segments to avoid cycles
    visited_segments = Set{Int}()
    push!(visited_segments, start_segment["start_idx"])

    # Start the length count at 1 (already includes start_segment)
    total_length = 1

    while true
        # Find possible next segments within tolerance and meeting min_paths requirement
        next_segments = filter(s ->
            !(s["start_idx"] in visited_segments) &&
            length(s["paths"]) >= min_paths &&
            euclidean_distance(
                (all_gps_data[current_segment["end_idx"]]["longitude"], all_gps_data[current_segment["end_idx"]]["latitude"]),
                (all_gps_data[s["start_idx"]]["longitude"], all_gps_data[s["start_idx"]]["latitude"])
            ) <= tolerance,
            overlap_segments)

        if isempty(next_segments)
            # If no further segments can be found, throw an exception
            throw(ErrorException("No valid path found between the two segments"))
        end

        # Pick the next segment and find its index in overlap_segments
        current_segment = next_segments[1]
        current_segment_index = findfirst(s -> s == current_segment, overlap_segments)

        # Add the current segment to path_segments with its index
        push!(path_segments, merge(current_segment, Dict("segment_index" => current_segment_index)))

        push!(visited_segments, current_segment["start_idx"])

        total_length += 1

        # Check if the current segment can connect directly to the end segment
        if euclidean_distance(
                (all_gps_data[current_segment["end_idx"]]["longitude"], all_gps_data[current_segment["end_idx"]]["latitude"]),
                (all_gps_data[end_segment["start_idx"]]["longitude"], all_gps_data[end_segment["start_idx"]]["latitude"])
            ) <= tolerance
            # Add the end segment to the path with its index
            push!(path_segments, merge(end_segment, Dict("segment_index" => end_segment_index)))
            total_length += 1
            break
        end
    end

    # Final check to ensure we have met the minimum path length constraint
    if total_length < min_length
        throw(ErrorException("Path does not meet the minimum required length"))
    end

    return path_segments
end
