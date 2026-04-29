module RedGreenAttention

using Gen
using Luxor
using GenRFS
using StaticArrays
using Distributions
using LinearAlgebra
using DocStringExtensions

greet() = print("Hello World!")

include("utils/utils.jl")
include("world_model/world_model.jl")
include("agent/agent.jl")

end # module RedGreenAttention
