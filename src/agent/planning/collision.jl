export RedGreenCollision,
    RGCollisionState,
    decision_expectation

"""
    ($TYPEDEF)

Protocol for counting collisions of objects that match target appearance `mat`.

---

$(TYPEDFIELDS)

"""
@with_kw struct RedGreenCollision <: PlanningProtocol
    "HSV color code for Red"
    hsv_red::Float64 = 0.0
    "HSV color code for Green"
    hsv_green::Float64 = 110.0
    "Maximum length of future horizon (default 3s)"
    max_sim_steps::Int64 = 72 
    "Threshold to increment collision"
    collision_threshold::Float64 = 0.20
end

mutable struct RGCollisionState <: MentalState{RedGreenCollision}
    chain::Vector{Trace}
    expectation::Float64
end

function RGCollisionState(p::RedGreenCollision)
    RGCollisionState(Trace[], NaN)
end

function MentalModule(p::RedGreenCollision)
    MentalModule(p, RGCollisionState(p))
end

# helper to extract planning state
function decision_expectation(pm::MentalModule{T}) where {T<:RedGreenCollision}
    _, state = mparse(pm)
    state.expectation
end

include("gen.jl")

function planning_proxy(m::MentalModule{RedGreenCollision}, tr::WMTrace)
    p, _ = mparse(m)
    rtr = seed_k_model(p, tr)
    get_retval(rtr)
end

function seed_k_model(p::RedGreenCollision, tr::WMTrace)
    t, _, wm = get_args(tr)
    istate = get_last_state(tr)
    seed_k_model(t, p, wm, istate)
end

# function seed_recurse_model(p::RedGreenCollision,
#                             wm::WorldModel,
#                             istate::WorldState)
#     args = (SimulationNode(0, istate, wm, p), 1)
#     recurse_trace, _ =
#         generate(recurse_model, args)
#     return recurse_trace
# end

function seed_k_model(t::Int,
                      p::RedGreenCollision,
                      wm::WorldModel,
                      istate::WorldState)
    args = (t, istate, wm, p)
    trace, _ =
        generate(kmodel_dynamic, args)
    return trace
end

function seed_state!(state::RGCollisionState, protocol::RedGreenCollision,
                     perception::MentalModule{RGPerception})

    vp, vs = mparse(perception)
    traces = Vector{Trace}(undef, vp.pf.particles)

    ups = sample_unweighted_traces(vs.chain.particles, vp.pf.particles)
    @inbounds for i=1:vp.pf.particles
        st = get_last_state(ups[i])
        traces[i] = seed_k_model(protocol, ups[i])
    end
    state.chain = traces
    return nothing
end

"""

$(SIGNATURES)

Computes the marginal over collision counts.

Also updates the \$\\delta \\pi\$ records in the attention module.
"""
function step_module!(planner::MentalModule{T},
                      t::Int,
                      perception::MentalModule{V}
                      ) where {T<:RedGreenCollision,
                               V<:PerceptionProtocol}
    # Propogate info from perception
    protocol, state = mparse(planner)
    seed_state!(state, protocol, perception)
    # Initial estimate of marginal red-green ratio
    state.expectation = approximate_rg_marginal(protocol, state.chain)
    return nothing
end

function approximate_rg_marginal(p::RedGreenCollision, traces::Vector{<:Trace})
    n = length(traces)
    scores = Vector{Float64}(undef, n)
    ratios = Vector{Float64}(undef, n)
    @inbounds for i = 1:n
        trace = traces[i]
        scores[i] = get_score(trace)
        ratios[i], _ = get_retval(trace)
    end
    total_mass = logsumexp(scores)
    expectation = -Inf
    @inbounds for i = 1:n
        inc = ratios[i] + scores[i] - total_mass
        expectation = logsumexp(expectation, inc)
    end
    return expectation
end

# function extend_frontier(pl::RedGreenCollision, tr::Trace)
#     red, green = red_green_marginal(tr)
#     # early stopping if collision is found
#     while red < pl.collision_threshold && green < pl.collision_threshold
#         tr = advance_trace(tr)
#         red, green = red_green_marginal(tr)
#     end
#     ratio = (red / (red + green))
#     (tr, ratio)
# end

# function red_green_ratio(pl::RedGreenCollision, tr::InertiaTrace)
#     red, green = red_green_marginal(pl, tr)
#     (red / (red + green))
# end

function red_green_marginal(pl::RedGreenCollision, ws::WorldState)
    ntargets = length(ws.dynamic)
    nobstacles = length(ws.static)
    col_prob   = 0.0
    mass_red   = 0.0
    mass_green = 0.0
    @inbounds for i = 1:ntargets
        tobj, tpos, _ = ws.dynamic[i]
        tshape = tobj.shape
        for j = 1:nobstacles
            obstacle = ws.static[j]
            color = obstacle.color
            if isapprox(color, pl.hsv_red)
                col_prob = collision_probability(tshape, obstacle.shape,
                                                 tpos, obstacle.pos)
                mass_red = max(mass_red, col_prob)
            elseif isapprox(color, pl.hsv_green)
                col_prob = collision_probability(tshape, obstacle.shape,
                                                 tpos, obstacle.pos)
                mass_green = max(mass_green, col_prob)
            end
        end
    end
    (mass_red, mass_green)
end

# function collision_probs(tr::InertiaTrace)
#     error("TODO")
# end
# function collision_probs(ws::WorldState)
#     target = get_target(tr)
#     no = length(wm.obstacles)
#     probs = Vector{Float64}(undef, no)
#     collision_probs!(probs, target, wm.obstacles)
#     return probs
# end

# function collision_probs!(probs::Vector{Float64},
#                           target::Circle,
#                           obstacles::Vector{Rectangle})
#     no = min(length(probs), length(obstacles))
#     @inbounds for i = 1:no
#         probs[i] =
#             collision_probability(target, obstacles[i])
#     end
#     return nothing
# end

# function acc_collision_probs!(probs::Vector{Float64},
#                               target::Circle,
#                               obstacles::Vector{Rectangle})
#     no = min(length(probs), length(obstacles))
#     @inbounds for i = 1:no
#         probs[i] +=
#             collision_probability(target, obstacles[i])
#     end
#     return nothing
# end


function collision_probability(c::Circle, r::Rectangle,
                               c_pos::S2V, r_pos::S2V)
    # Distance between object and wall
    d, _ = distance(c, r, c_pos, r_pos)
    exp(-max(abs(d), 0.01))
end

function update_k_trace(tr::KMDTrace, istate::WorldState)
    (_, wm, rg) = get_args(tr)
    args = (t, istate, wm, rg)
    argdiffs = (NoChange(), UnknownChange(), NoChange(), NoChange())
    new_tr, w, _... = update(tr, args, argdiffs, choicemap())
    pi = get_retval(tr)
    new_pi = get_retval(new_tr)
    @show pi
    @show new_pi
    return log(abs(new_pi - pi)) + w
end

function update_k_trace(tr::KModelTrace, istate::WorldState)
    node, t = get_args(tr)
    args = (SimulationNode(node.dt, istate, node.wm, node.rg), t)
    argdiffs = (UnknownChange(), NoChange())
    new_tr, w, _... = update(tr, args, argdiffs, choicemap())
    pi = get_retval(tr)
    new_pi = get_retval(new_tr)
    return log(abs(new_pi - pi)) + w
end

function proxy_delta_pi(m::MentalModule{RedGreenCollision}, tr::WMTrace)
    protocol, dm_state = mparse(m)
    st = get_last_state(tr)
    delta_pi = -Inf
    n = length(dm_state.chain)
    @inbounds for i = 1:n
        trace = dm_state.chain[i]
        w = update_k_trace(trace, st)
        delta_pi = logsumexp(delta_pi, w)
    end
    delta_pi - log(n)
end

function proxy_delta_pi(m::MentalModule{RedGreenCollision}, tr::WMTrace, i::Int)
    protocol, dm_state = mparse(m)
    st = get_last_state(tr)
    k_trace = dm_state.chain[i]
    delta_pi = update_k_trace(k_trace, st)
end

function paint_state(m::MentalModule{RedGreenCollision},
                     drawing, ret_finish=true)
    paint_rg_predictions!(drawing, m)
    paint_rg_expectation!(drawing, m)
    ret_finish && finish()
    return drawing
end

function paint_rg_predictions!(drawing, m::MentalModule{RedGreenCollision})
    p, s = mparse(m)
    opacity = 1.0 / length(s.chain)
    for trace = s.chain, state = get_states(trace), i = 1:ndynamic(state)
        x, pos, _ = state.dynamic[i]
        paint!(x.shape, pos, x.color, opacity, 0.3)
    end

    return nothing
end
function paint_rg_expectation!(drawing, m::MentalModule{RedGreenCollision})
    p, s = mparse(m)
    paint_rg_bar!(s.expectation, drawing.width, drawing.height)
    return nothing
end


function paint_rg_bar!(
    rg::Float64,                  # value in [0, 1]
    canvas_w::Float64,
    canvas_h::Float64,
    bar_w::Float64  = 16.0,
    bar_h::Float64  = 200.0,
    margin::Float64 = 20.0,
    hue_low::Float64  = 0.35,       # green  (hue in [0,1])
    hue_high::Float64 = 0.0,        # red
)
    rg = clamp(rg, 0.05, 1.0)

    # ── Position: right side of canvas, vertically centred ──────────────────
    # Luxor origin() is at canvas centre, y-axis points DOWN
    bar_x = -canvas_w/2 + margin + bar_w/2
    bar_y = -bar_h/2                # top of bar in Luxor coords

    # ── Background track ────────────────────────────────────────────────────
    @layer begin
        sethue(0.15, 0.15, 0.15)   # dark track
        setopacity(0.4)
        Luxor.box(Point(bar_x, 0.0), bar_w, bar_h, :fill)
    end

    # ── Filled portion (grows upward from bottom) ───────────────────────────
    fill_h   = bar_h * rg
    fill_top = bar_y + (bar_h - fill_h)          # top edge of filled rect
    fill_cy  = fill_top + fill_h/2               # centre in Luxor coords

    hue  = hue_low + rg * (hue_high - hue_low) # interpolate green→red
    fill_color = Colors.HSV(hue * 360, 0.85, 0.9)

    @layer begin
        sethue(fill_color)
        setopacity(0.9)
        Luxor.box(Point(bar_x, fill_cy), bar_w, fill_h, :fill)
    end

    # ── Border ───────────────────────────────────────────────────────────────
    @layer begin
        sethue(0.7, 0.7, 0.7)
        setopacity(0.8)
        setline(1.0)
        Luxor.box(Point(bar_x, 0.0), bar_w, bar_h, :stroke)
    end

    # ── Label ────────────────────────────────────────────────────────────────
    @layer begin
        sethue(0.0, 0.0, 0.0)
        setopacity(1.0)
        fontsize(9)
        text("$(round(Int, rg*100))%",
             Point(bar_x, bar_y - 8.0),
             halign=:center, valign=:bottom)
        text("Pr(Red)",
             Point(bar_x, bar_h/2 + 12.0),
             halign=:center, valign=:bottom)
    end

    return nothing
end
