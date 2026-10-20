using FileIO
using Printf
import JSON
import Colors
import RedGreenAttention as RGA

function rg_score(dists::Matrix{Float64})
    n = size(dists, 2)
    idx = 0
    best_score = 10.0
    @inbounds for i = 1:n
        r = dists[1, i]
        g = dists[2, i]
        mn, mx = minmax(r, g)
        score = (mx - mn) / (mn + 1.0)
        if score > best_score
            idx = i
            best_score = score
        end
    end
    idx
end

function verify_initial_state(s::RGA.TrialGenSpec, istate::WorldState)
    # Check if both discs are similarly close to red or green
    dists = RGA.rg_dists(istate)
    dist_1, dist_2 = map(minimum, dists)
    abs(dist_1 - dist_2) < s.max_init_dist &&
        min(dist_1, dist_2) > s.min_rg_dist # REVIEW: remove?
end

function sample_initial_state(s::RGA.TrialGenSpec)
    istate = RGA.initial_state(s)
    while !verify_initial_state(s, istate)
        istate = RGA.initial_state(s)
    end
    istate
end

TrialRecord = @NamedTuple begin
    r_or_g     :: Vector{Bool}
    t_col      :: Int64
    dists      :: Matrix{Float64}
    to_probe   :: Int64
end

SceneRecord = @NamedTuple begin
    istate     :: WorldState
    c_swap     :: WorldState
    unswapped  :: TrialRecord
    c_swapped  :: TrialRecord
    traj       :: Array{Float64, 3}
end

function measure_trial(s::RGA.TrialGenSpec,
                       istate::WorldState)
    (r_or_g, t_col, last_state, traj) =
        RGA.run_to_rg_collision(s, istate)
    dists = RGA.rg_dists(last_state)
    to_probe = rg_score(dists)
    TrialRecord((; r_or_g, t_col, dists, to_probe)), traj
end

function sample_scene(s::RGA.TrialGenSpec)
    
    istate = sample_initial_state(s)
    unswapped, traj = measure_trial(s, istate)

    # swap rect 1 and 3
    c_swap = swap_colors(istate)
    c_swapped, _ = measure_trial(s, c_swap)

    SceneRecord((; istate, c_swap, unswapped, c_swapped, traj))
end

function verify_trial(s::RGA.TrialGenSpec, sample::TrialRecord)
    sample.t_col > s.min_t_col &&
        any(sample.r_or_g) &&
        sample.to_probe > 0 
end

function verify_scene(s::RGA.TrialGenSpec, sample::SceneRecord)
    verify_trial(s, sample.unswapped) &&
        verify_initial_state(s, sample.c_swap) &&
        verify_trial(s, sample.c_swapped)
end

function sample_and_verify_scene(s::RGA.TrialGenSpec)
    sample = sample_scene(s)
    attempts = 1
    while !verify_scene(s, sample)
        sample = sample_scene(s)
        attempts += 1
        if (attempts % 1000) == 0
            @printf "Attempts so far: %d \n" attempts
        end
    end
    sample
end

function swap_colors(istate::RGA.WorldState)
    hit_idx = 1
    other_idx = 3

    new_static = deepcopy(istate.static)
    a, b = istate.static[hit_idx], istate.static[other_idx]
    new_static.objects[hit_idx]  = StaticObject(b.pos, b.shape,
                                                a.color, b.collides)
    new_static.objects[other_idx] = StaticObject(a.pos, a.shape,
                                                 b.color, a.collides)
    WorldState(istate.dynamic, new_static)
end


const STEP_MS = 1000 / 30.0   # 1 sim step ≈ 1 frame @ 30 Hz
const PX_PER_UNIT_PER_SEC = 60.0  # vel (units/step) → px/s

# RGA hues (radians, from dgp_pilot.jl) → plugin hex colors.
# HSV(h,1,1) matches visuals.jl: Colors.MSC(rad2deg(hue)) at full saturation.
rg_hex(hue::Float64) =
    hue == RGA.RED   ? "#FF7878" :
    hue == RGA.GREEN ? "#78FF78" :
    "#$(string(Colors.hex(Colors.HSV(hue, 1.0, 1.0))))"

# RGA center-origin, y-up → plugin top-left, y-down.
# Positions are centers in both systems; RGA pos ∈ (±w/2, ±h/2).
to_plugin_xy(p::RGA.S2V, w::Float64, h::Float64) = (p[1] + w/2, h/2 - p[2])
# to_plugin_xy(p::RGA.S2V, w::Float64, h::Float64) = (p[1] + w/2, h - p[2])

function rect_spec(o::StaticObject, w::Float64, h::Float64)
    x, y = to_plugin_xy(o.pos, w, h)
    (x = x, y = y,
     width  = 2 * o.shape.hw,
     height = 2 * o.shape.hh,
     color  = rg_hex(o.color),
     solid  = o.collides)
end

function disc_spec(o::DynamicObject, w::Float64, h::Float64)
    x, y = to_plugin_xy(o.pos, w, h)
    (x = x, y = y,
     radius = o.shape.radius,
     color  = rg_hex(o.color),
     vx = o.vel[1],
     vy = -o.vel[2])   # y-axis flip
end

function export_scene(sample::SceneRecord,
                      s::RGA.TrialGenSpec;
                      probe_interval::Int = 0)

    istate = sample.istate
    frames = sample.traj
    meta = sample.unswapped
    
    w, h = s.motion_model.dimensions

    mapped_frames = map(eachslice(frames;dims=3)) do t
        map(eachslice(t;dims=2)) do obj
            x, y = obj
            to_plugin_xy(RGA.S2V(x, y), s.scene_x, s.scene_y)
        end
    end

    trial_1 = export_trial(sample.unswapped, sample.istate, mapped_frames, s;
                           probe_interval=probe_interval)
    trial_2 = export_trial(sample.c_swapped, sample.c_swap, mapped_frames, s;
                           probe_interval=probe_interval)
    (trial_1, trial_2)
end

function export_trial(
    meta::TrialRecord,
    istate::WorldState,
    mapped_frames,
    s::RGA.TrialGenSpec;
    probe_interval::Int = 0)
    
    w, h = s.motion_model.dimensions

    correct = meta.r_or_g[1] ? "r" : "g"
    (
        rectangles = [rect_spec(o, w, h) for o in istate.static],
        discs      = [disc_spec(o, w, h) for o in istate.dynamic],
        frames     = mapped_frames,
        duration   = round(Int, meta.t_col * STEP_MS),
        choices    = ["r", "g"],
        correct_response = correct,
        scene_width  = round(Int, w),
        scene_height = round(Int, h),
        probe_interval = probe_interval,
        meta = (t_col = meta.t_col,
                to_probe = meta.to_probe,
                dists = meta.dists),
    )
end

function export_trials(scenes::Vector{SceneRecord}, s::RGA.TrialGenSpec; kwargs...)
    ns = length(scenes)
    ntrials = 2*ns
    trials = Vector{NamedTuple}(undef, ntrials)
    for i = 1:ns
        (trial_1, trial_2) = export_scene(scenes[i], s; kwargs...)
        trials[i*2 - 1] = trial_1
        trials[i*2] = trial_2
    end

    JSON.json(trials)
end

function main()

    motion_model = RGA.BilliardBrownian(
        RGA.S2V(580, 580),
        0.1,
        0.001,
    )

    s = RGA.TrialGenSpec(
        ;
        scene_x = motion_model.dimensions[1],
        scene_y = motion_model.dimensions[2],
        motion_model = motion_model,
        resolve_steps = 10,
    )

    n_scenes = 1

    @time scenes = [sample_and_verify_scene(s) for _ = 1:n_scenes]
    exported = export_trials(scenes, s)

    open("output/pilot.json", "w") do io; write(io, exported); end

end


main();
