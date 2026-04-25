abstract type Shape end


struct Circle <: Shape
    radius::Float64
end

const PI_HALF = pi / 2
const PI_QT   = pi / 4

function bbox_iou(c::Circle)
    # area = pi * c.radius * c.radius
    # area / (4 * c.radius * c.radius)
    PI_QT
end

struct Rectangle <: Shape
    hw::Float64
    hh::Float64
    angle::Float64
end

function bbox_iou(rect::Rectangle)
    area = 4 * rect.hw * rect.hh
    aca = abs(cos(rect.angle))
    asa = abs(sin(rect.angle))
    bbw = aca*2*rect.hw + asa*2*rect.hh
    bbh = asa*2*rect.hw + aca*2*rect.hh
    area / (bbw*bbh)
end
