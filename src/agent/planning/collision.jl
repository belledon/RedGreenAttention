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
    uncertainty::Float64
end

function RGCollisionState(p::RedGreenCollision)
    RGCollisionState(Trace[], 0.5, 1.0)
end

function MentalModule(p::RedGreenCollision)
    MentalModule(p, RGCollisionState(p))
end

# helper to extract planning state
function decision_expectation(pm::MentalModule{T}) where {T<:RedGreenCollision}
    _, state = mparse(pm)
    state.expectation
end

function red_green_diff(p::RedGreenCollision, red::Float64, green::Float64)
    (red - green)# * (red + green)
end

include("gen.jl")

# function planning_proxy(m::MentalModule{RedGreenCollision}, tr::WMTrace)
#     p, _ = mparse(m)
#     rtr = seed_k_model(p, tr)
#     get_retval(rtr)
# end

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

    # traces = sample_unweighted_traces(vs.chain.particles, vp.pf.particles)
    vtraces = vs.chain.particles.traces
    @inbounds for i=1:vp.pf.particles
        # st = get_last_state(vtraces[i])
        traces[i] = seed_k_model(protocol, vtraces[i])
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
    update_expectation!(state, protocol)
    return nothing
end

function update_expectation!(state::RGCollisionState, p::RedGreenCollision)
    new_expectation, _ =
        approximate_rg_marginal(p, state.chain)
    # smoothing
    state.expectation = 0.3*state.expectation + 0.7*new_expectation
    return nothing
end

function approximate_rg_marginal(p::RedGreenCollision, traces::Vector{<:Trace})
    n = length(traces)
    # m = 0.0
    red_count = 0
    # red_mass = -Inf
    green_count = 0
    # green_mass = -Inf
    @inbounds for i = 1:n
        trace = traces[i]
        rgdiff,_ = get_retval(trace)
        # println("| R-G: $(rgdiff) |")
        # if trace[:choose_rg]
        if rgdiff > 0.05
            red_count += 1
        elseif rgdiff < -0.05
            green_count += 1
        end
    end
    # println("| R: $(red_count) | G: $(green_count) |")
    # Compute the expected proportion of choose Red
    # weighting by trace log scores. 
    # total_mass = logsumexp(red_mass, green_mass)
    # exp_red_count = red_count * exp(red_mass - total_mass)
    # exp_green_count = green_count * exp(green_mass - total_mass)
    # exp_prop_red = exp_red_count / (exp_red_count + exp_green_count)
    # @show red_count
    # @show green_count
    # @show exp_red_count
    # @show exp_green_count
    exp_prop_red = red_count / n
    # Transform to difference score
    diff = 2.0 * exp_prop_red - 1.0
    (diff, 0.0)
    # m = m / n
    # (m, 0.0)
end

function red_green_marginal(pl::RedGreenCollision, ws::WorldState)
    ntargets = length(ws.dynamic)
    nobstacles = length(ws.static)
    col_prob   = 0.0
    mass_red   = 0.0
    mass_green = 0.0
    @inbounds for i = 1:ntargets
        tobj, tpos, tvel = ws.dynamic[i]
        tshape = tobj.shape
        for j = 1:nobstacles
            obstacle = ws.static[j]
            color = obstacle.color
            if isapprox(color, pl.hsv_red)
                col_prob = collision_probability(tshape, obstacle.shape,
                                                 tpos, obstacle.pos, tvel)
                mass_red = max(mass_red, col_prob)
            elseif isapprox(color, pl.hsv_green)
                col_prob = collision_probability(tshape, obstacle.shape,
                                                 tpos, obstacle.pos, tvel)
                mass_green = max(mass_green, col_prob)
            end
        end
    end
    # @show (mass_red, mass_green)
    (mass_red, mass_green)
end


# COL PROB
function collision_probability(c::Circle, r::Rectangle,
                               c_pos::S2V, r_pos::S2V,
                               c_vel::S2V)
    # Distance between object and wall
    d, angle = distance(c, r, c_pos, r_pos)
    # n = S2V(cos(-angle), sin(-angle))
    # orth_vel = max(dot(n, c_vel), 0.1)
    # w = abs(d) / orth_vel
    # w = exp(-max(w, 0.1))
    # @show c_pos
    # @show r_pos
    # @show d
    # @show w
    # clamp(w, 0.001, 0.999)
    clamp(exp(-max(d/7, 0.1)), 0.001, 0.999)
end

# Just look at raw distance
function proxy_red_green_marginal(pl::RedGreenCollision, ws::WorldState)
    ntargets = length(ws.dynamic)
    nobstacles = length(ws.static)
    d       = 0.0
    d_red   = Inf
    d_green = Inf
    @inbounds for i = 1:ntargets
        tobj, tpos, tvel = ws.dynamic[i]
        tshape = tobj.shape
        for j = 1:nobstacles
            obstacle = ws.static[j]
            color = obstacle.color
            # Only consider red or green obstacles
            if isapprox(color, pl.hsv_red) || isapprox(color, pl.hsv_green)
                d, _ = distance(tshape, obstacle.shape, tpos, obstacle.pos)
                d = abs(d)
                if isapprox(color, pl.hsv_red)
                    d_red = min(d_red, d)
                elseif isapprox(color, pl.hsv_green)
                    d_green = min(d_green, d)
                end
            end
        end
    end
    # red is closer (green has more distance)
    mass_red = d_green / (d_red + d_green)
    mass_green = 1.0 - mass_red
    (mass_red, mass_green)
end

function proxy_delta_pi(m::MentalModule{RedGreenCollision}, tr::WMTrace, i::Int)
    protocol, dm_state = mparse(m)
    st = get_last_state(tr)
    k_trace = dm_state.chain[i]
    delta_pi = update_k_trace(k_trace, st)
end

function update_k_trace(tr::KMDTrace, istate::WorldState)
    (t, _, wm, rg) = get_args(tr)
    args = (t, istate, wm, rg)
    argdiffs = (NoChange(), UnknownChange(), NoChange(), NoChange())
    new_tr, w, _... = update(tr, args, argdiffs, choicemap())
    # @show w
    # return w
    pi,_ = get_retval(tr)
    new_pi,_ = get_retval(new_tr)
    @show pi
    @show new_pi
    return log(abs(new_pi - pi))
end
