
@with_kw struct TrialGenSpec
    scene_x::Float64 = 720.0
    scene_y::Float64 = 480.0

    min_n_disc::Int = 1
    max_n_disc::Int = 3
    "Disc radius in world units"
    disc_radius::Float64 = 10.0

    "Maximum rectangles present"
    max_rect::Int = 5
    "Minimum rectangles present"
    min_rect::Int = 2
    "Whether the scene has occluders"
    has_occluder::Bool = false
end

@with_kw struct TrialScore
    "Smallest difference in time between Red or Green"
    red_green_time_tol::Int64 = 6

end

const DISC_COLORS = [
    deg2rad(190),
    deg2rad(210),
    deg2rad(230),
]

function resolve_initial_state(s::TrialGenSpec,
                               rectangles,
                               positions,
                               velocities)
    nd = length(positions)
    ds = DynamicState(
        map(DynamicObject, 1:nd),
        positions,
        velocities,
        Fill(Circle(s.disc_radius), nd)
        DISC_COLORS[1:nd],
    )
    ws = WorldState(
        StaticState(rectangles),
        ds,
    )

end

@gen function initial_state(s::TrialGenSpec)
    nrect ~ uniform_discrete(s.min_rect, s.max_rect)
    rectangles ~ Map(sample_rectangle)(Fill(s, nrect))
    
    ndiscs ~ uniform_discrete(s.min_n_disc, s.max_n_disc)
    discs ~ Map(sample_discs)(Fill(s, ndiscs))

    # run motion forward a few steps to resolve collisions
    istate = resolve_initial_state(s, rectangles, discs)
    return istate
end
