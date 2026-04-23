
struct MaskGraphics <: GraphicsModel

end

include("mask.jl")

# TODO: import GenRFS
# const MaskRFS = RFGM(MRFS{Mask}(), (150, 1.0))

const MaskRFE = RandomFiniteElement{Mask}

function predict(gm::MaskGraphics, ws::WorldState)

    static_rfes = MaskRFE[]
    sizehint!(es, nstatic(ws))

    # 1. Render static elements
    for i = 1:nstatic(ws)
        static_rfes[i] = render_mask(ws.static[i], gm)
    end

    # Occlusion between dynamic and static?

    # for each static that overlaps but does not collide

end

function render_mask(obj::Rectangle, model::MaskGraphics)
    BernoulliElement{Mask}(
        1.0, # should always be present,
        (
            obj.pos,
            model.pos_var,
            S2V(2 * obj.hw, 2 * obj.hh),
            model.extents_var,
            bbox_iou(obj),
            model.fill_var,
            obj.color,
            model.color_var)
        )
    )
end


function scan_for_occlusion(model::MaskGraphics,
                            src::DynamicObject,
                            pos::S2V,
                            others::StaticState)
    n = length(others)
    @inbounds for i = 1:n
        other = others.objects[i]
        occluded, ratio =
            occlusion(model, src.shape, other.shape, pos, other.pos)
        if occluded
            pos, vel =
                resolve_occlusion(model, src.shape, pos, )
            break
        end
    end
    # No collision
    (pos, vel)
end
