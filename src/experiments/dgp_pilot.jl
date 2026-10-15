
@with_kw struct TrialGenSpec
    scene_x::Float64 = 720.0
    scene_y::Float64 = 480.0

    min_n_disc::Int = 3
    max_n_disc::Int = 4
    "Disc radius in world units"
    disc_radius::Float64 = 15.0
    disc_vel::Float64 = 5.0

    "Maximum rectangles present"
    max_rect::Int = 5
    "Minimum rectangles present"
    min_rect::Int = 3
    "Whether the scene has occluders"
    has_occluder::Bool = false


    # Motion
    resolve_steps::Int = 30
    max_sim_steps::Int = 300
    motion_model::BilliardBrownian 
end

@with_kw struct TrialScore
    "Smallest difference in time between Red or Green"
    red_green_time_tol::Int64 = 6

end

const DISC_COLORS = [
    190.0,
    210.0,
    230.0,
]

const RED = 0.0
const GREEN = 105.0
const YELLOW = 50.0

function resolve_initial_state(s::TrialGenSpec,
                               rectangles,
                               # rect_positions,
                               disc_positions,
                               disc_velocities)
    nd = length(disc_positions)
    ds = DynamicState(
        collect(1:nd),
        disc_positions,
        disc_velocities,
        fill(Circle(s.disc_radius), nd),
        DISC_COLORS[1:nd],
    )

    nr = length(rectangles)
    statics = Vector{StaticObject}(undef, nr)
    for i = 1:nr
        color = if i === 1
            RED
        elseif i === 2
            GREEN
        else
            YELLOW
        end
        cx,cy,hw,hy = rectangles[i]
        statics[i] = StaticObject(
            S2V(cx, cy),
            Rectangle(hw, hy, 0.0),
            color,
            true
        )
    end
    ss = StaticState(statics)
    
    ws = WorldState(ds, ss)
    for t = 1:s.resolve_steps
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

"""
    partition_cells(region, k; min_frac=0.12) -> Vector{NTuple{4,Float64}}

Recursively bisect a rectangular region into at least `k` disjoint
sub-rectangles, using `k - 1` splits. Each split cuts the cell with the
largest perimeter along its longer axis, at a uniform random position
bounded away from the cell edges.

# Arguments
- `region::NTuple{4,Float64}`: the room as `(x0, y0, x1, y1)` — min corner
  and max corner. For RGA's world coordinates use
  `(-scene_x/2, -scene_y/2, scene_x/2, scene_y/2)`; for a top-left-origin
  (screen/pixel) convention use `(0.0, 0.0, scene_w, scene_h)`.
- `k::Int`: number of cells to produce. Must satisfy `k ≥ 1`; the returned
  vector has exactly `k` cells when `k ≥ 2` (for `k = 1` the region itself
  is returned).
- `min_frac::Float64`: each split position `t ∈ [min_frac, 1 - min_frac]`
  along the split axis, as a fraction of that axis. Bounds the aspect
  ratio of the smallest possible sliver; `0.12` prevents near-degenerate
  cuts.

# Returns
Exactly `k` rectangles `(x0, y0, x1, y1)` that tile `region` with no
gaps and no overlaps — non-overlap of anything placed strictly inside
distinct cells is therefore guaranteed by construction.
"""
function partition_cells(region, k::Int; min_frac=0.12)
    cells = [region]
    while length(cells) < k
        # split the largest cell along its longer axis
        (_, i) = findmax(c -> (c[3]-c[1]) + (c[4]-c[2]), cells)
        c = cells[i]
        w, h = c[3]-c[1], c[4]-c[2]
        t = uniform(min_frac, 1 - min_frac)     # split position, bounded
        if w ≥ h
            a = (c[1], c[2], c[1] + t*w, c[4])
            b = (c[1] + t*w, c[2], c[3], c[4])
        else
            a = (c[1], c[2], c[3], c[2] + t*h)
            b = (c[1], c[2] + t*h, c[3], c[4])
        end
        cells[i] = a; push!(cells, b)
    end
    return cells
end

"""
    sample_rectangles(k, room_w, room_h, rect_max_w, rect_max_h;
                      margin=8.0) -> Vector{NTuple{4,Float64}}

Sample `k` non-overlapping rectangles inside a room, one per cell of a
recursive partition (see [`partition_cells`](@ref)). Non-overlap is
guaranteed by construction — there is no rejection loop, so the function
always terminates after exactly `k` placements.

All coordinates are in the same units as `room_w`/`room_h` (RGA uses
world units; the jsPsych plugin uses pixels). Rectangles are returned in
**center + half-extent form**: `(cx, cy, hw, hh)`, matching RGA's
`StaticObject.pos::S2V` and `Rectangle(hw, hh, angle)`. To convert to the
jsPsych plugin's `x, y, width, height` (also center-based), use
`width = 2*hw`, `height = 2*hh`.

# Arguments
- `k::Int`: number of rectangles to place. Any `k ≥ 1` is accepted;
  larger `k` yields smaller cells and thus smaller sampled rectangles.
- `room_w, room_h::Float64`: room size. The partition is built over
  `(0, 0)` to `(room_w, room_h)`; if your coordinates are RGA's
  center-origin world, shift the result by `(+room_w/2, -room_h/2)`
  afterward (y flip, per `visuals.jl`).
- `rect_max_w::Float64`: **full** (not half) maximum rectangle width —
  sampled widths are drawn from `[0.5, 1.0] * rect_max_w` and then
  capped by the available space in the cell.
- `rect_max_h::Float64`: same, for height.
- `margin::Float64 = 8.0`: minimum clearance, in the same units,
  between every rectangle edge and its cell boundary. This is what
  guarantees non-overlap under floating-point round-off (cells share
  exact boundaries; a strict inset keeps placed rectangles disjoint even
  at the shared edge) and doubles as a visual separation guarantee
  (two adjacent cells each inset by `margin` ⇒ ≥ `2*margin` between
  rectangles).

# Returns
A vector of `k` tuples `(cx, cy, hw, hh)` — centers and half-extents.
"""
function sample_rectangles(k::Int, room_w, room_h, rect_max_w, rect_max_h;
                           margin::Float64 = 8.0)
    cells = partition_cells((-0.45*room_w, -0.45*room_h, 0.45*room_w, 0.45*room_h), k)
    # out = Tuple{Float64,Float64,Float64,Float64}[]   # (x,y,hw,hh) center form
    out = Vector{NTuple{4, Float64}}(undef, k)
    for (i, c) in enumerate(cells)
        cw, ch = c[3]-c[1], c[4]-c[2]
        aw, ah = cw - 2*margin, ch - 2*margin
        # aw > 0.5*rect_max_w || throw(ArgumentError("cell too small in x"))
        # ah > 0.5*rect_max_h || throw(ArgumentError("cell too small in y"))
        sw = min(rect_max_w * uniform(0.5, 1.0), aw)
        sh = min(rect_max_h * uniform(0.5, 1.0), ah)
        cx = c[1] + margin + sw/2 + rand() * (aw - sw)
        cy = c[2] + margin + sh/2 + rand() * (ah - sh)
        out[i] = (cx, cy, sw/2, sh/2)
    end
    return out
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
    # nrect ~ uniform_discrete(s.min_rect, s.max_rect)
    # rectangles ~ Map(sample_rectangle)(Fill(s, nrect))
    # rect_positions ~ Map(sample_position)(Fill(s, nrect))
    nrect = 5
    rectangles = sample_rectangles(nrect, s.scene_x, s.scene_y,
                                   100., 200.0)
    
    # ndiscs ~ uniform_discrete(s.min_n_disc, s.max_n_disc)
    ndiscs = 2 
    disc_positions ~ Map(sample_position)(Fill(s, ndiscs))
    disc_velocities ~ Map(sample_velocity)(Fill(s, ndiscs))
    
    # run motion forward a few steps to resolve collisions
    istate = resolve_initial_state(s, rectangles,
                                   # rect_positions,
                                   disc_positions,
                                   disc_velocities)
    return istate
end

# NOTE: assumes last state has red or green collision
function rg_dists(last_state::WorldState)
    ndisc = ndynamic(last_state)
    dists = Matrix{Float64}(undef, 2, ndisc)

    for i = 1:ndisc
        disc = last_state.dynamic[i]
        dpos = disc.pos

        red_dist = Inf
        gre_dist = Inf
        for rect = last_state.static
            dist_to_disc = norm(rect.pos - dpos)
            if rect.color == RED
                red_dist = min(red_dist, dist_to_disc)
            elseif rect.color == GREEN
                gre_dist = min(gre_dist, dist_to_disc)
            end
        end

        dists[1, i] = red_dist
        dists[2, i] = gre_dist
    end

    return dists
end

function run_to_rg_collision(s::TrialGenSpec, istate::WorldState)
    ws = istate
    last_t = 0
    red_or_green = [false, false]

    ndiscs = length(istate.dynamic)
    traj = Array{Float64}(undef, 2, ndiscs, s.max_sim_steps + 1)

    for (i, o) in enumerate(istate.dynamic)
        traj[1, i, 1] = o.pos[1]
        traj[2, i, 1] = o.pos[2]
    end

    for t = 1:s.max_sim_steps
        red_or_green, ws = step_motion(s.motion_model, ws)
        for (i, o) in enumerate(ws.dynamic)
            traj[1, i, t+1] = o.pos[1]
            traj[2, i, t+1] = o.pos[2]
        end
        if any(red_or_green)
            last_t = t
            break
        end
    end

    red_or_green, last_t, ws, traj[:, :, 1:last_t+1]
end


function step_motion(model::BilliardBrownian,
                     state::WorldState)

    nstatic = length(state.static)
    ndynamic = length(state.dynamic)

    red_or_green = [false, false]
    new_dynamic = DynamicState(state.dynamic)
    for i = 1:ndynamic
        obj = state.dynamic[i]

        collided, d, angle, other_idx =
            scan_for_collision(model, obj, state.static)

        pos = obj.pos
        vel = obj.vel

        if collided
            pos, vel =
                resolve_collision(model, obj.shape, pos, vel, d, angle)
        end

        if collided && other_idx <= 2
            red_or_green[other_idx] = true
        end

        pos, vel = resolve_oob(model, radius(obj), pos, vel)
        update_position!(new_dynamic, i, pos)
        update_velocity!(new_dynamic, i, vel)
    end
    ws = WorldState(new_dynamic, state.static)

    red_or_green, ws
end
