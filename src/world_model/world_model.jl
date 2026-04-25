
include("shapes.jl")

export WorldModel,
    WorldState,
    StaticObject,
    DynamicObject,
    StaticState,
    DynamicState

abstract type MotionModel end
abstract type GraphicsModel end

"""
    $TYPEDEF

An object that does not change.

---

$TYPEDFIELDS
"""
struct StaticObject
    "Position"
    pos::S2V
    "Shape type"
    shape::Shape
    "HSV space, assumed saturation of 1"
    color::Float64
end

struct DynamicObject
    state_idx::Int
    "Shape type"
    shape::Shape
    "HSV space, assumed saturation of 1"
    color::Float64
end

"""

"""
struct WorldModel
    motion  ::MotionModel
    graphics::GraphicsModel
    dimensions::S2V
end

struct StaticState
    objects::Vector{StaticObject}
end

struct DynamicState
    objects::Vector{DynamicObject}
    positions::Vector{S2V}
    velocities::Vector{S2V}
end

function DynamicState(prev::DynamicState)
    DynamicState(prev.objects,
                 copy(prev.positions),
                 copy(prev.velocities))
end

import Base.getindex


function Base.getindex(st::StaticState, i::Int)
    st.objects[i]
end

function Base.getindex(st::DynamicState, i::Int)
    (st.objects[i], st.positions[i], st.velocities[i])
end

import Base.length
Base.length(st::StaticState) = length(st.objects)
Base.length(st::DynamicState) = length(st.objects)

function update_position!(st::DynamicState, i::Int, v::S2V)
    st.positions[i] = v
    return nothing
end

function update_velocity!(st::DynamicState, i::Int, v::S2V)
    st.velocities[i] = v
    return nothing
end

struct WorldState
    "Move around"
    dynamic::DynamicState
    "Don't move"
    static::StaticState
end

nstatic(ws::WorldState) = length(ws.static)
ndynamic(ws::WorldState) = length(ws.dynamic)
nobjects(ws::WorldState) = nstatic(ws) + ndynamic(ws)

include("motion.jl")
include("graphics/graphics.jl")
include("gen.jl")
include("visuals.jl")
