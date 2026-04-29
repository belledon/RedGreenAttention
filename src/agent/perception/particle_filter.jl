export AdaptiveParticleFilter,
    APFChain

using GenParticleFilters

"""
    ($TYPEDEF)

Perception Protocol that implements the adaptive computation interface in a particle filter.

---

$(TYPEDFIELDS)

"""
@with_kw struct AdaptiveParticleFilter <: PerceptionProtocol
    "Number of particles"
    particles::Int = 1
    "Effective sample size"
    ess::Real = particles * 0.5
end

mutable struct APFChain <: MentalState{AdaptiveParticleFilter}
    query::SequentialQuery
    particles::Gen.ParticleFilterState
end

function APFChain(prot::AdaptiveParticleFilter, q)
    particles =
        Gen.initialize_particle_filter(q.model,
                                       q.args,
                                       q.constraints,
                                       p.particles)
    APFChain(0, particles)
end

function PerceptionModule(p::AdaptiveParticleFilter, query)
    MentalModule(p, APFChain(p, query))
end


"""

$(SIGNATURES)

Internally samples particles for the next time step, conditioning on observations.
"""
function module_step!(perception::MentalModule{V},
                      t::Int,
                      obs::ChoiceMap,
                      ) where {V<:PerceptionProtocol}

    p, q = mparse(perception)
    # Resample before moving on...
    if effective_sample_size(q.particles) < proc.ess
        # Perform residual resampling, pruning low-weight particles
        pf_residual_resample!(q.particles)
    end
    args, argdiffs = q.query(t)
    # update the state of the particles
    Gen.particle_filter_step!(state, args, argdiffs, obs)
    return nothing
end

# function estimate_marginal(chain::PFChain{<:IncrementalQuery, <:AdaptiveParticleFilter},
#                            func::Function,
#                            args::Tuple)
#     @unpack state = chain
#     ws = state.log_weights
#     mass = logsumexp(ws)
#     acc = -Inf
#     @inbounds for i = 1:length(ws)
#         v = func(args..., state.traces[i])
#         w = ws[i] - mass
#         acc = logsumexp(acc, w + v)
#     end
#     if isnan(acc)
#         msg = "Marginal of $(func) lead to NaN, ws = $(ws);"
#         foreach(find_inf_scores, state.traces)
#         error(msg)
#     end
#     return acc
# end

# """
# Returns the MAP trace
# """
# function retrieve_map(chain::APChain)
#     @unpack state = chain
#     state.traces[argmax(state.log_weights)]
# end


# function reinit_chain(chain::APChain, template::InertiaTrace,
#                       cm = choicemap())
#     pf = estimator(chain)
#     q = estimand(chain)
#     steps = chain.steps # dt
#     _, wm, _ = q.args
#     ws = get_last_state(template)
#     args = (0, wm, ws)
#     q = IncrementalQuery(q.model, cm, args, INERTIA_ARG_DIFFS, 1)
#     Gen_Compose.initialize_chain(pf, q, steps)
# end
