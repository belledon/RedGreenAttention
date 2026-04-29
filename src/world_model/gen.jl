export world_model

@gen (static) function jitter_prior(var::Float64)
    dx ~ normal(0., var)
    dy ~ normal(0., var)
    result::S2V = S2V(dx, dy)
    return result
end

@gen (static) function kernel(t::Int,
                     prev::WorldState,
                     wm::WorldModel)
    nd = ndynamic(prev)
    jitter ~ Gen.Map(jitter_prior)(Fill(wm.motion.jitter, nd))
    next::WorldState = resolve_motion(wm.motion, prev, jitter)
    rfes = predict(wm.graphics, next)
    xs ~ MaskRFS(rfes)
    return next
end

@gen (static) function world_model(t::Int,
                                   istate::WorldState,
                                   wm::WorldModel)

    states ~ Gen.Unfold(kernel)(t, istate, wm)
    return states
end
