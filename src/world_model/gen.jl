export vis_model, cog_model

@gen (static) function jitter_prior(var::Float64)
    dx ~ normal(0., var)
    dy ~ normal(0., var)
    result::S2V = S2V(dx, dy)
    return result
end

@gen (static) function vis_kernel(t::Int,
                                  prev::WorldState,
                                  wm::WorldModel)
    nd = ndynamic(prev)
    jitter ~ Gen.Map(jitter_prior)(Fill(wm.motion.jitter, nd))
    next::WorldState = resolve_motion(wm.motion, prev, jitter)
    rfes = predict(wm.graphics, next)
    xs ~ MaskRFS(rfes)
    return next
end

@gen (static) function cog_kernel(t::Int,
                                  prev::WorldState,
                                  wm::WorldModel)
    nd = ndynamic(prev)
    jitter ~ Gen.Map(jitter_prior)(Fill(wm.motion.jitter*0.5, nd))
    next::WorldState = resolve_motion(wm.motion, prev, jitter)
    return next
end

@gen (static) function vis_model(t::Int,
                                 istate::WorldState,
                                 wm::WorldModel)

    states ~ Gen.Unfold(vis_kernel)(t, istate, wm)
    return states
end

@gen (static) function cog_model(t::Int,
                                 istate::WorldState,
                                 wm::WorldModel)

    states ~ Gen.Unfold(cog_kernel)(t, istate, wm)
    return states
end

