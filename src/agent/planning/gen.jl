export KMDTrace, KModelTrace

@gen (static) function kmodel_advance(dt::Int,
                                      ws::WorldState,
                                      rg::RedGreenCollision)
    # marginal prob of hitting red or green first
    r,g = red_green_marginal(rg, ws)
    # stop if close to red or green
    w = advance_weight(dt, rg.max_sim_steps, r, g)
    stop ~ bernoulli(w)
    result::Tuple{Bool, Float64, Float64} = (stop, r, g)
    return result
end

function advance_weight(dt::Int, max_sim_steps::Int, r::Float64, g::Float64)
    # ran out of time
    w = dt > max_sim_steps ? 0.0 : max(r, g)
    return w
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
    # Use proxy of r-g diff if simulation budget ran out
    r,g = proxy_red_green_marginal(rg, state)
    # if total_dt === rg.max_sim_steps
    #     r,g = proxy_red_green_marginal(rg, state)
    # end
    # Determine ratio: 1 = red, -1 = green
    rgd = red_green_diff(rg, r, g)
    # true = red; false = green
    # decision_weight = 0.5*rgd + 0.5
    choose_rg ~ bernoulli(r)
    return (rgd, total_dt)
end

const KMDTrace = Gen.get_trace_type(kmodel_dynamic)

function object_ancestral_proposal(trace::KMDTrace,
                                   idx::Int,
                                   lookback::Int = 15)
    t0, _... = get_args(trace)
    _, dt = get_retval(trace)
    t_range = max(t0, dt-lookback):dt
    selection = select(
        ((:kernel, t) => :jitter => idx for t = t_range)...,
        :choose_rg
    )
    new_trace, w, _ = regenerate(trace, selection)

    # TODO: think about this more, perhaps cross compare
    # prev_decision_mass = project(trace, select(:choose_rg))
    # new_decision_mass = project(new_trace, select(:choose_rg))
    # delta_pi = abs(new_decision_mass - prev_decision_mass)

    org_rgdiff,_ = get_retval(trace)
    org_decision_weight = 0.5*org_rgdiff + 0.5

    new_rgdiff,_ = get_retval(new_trace)
    new_decision_weight = 0.5*new_rgdiff + 0.5

    # delta_pi = -(logit(org_decision_weight) - logit(new_decision_weight))
    delta_pi = log(abs(org_decision_weight - new_decision_weight))
    # println("OBJECT: $(idx)")
    # @show org_rgdiff
    # @show new_rgdiff
    # @show org_decision_weight
    # @show new_decision_weight
    # @show delta_pi

    # if delta_pi > -1
    #     orig_st = get_last_state(trace)
    #     new_st = get_last_state(new_trace)
    #     for i = 1:2
    #         println("OBJ: $(1)")
    #         println("ORIG:")
    #         @show orig_st.dynamic[i]
    #         println("NEW:")
    #         @show new_st.dynamic[i]
    #     end
    #     error()
    # end

    if isinf(w) || isnan(w)
        println("Checking original trace")
        hit, acc = find_inf_scores_recurse(trace.trie, [])
        if hit
            addr = foldl(pair, acc)
            println("Found -Inf at $addr")
        end
        println("Checking proposed trace")
        hit, acc = find_inf_scores_recurse(new_trace.trie, [])
        if hit
            # push!(acc, :stop)
            addr = foldl(pair, acc)
            println("Found -Inf at $addr")
            display(select(addr))
            display(get_selected(get_choices(trace), select(addr)))
            display(get_selected(get_choices(new_trace), select(addr)))
            display(get_args(new_trace[addr => :stop]))
        end
        # println("ORIGINAL:")
        # display(get_choices(trace))
        # println("NEW TRACE:")
        # display(get_choices(new_trace))
        error("Invalid score from ancestral proposal")
    end
    (new_trace, w, delta_pi)
end

function find_inf_scores_leaf!(acc, trie)
    hit = false
    for (key, choice_or_call) in Gen.get_leaf_nodes(trie)
        if isinf(choice_or_call.score)
            push!(acc, key)
            hit = true
            break
        end
    end
    return hit
end

function find_inf_scores_recurse(trie, acc)
    if find_inf_scores_leaf!(acc, trie)
        return (true, acc)
    end
    for (key, subtrie) in Gen.get_internal_nodes(trie)
        sub_acc = deepcopy(acc)
        push!(sub_acc, key)
        hit, sub_acc = find_inf_scores_recurse(subtrie, acc)
        if hit
            return (hit, sub_acc)
        end
    end

    return (false, [])
end

function find_inf_scores(tr::KMDTrace)
    t0, _... = get_args(tr)
    _, dt = get_retval(tr)
    t_range = max(t0, dt-5):dt
    for t = t_range
        selection = select((:kernel, t))
        w = project(tr, selection)
        println("Selection: $(selection) = $(w)")

        selection = select((:go_next, t))
        w = project(tr, selection)
        println("Selection: $(selection) = $(w)")
    end
    return nothing
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
