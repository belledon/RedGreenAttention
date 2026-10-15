using FileIO
using Printf
import JSON
import Colors
import RedGreenAttention as RGA

# Specs:
# 1. r-g diff
# 2. 

# Spec details:
# r-g diff:
# the difference in proximity for first disc
# want to maximize
#
# 

SceneMeta = @NamedTuple begin
    t_col          :: Int64
    r_or_g         :: Vector{Bool}
    dists          :: Matrix{Float64}
    to_probe       :: Int64
end

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

function sample_initial_state(s::RGA.TrialGenSpec)
    istate = RGA.initial_state(s)
    # Check if both discs are similarly close to red or green
    dists = RGA.rg_dists(istate)
    dist_1, dist_2 = map(minimum, dists)
    while abs(dist_1 - dist_2) > 40.0 || min(dist_1, dist_2) < 50
        istate = RGA.initial_state(s)
        dists = RGA.rg_dists(istate)
        dist_1, dist_2 = map(minimum, dists)
    end
    istate
end

function sample_scene(s::RGA.TrialGenSpec)
    
    istate = sample_initial_state(s)
    (r_or_g, t_col, ws, traj) =
        RGA.run_to_rg_collision(s, istate)
    dists = RGA.rg_dists(ws)
    to_probe = rg_score(dists)

    attempts = 1
    while t_col < 90 || !any(r_or_g) || to_probe == 0 
        istate = sample_initial_state(s)
        (r_or_g, t_col, ws, traj) =
            RGA.run_to_rg_collision(s, istate)
        dists = RGA.rg_dists(ws)
        to_probe = rg_score(dists)
        attempts += 1

        if (attempts % 1000) == 0
            @printf "Attempts so far: %d \n" attempts
            @show t_col
            @show r_or_g
            @show to_probe
        end
    end

    meta = SceneMeta((;t_col, r_or_g,
                     dists, to_probe))
    (istate, traj, meta)
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

function export_trial(istate::WorldState,
                      frames::Array{Float64, 3},
                      meta::SceneMeta,
                      s::RGA.TrialGenSpec;
                      probe_interval::Int = 0)
    w, h = s.motion_model.dimensions

    mapped_frames = map(eachslice(frames;dims=3)) do t
        map(eachslice(t;dims=2)) do obj
            x, y = obj
            to_plugin_xy(RGA.S2V(x, y), s.scene_x, s.scene_y)
        end
    end
    
    correct = meta.r_or_g[1] ? "r" : "g"
    return (
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

function export_trials(trials::Vector{<:Tuple}, s::RGA.TrialGenSpec; kwargs...)
    JSON.json([export_trial(t[1], t[2], t[3], s; kwargs...) for t in trials])
end

function main()

    motion_model = RGA.BilliardBrownian(
        RGA.S2V(720.0, 480.0),
        0.1,
        0.001,
    )

    s = RGA.TrialGenSpec(
        ;
        motion_model = motion_model,
        resolve_steps = 10,
    )

    @time trials = [sample_scene(s) for _ = 1:5]
    exported = export_trials(trials, s)

    open("output/pilot.json", "w") do io; write(io, exported); end

end


main();
