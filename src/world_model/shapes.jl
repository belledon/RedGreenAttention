abstract type Shape end


struct Circle
    radius::Float64
end

struct Rectangle
    hw::Float64
    hh::Float64
    angle::Float64
end

function bbox_iou(rect::Rectangle)
    area = 4 * rect.hw * rect.hh
    aca = abs(cos(angle))
    asa = abs(sin(angle))
    bbw = aca*2*rect.hw + asa*2*rect.hh
    bbh = asa*2*rect.hw + aca*2*rect.hh
    area / (bbw*bbh)
end
