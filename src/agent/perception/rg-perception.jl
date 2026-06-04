export RGPerception, RGPerceptionState

struct RGPerception <: PerceptionProtocol
    pf::PFProtocol
    initial_args::Tuple
    initial_constraints::ChoiceMap
end

state_type(::Type{RGPerception}) = RGPerceptionState

# State definition
mutable struct RGPerceptionState <: MentalState{RGPerception}
    chain::PFChain
end

# State constructor
RGPerceptionState(v::RGPerception) =
    RGPerceptionState(
        PFChain(v.pf, vis_model, v.initial_args, v.initial_constraints)
    )

function MentalModule(p::RGPerception)
    MentalModule(p, RGPerceptionState(p))
end

const WM_ARG_DIFFS =
    (Gen.UnknownChange(), Gen.NoChange(), Gen.NoChange())

function step_args(p::RGPerception, t::Int)
    (_, wm, istate) = p.initial_args
    args = (t, wm, istate)
    (args, WM_ARG_DIFFS)
end

function step_module!(perception::MentalModule{V},
                      t::Int,
                      obs::ChoiceMap,
                      ) where {V<:RGPerception}
    p, q = mparse(perception)
    args, argdiffs = step_args(p, t)
    # Preattentive step
    inference_step!(q.chain, p.pf, args, argdiffs, obs)
    return nothing
end

function paint_state(m::MentalModule{RGPerception}, ret_finish=true)
    # unpack data
    p, q = mparse(m)
    _, istate, wm = p.initial_args
    particles = q.chain.particles.traces # REVIEW: this are not `unweighted`

    # initialize
    x, y = wm.dimensions
    drawing = init_viz!(x, y)

    # draw static elements
    for i = 1:nstatic(istate)
        x = istate.static[i]
	    paint!(x.shape, x.pos, x.color)
    end

    # draw particle states
    opacity = 3.0 / length(particles)
    for particle = particles
        ws = get_last_state(particle)
        for i = 1:ndynamic(ws)
            x, pos, _ = ws.dynamic[i]
            paint!(x.shape, pos, x.color, opacity)
        end
    end
	ret_finish && finish()
    return drawing
end
