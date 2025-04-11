using Base.Threads
using StaticArrays

export find_overlapping_segments

"""
	find_best_window_in_ride(ride_global, candidate_polyline, window_size, tol_m, all_gps_data)

Given a sorted array of global indices from a ride (found by a KD–tree pre–filter),
this function searches for a contiguous block (of length = window_size) that minimizes
the discrete Fréchet distance with candidate_polyline. Returns the best contiguous block
and its Fréchet distance.
"""
function find_best_window_in_ride(ride_global::Vector{Int}, candidate_polyline::Vector{SVector{2, Float64}}, window_size::Int, tol_m::Float64, all_gps_data::Dict{Int, Dict{String, Any}})
	best_window = nothing
	best_df = Inf
	sorted_indices = sort(ride_global)
	for i in 1:(length(sorted_indices)-window_size+1)
		block = sorted_indices[i:(i+window_size-1)]
		if maximum(diff(block)) > 1
			continue
		end
		window_polyline = [gps_to_point(all_gps_data[j]) for j in block]
		df = discrete_frechet(candidate_polyline, window_polyline)
		if df < best_df
			best_df = df
			best_window = block
		end
	end
	return best_window, best_df
end

"""
	find_overlapping_segments(all_gps_data, paths; ref_ride_idx, max_length_m, tol_m, window_step, min_runs, prefilter_margin_m, dedup_overlap_frac)

For a chosen reference ride (specified by ref_ride_idx in `paths`), this function slides a window along the ride
to produce candidate segments that have geographic length at least max_length_m (meters). For each candidate (an ordered
subarray of indices from the reference ride), it pre–filters each ride using a per–ride KD–tree so that only points within
an expanded candidate bounding circle (using prefilter_margin_m) are considered. Then, for each ride, it slides a window over
the candidate points and computes the discrete Fréchet distance between the candidate polyline and the window.
If at least min_runs rides produce a window with discrete Fréchet distance ≤ tol_m, the candidate is accepted.
Before adding a candidate to the results, a deduplication check is done: if the candidate’s reference range overlaps an
existing candidate by more than dedup_overlap_frac (fraction of the candidate length), it is considered a duplicate and skipped.

Returns an array of dictionaries with:
  • "ref_range": the indices (from the reference ride) of the candidate segment.
  • "run_ranges": a Dict mapping each ride index (that passed) to a UnitRange of indices (the overlapping segment in that ride).
  • "candidate_length": the geographic length (in meters) of the candidate segment.
  • "candidate_polyline": the candidate polyline as a vector of points.

The outer loop over candidate start indices is threaded.
"""
function find_overlapping_segments(
	all_gps_data::Dict{Int, Dict{String, Any}},
	paths::Vector{UnitRange{Int64}};
	ref_ride_idx::Int = 1,
	max_length_m::Float64 = 500.0,
	tol_m::Float64 = 5.0,
	window_step::Int = 1,
	min_runs::Int = 2,
	prefilter_margin_m::Float64 = 5.0,
	dedup_overlap_frac::Float64 = 0.8,   # if 80% or more of indices overlap, consider duplicate
)::Vector{Dict{String, Any}}
	results = Vector{Dict{String, Any}}()
	ref_indices = collect(paths[ref_ride_idx])
	cum = cumulative_distances(ref_indices, all_gps_data)
	result_lock = ReentrantLock()

	# Prebuild KD–trees for each ride
	ride_kdtrees = [create_ride_kdtree(paths[p], all_gps_data) for p in 1:length(paths)]
	# Conversion factor from meters to degrees (approximate for small distances)
	m_to_deg = 1.0 / 111000.0
	tol_deg = tol_m * m_to_deg
	prefilter_margin_deg = prefilter_margin_m * m_to_deg

	@threads for s in 1:length(ref_indices)
		# Extend candidate until candidate segment length is at least max_length_m
		e = s
		while e <= length(ref_indices) && (cum[e] - cum[s]) < max_length_m
			e += 1
		end
		if e > length(ref_indices)
			continue
		end

		candidate_range = ref_indices[s:e]
		candidate_polyline = [gps_to_point(all_gps_data[i]) for i in candidate_range]
		candidate_length = cum[e] - cum[s]

		# Compute candidate bounding box (in degrees)
		lats = [pt[2] for pt in candidate_polyline]
		lons = [pt[1] for pt in candidate_polyline]
		lat_min, lat_max = minimum(lats), maximum(lats)
		lon_min, lon_max = minimum(lons), maximum(lons)
		center = SVector((lon_min + lon_max) / 2, (lat_min + lat_max) / 2)
		half_diag = sqrt(((lon_max - lon_min) / 2)^2 + ((lat_max - lat_min) / 2)^2)
		radius = half_diag + tol_deg + prefilter_margin_deg

		# For each ride, use its KD–tree to get candidate points
		run_ranges = Dict{Int, UnitRange{Int64}}()
		count_found = 0
		for p in 1:length(paths)
			(kd, ride_global) = ride_kdtrees[p]
			candidate_pts_idx = inrange(kd, center, radius)
			candidate_global = ride_global[candidate_pts_idx]
			window_size = length(candidate_range)
			best_window, best_df = find_best_window_in_ride(candidate_global, candidate_polyline, window_size, tol_m, all_gps_data)
			if best_window !== nothing && best_df <= tol_m
				run_ranges[p] = best_window[1]:best_window[end]
				count_found += 1
			end
		end

		if count_found >= min_runs
			# Deduplication: check if candidate_range significantly overlaps a previously accepted candidate.
			duplicate = false
			lock(result_lock) do
				for cand in results
					# Calculate the fraction of overlap between the candidate's ref_range and cand["ref_range"]
					common = length(intersect(candidate_range, cand["ref_range"]))
					frac = common / min(length(candidate_range), length(cand["ref_range"]))
					if frac >= dedup_overlap_frac
						duplicate = true
						break
					end
				end
			end

			if duplicate
				continue
			end

			lock(result_lock) do
				push!(results, Dict(
					"ref_range" => candidate_range,
					"run_ranges" => run_ranges,
					"candidate_length" => candidate_length,
					"candidate_polyline" => candidate_polyline,
				))
			end
		end
	end

	return results
end


