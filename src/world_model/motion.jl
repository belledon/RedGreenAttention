export BilliardBrownian

struct BilliardBrownian <: MotionModel
    dimensions::S2V
    jitter::Float64
    collision_thresh::Float64
end

function resolve_motion(model::BilliardBrownian,
                        state::WorldState,
                        jitter::Union{<:AbstractArray{S2V}, Nothing} = nothing)

    nstatic = length(state.static)
    ndynamic = length(state.dynamic)

    !isnothing(jitter) &&
        length(jitter) !== ndynamic &&
            error("jitter to state length missmatch")

    new_dynamic = DynamicState(state.dynamic)


    for i = 1:ndynamic
        obj = state.dynamic[i]
        # Apply random jitter
        if !isnothing(jitter)
            vx,vy = obj.vel + jitter[i]
            vel = S2V(
                clamp(vx, -15.0, 15.0),
                clamp(vy, -15.0, 15.0),
            )
        end

        collided, d, angle, other_idx =
            scan_for_collision(model, obj, state.static)

        pos = obj.pos
        vel = obj.vel

        if collided
            pos, vel =
                resolve_collision(model, obj.shape, pos, vel, d, angle)
        end

        # OOB resolution now uses the (possibly ejected) position and
        # the post-collision velocity.
        pos, vel = resolve_oob(model, radius(obj), pos, vel)
        update_position!(new_dynamic, i, pos)
        update_velocity!(new_dynamic, i, vel)
    end

    WorldState(new_dynamic, state.static)
end


function scan_for_collision(model::BilliardBrownian,
                            src::DynamicObject,
                            others::StaticState)::Tuple{Bool, Float64, Float64, Int}
    collided = false
    d = 0.0
    angle = 0.0
    other_idx = 0
    n = length(others)
    @inbounds for i = 1:n
        other = others.objects[i]
        collided, d, angle =
            collision(model, src.shape, other.shape, src.pos, other.pos)
        if collided
            other_idx = i
            break
        end
    end
    (collided, d, angle, other_idx)
end


function collision(model::BilliardBrownian,
                   a::Shape,
                   b::Shape,
                   a_pos::S2V,
                   b_pos::S2V)
    d, angle = distance(a, b, a_pos, b_pos)
    collided = d < model.collision_thresh
    angle = collided ? angle : 0.0
    (collided, d, angle)
end

function distance(a::Circle, b::Circle, a_pos::S2V, b_pos::S2V)
    l2_center = norm(b_pos - a_pos)
    (l2_center - a.radius - b.radius, 0.0)
end

function distance(a::Circle, b::Rectangle, a_pos::S2V, b_pos::S2V)
    # 1. Translate circle center relative to rect center
    dx, dy = a_pos - b_pos

    # 2. Rotate by -b.angle to align with rectangle's local axes.
    #    (lx, ly) is the circle center expressed in the rectangle's
    #    local frame: lx along the rectangle's width axis, ly along
    #    its height axis. After this rotation the rectangle is the
    #    axis-aligned box [-hw, hw] × [-hh, hh], and lx/ly are the
    #    components of the offset from rect center to circle center
    #    in that frame.
    cos_a =  cos(b.angle)
    sin_a =  sin(b.angle)
    lx =  cos_a * dx + sin_a * dy
    ly = -sin_a * dx + cos_a * dy

    # 3. Inside case: the circle center lies within the rectangle's
    #    local extents. The clamp below would return the circle's own
    #    center as the "nearest point" (dist = -radius always, normal
    #    inverted), so compute the minimal translation vector instead:
    #    the nearest face and the penetration depth through it.
    if abs(lx) <= b.hw && abs(ly) <= b.hh
        # dx_face: distance from the circle center to the nearest
        #          vertical face (lx = ±hw), measured along local x
        # dy_face: same, to the nearest horizontal face (ly = ±hh),
        #          measured along local y
        dx_face = b.hw - abs(lx)
        dy_face = b.hh - abs(ly)
        if dx_face < dy_face
            sx, sy = sign(lx), 0.0
            dist = -(dx_face + a.radius)
        else
            sx, sy = 0.0, sign(ly)
            dist = -(dy_face + a.radius)
        end
        gx = sx * (b.hw + a.radius)
        gy = sy * (b.hh + a.radius)
    else
        # 4. Outside case: nearest point on the axis-aligned box
        nearest_x = clamp(lx, -b.hw, b.hw)
        nearest_y = clamp(ly, -b.hh, b.hh)
        dist = sqrt((lx - nearest_x)^2 + (ly - nearest_y)^2) - a.radius
        gx = nearest_x; gy = nearest_y
    end

    # 5. Rotate the local contact point back to global space (+b.angle)
    g = S2V(cos_a * gx - sin_a * gy, sin_a * gx + cos_a * gy)
    angle = atan(g[2], g[1])
    (dist, angle)
end

function distance(a::Rectangle, b::Circle, a_pos, b_pos)
    distance(b, a, b_pos, a_pos)
end

function resolve_collision(model::BilliardBrownian,
                           src::Circle,
                           pos::S2V,
                           vel::S2V,
                           d::Float64,
                           angle::Float64)
    n = S2V(cos(angle), sin(angle))
    new_vel = vel - 2 * dot(vel, n) * n
    # Penetrating contact: eject along the outward normal. distance()
    # returns negative depth, so -d > 0 moves the disc to the surface.
    new_pos = d < 0 ? pos - d .* n : pos
    (new_pos, new_vel)
end

function resolve_oob(model::BilliardBrownian,
                     radius::Float64,
                     pos::S2V,
                     vel::S2V)
    new_pos = (x, y) = pos + vel
    if abs(x) > 0.5 * model.dimensions[1] - radius
        vel = vel .* S2V(-1., 1)
        new_pos = pos + vel
    elseif abs(y) > 0.5 * model.dimensions[2] - radius
        vel = vel .* S2V(1, -1)
        new_pos = pos + vel
    end
    new_pos, vel
end
