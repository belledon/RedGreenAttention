module RedGreenAttention

using Gen
using Luxor
using GenRFS
using StaticArrays
using Distributions
using LinearAlgebra
using DocStringExtensions
using Parameters: @unpack, @with_kw

greet() = print("Hello World!")

include("utils/utils.jl")
include("world_model/world_model.jl")
include("agent/agent.jl")
include("experiments/experiments.jl")

end # module RedGreenAttention
