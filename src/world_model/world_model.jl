
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
@kwdef struct StaticObject
    "Position"
    pos::S2V
    "Shape type"
    shape::Shape
    "HSV space, assumed saturation of 1"
    color::Float64
    "Whether the object collides with others"
    collides::Bool = false
end

"""
    $TYPEDEF

An object that changes from interactions.
This struct only contains an index to an object's
state. The actualy properties are stored in `DynamicState`

---

$TYPEDFIELDS

"""
struct DynamicObject
    "Index to retrieve properties in DynamicState"
    state_idx::Int
    "Position"
    pos::S2V
    vel::S2V
    "Shape type"
    shape::Shape
    "HSV space, assumed saturation of 1"
    color::Float64
end

"""

"""
struct WorldModel
    motion    ::MotionModel
    graphics  ::GraphicsModel
    dimensions::S2V
end

struct StaticState
    objects::Vector{StaticObject}
end

struct DynamicState
    objects::Vector{Int}
    positions::Vector{S2V}
    velocities::Vector{S2V}
    shape::Vector{Shape}
    color::Vector{Float64}
end

function DynamicState(prev::DynamicState)
    # NOTE: Assumes that shape and color does not change
    DynamicState(
        prev.objects,
        copy(prev.positions),
        copy(prev.velocities),
        prev.shape,
        prev.color
    )
end

import Base.getindex

function Base.getindex(st::StaticState, i::Int)::StaticObject
    st.objects[i]
end

function Base.getindex(st::DynamicState, i::Int)::StaticObject
    DynamicObject(
        st.objects[i],
        st.positions[i],
        st.velocities[i],
        st.shape[i],
        st.color[i]
    )
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

"""
    $TYPEDEF

The state of the world.

---

$TYPEDFIELDS
"""
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
include("trace.jl")
include("visuals.jl")
