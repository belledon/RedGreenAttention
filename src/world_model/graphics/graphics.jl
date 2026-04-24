export MaskGraphics

struct MaskGraphics <: GraphicsModel
    pos_var::Float64
    extents_var::Float64
    fill_var::Float64
    color_var::Float64
end

include("mask.jl")

# TODO: import GenRFS
# const MaskRFS = RFGM(MRFS{Mask}(), (150, 1.0))

const MaskRFE = RandomFiniteElement{Mask}

function predict(gm::MaskGraphics, ws::WorldState)

    rfes = Vector{MaskRFE}(undef, nobjects(ws))

    # Render static elements
    for i = 1:nstatic(ws)
        x = ws.static[i]
        rfes[i] = render_mask(x.shape, x.pos, x.color, gm)
    end

    # Occlusion between dynamic and static
    for i in 1:ndynamic(ws)
        obj, pos, _ = ws.dynamic[i]
        bern_prob = scan_for_occlusion(gm, obj, pos, ws.static)
        rfes[i + nstatic(ws)] =
            render_mask(obj.shape, pos, obj.color, bern_prob, gm)
    end

    # TODO: Joined masks? 

    return rfes
end

function render_mask(shp::Rectangle,
                     pos::S2V,
                     color::Float64,
                     model::MaskGraphics)
    BernoulliElement{Mask}(
        1.0, # should always be present,
        maskrv,
        (
            pos,
            model.pos_var,
            S2V(2 * shp.hw, 2 * shp.hh),
            model.extents_var,
            bbox_iou(shp),
            model.fill_var,
            color,
            model.color_var
        )
    )
end

function render_mask(shp::Circle,
                     pos::S2V,
                     color::Float64,
                     ratio::Float64,
                     model::MaskGraphics)
    BernoulliElement{Mask}(
        clamp(ratio, 0.01, 0.99), # depends linearly on occlusion
        maskrv,
        (
            pos,
            model.pos_var,
            S2V(2 * shp.radius, 2 * shp.radius),
            model.extents_var,
            bbox_iou(shp),
            model.fill_var,
            color,
            model.color_var
        )
    )
end



function scan_for_occlusion(model::MaskGraphics,
                            src::DynamicObject,
                            pos::S2V,
                            others::StaticState)
    ratio = 0.0
    n = length(others)
    @inbounds for i = 1:n
        other = others.objects[i]
        ratio =
            occlusion(model, src.shape, other.shape, pos, other.pos)
        ratio > 0 && break
    end
    return ratio
end

function occlusion(::MaskGraphics,
                   a::Circle,
                   b::Rectangle,
                   a_pos::S2V,
                   b_pos::S2V)
    # d =   0, 0%
    # d =  -r, 50%
    # d = -2r, 100%
    d = distance(a, b, a_pos, b_pos)
    # [-r, r] ; + r
    # [0, 2r] ; / 2r
    # [0, 1]
    ratio = min(0.0, -0.5 * d / a.radius)
end
