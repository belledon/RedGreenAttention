export PilotExp

mutable struct PilotExp <: Experiment
    wm::WorldModel
    istate::WorldState
    observations::Vector{ChoiceMap}

    function PilotExp(wm::WorldModel, istate::WorldState, steps::Int)
        o = Vector{ChoiceMap}(undef, steps)
        e = new(wm, istate, o)
        load_trial!(e, steps)
        return e
    end
end

function write_obs!(cm::ChoiceMap, wm::WorldModel, st::WorldState, t::Int)
    # REVIEW: being lazy, sampling from graphics GM
    rfes = predict(wm.graphics, st)
    masks = MaskRFS(rfes)
    for i = 1:length(masks)
        cm[:states => t => :xs => i] = masks[i]
    end
    return nothing
end

function load_trial!(experiment::PilotExp, steps::Int)
    @unpack wm, istate, observations = experiment
    next_state = experiment.istate
    for t = 1:steps
        next_state = resolve_motion(wm.motion, next_state)
        cm = choicemap()
        write_obs!(cm, wm, next_state, t)
        observations[t] = cm
    end
    return nothing
end

function step_experiment!(agent::Agent, experiment::PilotExp, t::Int)
    obs = experiment.observations[t]
    step_agent!(agent, t, obs)
    # TODO: add hooks...
    return nothing
end
