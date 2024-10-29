function find_path_between_segments(
    start_segment::Dict{String, Any},
    end_segment::Dict{String, Any},
    overlap_segments::Vector{Dict{String, Any}};
    min_length::Int=3,
    min_paths::Int=2
)
    # Initialize the path with the start segment
    path_segments = [start_segment]
    current_segment = start_segment

    # Define the set of visited segments to avoid cycles
    visited_segments = Set{Int}()
    push!(visited_segments, start_segment["start_idx"])

    # Start the length count at 2 to include start and end segments
    total_length = 2

    while current_segment !== end_segment
        # Find possible next segments that overlap with the current segment
        next_segments = filter(s -> s["start_idx"] == current_segment["end_idx"] && !(s["start_idx"] in visited_segments), overlap_segments)

        # Apply the constraint that each segment must appear in at least `min_paths` paths
        next_segments = filter(s -> length(s["paths"]) >= min_paths, next_segments)

        if isempty(next_segments)
            # If no further segments can be found, throw an exception
            throw(ErrorException("No valid path found between the two segments"))
        end

        # Pick the next segment (could be based on certain criteria like minimal gap, etc.)
        current_segment = next_segments[1]  # For simplicity, just pick the first; could improve selection criteria
        push!(path_segments, current_segment)
        push!(visited_segments, current_segment["start_idx"])

        total_length += 1

        # If the total path length meets the minimum required length, we can stop
        if total_length >= min_length && current_segment == end_segment
            break
        end
    end

    # Final check to ensure we have met the minimum path length constraint
    if total_length < min_length
        throw(ErrorException("Path does not meet the minimum required length"))
    end

    # Ensure the end segment is included if it was not reached directly
    if path_segments[end] !== end_segment
        push!(path_segments, end_segment)
    end

    return path_segments
end
