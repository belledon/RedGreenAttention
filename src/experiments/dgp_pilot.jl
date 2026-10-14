
@with_kw struct TrialGenSpec
    scene_x::Float64 = 720.0
    scene_y::Float64 = 480.0

    min_n_disc::Int = 1
    max_n_disc::Int = 3
    "Disc radius in world units"
    disc_radius::Float64 = 10.0
    disc_vel::Float64 = 3.0

    "Maximum rectangles present"
    max_rect::Int = 5
    "Minimum rectangles present"
    min_rect::Int = 2
    "Whether the scene has occluders"
    has_occluder::Bool = false


    # Motion
    resolve_steps::Int = 10
    motion_model::BilliardBrownian 
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

const RED = 0.0
const GREEN = 105.0
const YELLOW = 50.0

function resolve_initial_state(s::TrialGenSpec,
                               rectangles,
                               rect_positions,
                               disc_positions,
                               disc_velocities)
    nd = length(disc_positions)
    ds = DynamicState(
        map(DynamicObject, 1:nd),
        disc_positions,
        disc_velocities,
        fill(Circle(s.disc_radius), nd),
        DISC_COLORS[1:nd],
    )

    nr = length(rect_positions)
    statics = Vector{StaticObject}(undef, nr)
    for i = 1:nr
        color = if i === 1
            RED
        elseif i === 2
            GREEN
        else
            YELLOW
        end
        statics[i] = StaticObject(
            rect_positions[i],
            rectangles[i],
            color,
            true
        )
    end
    ss = StaticState(statics)
    
    ws = WorldState(ds, ss)
    for _ = 1:s.resolve_steps
        ws = resolve_motion(s.motion_model, ws)
    end
    return ws
end

@gen function sample_rectangle(s::TrialGenSpec)
    dx ~ uniform(50.0, 120.0)
    dy ~ uniform(25.0, 200.0)
    rect = Rectangle(dx, dy, 0.0)
    return rect
end

@gen function sample_position(s::TrialGenSpec)
    dx = 0.45 * s.scene_x
    dy = 0.45 * s.scene_y
    x ~ uniform(-dx, dx)
    y ~ uniform(-dy, dy)
    pos = S2V(x, y)
    return pos
end


@gen function sample_velocity(s::TrialGenSpec)
    angle ~ uniform(0.0, 2*pi)
    vel = S2V(s.disc_vel * cos(angle), s.disc_vel * sin(angle))
    return vel
end

@gen function initial_state(s::TrialGenSpec)
    nrect ~ uniform_discrete(s.min_rect, s.max_rect)
    rectangles ~ Map(sample_rectangle)(Fill(s, nrect))
    rect_positions ~ Map(sample_position)(Fill(s, nrect))
    
    ndiscs ~ uniform_discrete(s.min_n_disc, s.max_n_disc)
    disc_positions ~ Map(sample_position)(Fill(s, ndiscs))
    disc_velocities ~ Map(sample_velocity)(Fill(s, ndiscs))
    
    # run motion forward a few steps to resolve collisions
    istate = resolve_initial_state(s, rectangles,
                                   rect_positions,
                                   disc_positions,
                                   disc_velocities)
    return istate
end
