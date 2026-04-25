export init_viz!,
    paint!,
    paint_state,
    paint_masks

import Colors

function init_viz!(w::Float64, h::Float64,
                   back_color="white")
    d = Drawing(w, h)
    origin()
    background(back_color)
    return d
end

function paint_state(ws::WorldState, wm::WorldModel, ret_finish=true)
    x, y = wm.dimensions
    d = init_viz!(x, y)
    for i = 1:ndynamic(ws)
        x, pos, _ = ws.dynamic[i]
        paint!(x.shape, pos, x.color)
    end
    for i = 1:nstatic(ws)
        x = ws.static[i]
	    paint!(x.shape, x.pos, x.color)
    end
	ret_finish && finish()
	return d
end

function paint_masks(masks::AbstractArray{Mask}, wm::WorldModel)
    x, y = wm.dimensions
    d = init_viz!(x, y)
    n = length(masks)
    for i = 1:n
        paint!(masks[i])
    end
	finish()
	return d
end


function paint!(shp::Rectangle, pos::S2V, hue::Float64,
                opacity=1.0)
    color = Colors.MSC(rad2deg(hue))
    point = Luxor.Point(pos[1], -pos[2])
    # Isolate the rotation for a specific object
    @layer begin
        setopacity(opacity)
        sethue(color)
        rotate(shp.angle) 
        Luxor.box(point, 2*shp.hw, 2*shp.hh, :fill)
    end
    return nothing
end

function paint!(shp::Circle, pos::S2V, hue::Float64,
                opacity=1.0)
    color = Colors.MSC(rad2deg(hue))
    point = Luxor.Point(pos[1], -pos[2])
    @layer begin
        setopacity(opacity)
        sethue(color)
        Luxor.circle(point, shp.radius, :fill)
    end
    return nothing
end

function paint!(mask::Mask, opacity=1.0)
    color = Colors.MSC(rad2deg(mask.hsv))
    point = Luxor.Point(mask.pos[1], -mask.pos[2])
    w, h = mask.extents
    @layer begin
        setopacity(opacity)
        sethue(color)
        Luxor.box(point,
                  mask.fill_ratio*w,
                  mask.fill_ratio*h,
                  :fill)
        Luxor.box(point, w, h, :stroke)
    end
    return nothing
end
