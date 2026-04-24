export BilliardBrownian

struct BilliardBrownian <: MotionModel
    jitter::Float64
    collision_thresh::Float64
end

function resolve_motion(model::BilliardBrownian,
                        state::WorldState,
                        jitter::Union{Vector{S2V}, Nothing} = nothing)

    nstatic = length(state.static)
    ndynamic = length(state.dynamic)

    new_dynamic = DynamicState(state)

    # Apply random jitter
    if !isnothing(jitter)
        new_vel += jitter
    end

    for i = 1:ndynamic
        obj, pos, vel = state.dynamic[i]
        new_pos, new_vel =
            scan_for_collision(model, obj, pos, vel, state.static)
        update_velocity!(state.dynamic, i, new_vel)
    end
    

    WorldState(new_dynamic, state.static)
end


function scan_for_collision(model::BilliardBrownian,
                            src::DynamicObject,
                            pos::S2V,
                            vel::S2V,
                            others::StaticState)
    n = length(others)
    @inbounds for i = 1:n
        other = others.objects[i]
        collided, angle =
            collision(model, src.shape, other.shape, pos, other.pos)
        if collided
            pos, vel =
                resolve_collision(model, src.shape, pos, vel, angle)
            break
        end
    end
    # No collision
    (pos, vel)
end


function collision(model::BilliardBrownian,
                   a::Shape,
                   b::Shape,
                   a_pos::S2V,
                   b_pos::S2V)
    abs(distance(a, b, a_pos, b_pos)) <
        model.collision_thresh
end

function distance(a::Circle, b::Circle, a_pos::S2V, b_pos::S2V)
    l2_center = norm(b_pos - a_pos)
    l2_center - a.radius - b.radius
end


function distance(a::Circle, b::Rectangle, a_pos::S2V, b_pos::S2V)
    # 1. Translate circle center relative to rect center
    dx, dy = a_pos - b_pos

    # 2. Rotate by -angle to align with b's local axes
    cos_a =  cos(b.angle)
    sin_a =  sin(b.angle)
    lx =  cos_a * dx + sin_a * dy   # local x
    ly = -sin_a * dx + cos_a * dy   # local y

    # 3. Find the closest point on the AABB [-hw,hw] x [-hh,hh] to local a center
    nearest_x = clamp(lx, -b.hw, b.hw)
    nearest_y = clamp(ly, -b.hh, b.hh)

    # 4. distance to the closest point within the a's radius
    dist = sqrt((lx - nearest_x)^2 + (ly - nearest_y)^2)
    return dist - a.radius
end

function distance(a::Rectangle, b::Circle, a_pos, b_pos)
    distance(b, a, b_pos, a_pos)
end

function resolve_collision(model::BilliardBrownian,
                           src::Circle,
                           pos::S2V,
                           vel::S2V,
                           angle::Float64)
    
    n = S2V(sin(angle), cos(angle))
    new_vel = vel - 2 * dot(vel, n) * n
    (pos, new_vel)
end

