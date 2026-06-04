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

function seed_recurse_model(p::RedGreenCollision, tr::WMTrace)
    t, _, wm = get_args(tr)
    istate = get_last_state(tr)
    args = (SimulationNode(0, istate, wm, p), 1)
    recurse_trace, _ =
        generate(recurse_model, args)
    return recurse_trace
end

function seed_state!(state::RGCollisionState, protocol::RedGreenCollision,
                     perception::MentalModule{RGPerception})

    vp, vs = mparse(perception)
    traces = Vector{Trace}(undef, vp.pf.particles)

    ups = sample_unweighted_traces(vs.chain.particles, vp.pf.particles)
    @inbounds for i=1:vp.pf.particles
        st = get_last_state(ups[i])
        traces[i] = seed_recurse_model(protocol, ups[i])
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
        ratios[i] = get_retval(trace)
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
            if color == pl.hsv_red
                col_prob = collision_probability(tshape, obstacle.shape,
                                                 tpos, obstacle.pos)
                mass_red = max(mass_red, col_prob)
            elseif color == pl.hsv_green
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
    exp(-max(d, 0.01))
end
