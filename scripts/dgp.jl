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

function sample_scene(s::RGA.TrialGenSpec)

    istate = RGA.initial_state(s)
    (r_or_g, t_col, ws) =
        RGA.run_to_rg_collision(s, istate)
    dists = RGA.rg_dists(ws)
    to_probe = rg_score(dists)

    attempts = 1
    while t_col < 48 || !any(r_or_g) || to_probe == 0 
        istate = RGA.initial_state(s)
        (r_or_g, t_col, ws) =
            RGA.run_to_rg_collision(s, istate)
        dists = RGA.rg_dists(ws)
        to_probe = rg_score(dists)
        attempts += 1
    end

    meta = SceneMeta((;t_col, r_or_g,
                     dists, to_probe))
    (istate, meta, attempts)
end

function main()

    motion_model = RGA.BilliardBrownian(
        RGA.S2V(720.0, 480.0),
        0.1,
        0.001,
    )

    s = RGA.TrialGenSpec(
        ;
        motion_model = motion_model
    )

    @time for _ = 1:10
        (istate, meta, attempts) = sample_scene(s)
        @show attempts
        display(meta)
    end
end


main();
