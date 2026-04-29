export AdaptiveComputation,
    UniformProtocol

################################################################################
# Uniform Rationing
################################################################################

export UniformProtocol

@with_kw struct UniformProtocol <: AttentionProtocol
    "Number of rejuvenation moves"
    moves::Int64 = 10
    partition::TracePartition = WMPartition()
end

struct UniformAuxState <: MentalState{UniformProtocol} end

function AuxState(::UniformProtocol)
    UniformAuxState()
end

function module_step!(att::MentalModule{<:UniformProtocol},
                      t::Int,
                      vis::MentalModule{<:AdaptiveParticleFilter})
    visp, visstate = mparse(vis)
    attend!(visstate, visp, att)
    return nothing
end

function attend!(chain::APFChain,
                 pf::AdaptiveParticleFilter,
                 att::MentalModule{<:UniformProtocol})

    protocol, aux = mparse(att)
    state = chain.particles

    np = length(state.traces)

    for i = 1:np # iterate through each particle
        trace = state.traces[i]
        nobj = representation_count(trace)
        # number of moves per object
        steps_per_obj = round(Int, protocol.moves / nobj)
        # Stage 2
        # select latent and C_k
        for j = 1:nobj
            for _ = 1:steps_per_obj
                prop = get_prop(protocol.partition, trace, j)
                # Apply computation, estimate dS
                new_trace, alpha = prop(trace)
                if log(rand()) < alpha # update particle
                    trace = new_trace
                    state.log_weights[i] += alpha
                end
            end
        end

        state.traces[i] = trace
    end
    return nothing
end

function AttentionModule(m::UniformProtocol)
    MentalModule(m, UniformAuxState())
end

# HACK: dummy function - called in collision counter
function update_dPi!(att::MentalModule{A},
                     obj::WMObject,
                     delta::Float64) where {A<:UniformProtocol}
    return nothing
end

################################################################################
# Adaptive Computation
################################################################################


@with_kw struct AdaptiveComputation{T} <: AttentionProtocol
    partition::TracePartition{T} = WMPartition()
    "Minimum number of moves"
    base_steps::Int64 = 3
    "Size of attention hash map"
    buffer_size::Int64 = 100
    "Distance metric in spatio-temporal maps (x,y,t)"
    map_metric_weights::S3V = S3V(0.1, 0.1, 0.8)
    map_metric::PreMetric = WeightedEuclidean(map_metric_weights)
    "Number of nearest neighbors"
    nns::Int64 = 5
    "Importance softmax temperature"
    itemp::Float64 = 3.0
    "Maximumal load"
    load::Int64 = 20
    "Load curve slope"
    load_m::Float64 = 20.0
    "Load curve intercept"
    load_x0::Float64 = 5.0
end

mutable struct AdaptiveAux <: MentalState{AdaptiveComputation}
    "Impact of C_k on planning"
    dPi::HashMap
    "Impact of C_k on perception"
    dS::HashMap
end

AdaptiveAux(n::Int) = AdaptiveAux(HashMap(S3V, Float64, n),
                                  HashMap(S3V, Float64, n))

function AttentionModule(m::AdaptiveComputation)
    MentalModule(m, AdaptiveAux(m.buffer_size))
end

Base.isempty(x::AdaptiveAux) = isempty(x.dPi) || isempty(x.dS)


function update_dPi!(att::MentalModule{A},
                     obj::WMObject,
                     delta::Float64) where {A<:AdaptiveComputation}
    _, aux = mparse(att)
    coord = get_coord(obj)
    push_sample!(aux.dPi, coord, delta)
    return nothing
end

function update_dS!(att::MentalModule{A},
        partition::TracePartition{T},
        trace::T,
        j::Int, delta::Float64) where {A<:AdaptiveComputation, T}
    _, aux = mparse(att)
    coord = get_coord(partition, trace, j)
    push_sample!(aux.dS, coord, delta)
    return nothing
end

function update_task_relevance!(att::MentalModule{A}
                                ) where {A<:AdaptiveComputation}
    attp, attstate = mparse(att)
    fit_map!(attstate.dPi, attp.map_metric)
    fit_map!(attstate.dS , attp.map_metric)
    return nothing
end

function load(p::AdaptiveComputation, x::AdaptiveAux, deltas::Vector{Float64})
    isempty(x) && return p.load
    x = (logsumexp(deltas) - p.load_x0) / p.load_m
    p.load * exp(min(x, 0.0))
end

function task_relevance(x::AdaptiveAux,
                        partition::TracePartition{T},
                        trace::T,
                        k::Int = 25
                        ) where {T<:Gen.Trace}
    @unpack dPi, dS = x
    n = latent_size(partition, trace)
    # NOTE: case with empty estimate?
    # No info yet -> -Inf
    isempty(x) && return fill(-Inf, n)
    tr = Vector{Float64}(undef, n)
    # Preallocating reused arrays
    idxs, dists = zeros(Int32, k), zeros(Float32, k)
    for i = 1:n
        coord = get_coord(partition, trace, i)
        _dpi  = integrate!(idxs, dists, coord, dPi)
        _ds   = integrate!(idxs, dists, coord, dS )
        tr[i] = _dpi + _ds
    end
    return tr
end

function module_step!(att::MentalModule{<:AdaptiveComputation},
                      t::Int,
                      vis::MentalModule{<:AdaptiveParticleFilter})
    visp, visstate = mparse(vis)
    attend!(visstate, visp, att)
    return nothing
end

function attend!(chain::APFChain,
                 pf::AdaptiveParticleFilter,
                 att::MentalModule{<:AdaptiveComputation})
    protocol, aux = mparse(att)

    @unpack partition, base_steps, nns, itemp = protocol
    state = chain.particles

    np = length(state.traces)
    # l = load(protocol, aux) # load is shared across particles

    for i = 1:np # iterate through each particle
        trace = state.traces[i]
        # determine the importance of each latent
        deltas = task_relevance(aux, partition, trace, nns)
        importance = softmax(deltas, itemp)
        tload = load(protocol, aux, deltas)
        nobj = length(deltas)
        steps_per_obj = floor(Int, base_steps / nobj)
        # Stage 2
        # select latent and C_k
        for j = 1:nobj
            steps = steps_per_obj + round(Int, tload * importance[j])
            for _ = 1:steps
                prop = select_prop(partition, trace, j)
                # Apply computation, estimate dS
                new_trace, alpha = prop(trace)
                dS = min(alpha, 0.)
                if log(rand()) < alpha # update particle
                    trace = new_trace
                    state.log_weights[i] += alpha
                end
                # NOTE: continually updating partition map
                update_dS!(att, partition, trace, j, dS)
            end
        end

        state.traces[i] = trace
    end

    return nothing
end
