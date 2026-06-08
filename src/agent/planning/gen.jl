export KMDTrace, KModelTrace

@gen (static) function kmodel_advance(dt::Int,
                                      ws::WorldState,
                                      rg::RedGreenCollision)
    r,g = red_green_marginal(rg, ws)
    # Determine ratio: 1 = red, 0 = green
    ratio = r / (r + g)
    # stop if close to red or green
    w = advance_weight(dt, rg.max_sim_steps, r, g)
    stop ~ bernoulli(w)
    result::Tuple{Bool, Float64, Float64} = (stop, r, g)
    return result
end

function advance_weight(dt::Int, max_sim_steps::Int, r::Float64, g::Float64)
    # ran out of time
    dt > max_sim_steps ? 0.0 : max(r, g)
end

@gen function kmodel_dynamic(t0::Int,
                             state::WorldState,
                             wm::WorldModel,
                             rg::RedGreenCollision)
    r = 0.0
    g = 0.0
    total_dt = 0
    for dt = 1:rg.max_sim_steps
        # Did red or green collision occur?
        go_next = {(:go_next, dt)} ~ kmodel_advance(dt, state, rg)
        (stop, r, g) = go_next
        stop && break
        # Simulate further into the future
        state = {(:kernel, dt)} ~ cog_kernel(dt, state, wm)
        total_dt = dt
    end
    # Determine ratio: 1 = red, 0 = green
    ratio = r / (r + g)
    return (ratio, total_dt)
end

const KMDTrace = Gen.get_trace_type(kmodel_dynamic)

function object_ancestral_proposal(trace::KMDTrace,
                                   idx::Int)
    _, dt = get_retval(trace)
    t_range = max(1, dt-5):dt
    selection = select(
        ((:kernel, t) => :jitter => idx for t = t_range)...
    )
    new_trace, w, _ = regenerate(trace, selection)

    if isinf(w) || isnan(w)
        find_inf_scores(new_trace)
        error("Invalid score from ancestral proposal")
    end
    (new_trace, w)
end

function get_last_state(trace::KMDTrace)
    istate, _... = get_args(trace)
    _, dt = get_retval(trace)
    dt === 0 ? istate : trace[(:kernel, dt)]
end

function get_last_time(trace::KMDTrace)
    istate, _... = get_args(trace)
    _, dt = get_retval(trace)
    return dt
end

function get_states(trace::KMDTrace)
    k = get_last_time(trace)
    k === 0 && return WorldState[]

    states = Vector{WorldState}(undef, k)
    for t = 1:k
        state = trace[(:kernel, t)]
        states[t] = state
    end
    return states
end

struct SimulationNode
    dt::Int
    ws::WorldState
    wm::WorldModel
    rg::RedGreenCollision
end

function advance_weight(node::SimulationNode, r::Float64, g::Float64)
    # ran out of time
    node.dt > node.rg.max_sim_steps ? 0.0 : 1.0 - max(r, g)
end

@gen (static) function production_model(node::SimulationNode)
    # Simulate next step
    next_state ~ cog_kernel(node.dt, node.ws, node.wm)
    next_node::SimulationNode =
        SimulationNode(node.dt + 1, next_state, node.wm, node.rg)
    # Determine if red or green obstacle is hit
    r,g = red_green_marginal(node.rg, node.ws)
    # Determine ratio: 1 = red, 0 = green
    ratio = r / (r + g)
    # stop if close to red or green
    w = advance_weight(next_node, r, g)
    grow ~ bernoulli(w)
    children::Vector{SimulationNode} = grow ? [next_node] : SimulationNode[]
    result = Production(ratio, children)
    return result
end

@gen (static) function aggregation_model(prod::Float64, children::Vector{Float64})
    # just pass deepest red-green ratio
    ratio::Float64 = isempty(children) ? prod : first(children)
    return ratio
end

const recurse_model = Recurse(production_model,
                              aggregation_model,
                              1, # only one branch
                              SimulationNode,# U (production to children)
                              Float64, # V (production to aggregation)
                              Float64) # W (aggregation to parents)

const KModelTrace = Gen.get_trace_type(recurse_model)


function object_ancestral_proposal(trace::KModelTrace,
                                   idx::Int)
    max_t = length(trace.production_traces)
    selection = select(
        ((t, Val(:production)) => :next_state => :jitter => idx for t = 1:max_t)...
    )
    new_trace, w, _ = regenerate(trace, selection)

    if isinf(w) || isnan(w)
        find_inf_scores(new_trace)
        error("Invalid score from ancestral proposal")
    end
    (new_trace, w)
end

function get_last_state(trace::KModelTrace)
    max_t = length(trace.production_traces)
    last_subtrace = trace.production_traces[max_t]
    return last_subtrace[:next_state]
end
