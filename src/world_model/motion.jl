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
    dx, dy = a_pos - b_pos

    cos_a =  cos(b.angle)
    sin_a =  sin(b.angle)
    lx =  cos_a * dx + sin_a * dy
    ly = -sin_a * dx + cos_a * dy

    if abs(lx) <= b.hw && abs(ly) <= b.hh
        # inside: nearest face direction is the outward normal
        dx_face = b.hw - abs(lx)
        dy_face = b.hh - abs(ly)
        if dx_face < dy_face
            nx_local, ny_local = sign(lx), 0.0
            dist = -(dx_face + a.radius)
        else
            nx_local, ny_local = 0.0, sign(ly)
            dist = -(dy_face + a.radius)
        end
    else
        # outside: normal = (center − nearest point on box), normalized
        nearest_x = clamp(lx, -b.hw, b.hw)
        nearest_y = clamp(ly, -b.hh, b.hh)
        nx_local = lx - nearest_x
        ny_local = ly - nearest_y
        nrm = sqrt(nx_local^2 + ny_local^2)
        if nrm == 0.0
            # center on the box surface: use the dominant axis
            nx_local, ny_local = 0.0, sign(ly)
            if abs(lx) >= abs(ly)
                nx_local, ny_local = sign(lx), 0.0
            end
        else
            nx_local /= nrm
            ny_local /= nrm
        end
        dist = nrm - a.radius
    end

    # rotate normal back to global space; resolve_collision reflects
    # about this vector and ejects via pos - d .* n (d < 0 → outward)
    n_glob = S2V(cos_a * nx_local - sin_a * ny_local,
                 sin_a * nx_local + cos_a * ny_local)
    angle = atan(n_glob[2], n_glob[1])
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
