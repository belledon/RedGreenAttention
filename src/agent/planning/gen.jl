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
