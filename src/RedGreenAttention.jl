module RedGreenAttention

using StaticArrays
using DocStringExtensions

greet() = print("Hello World!")

include("utils/utils.jl")
include("world_model/world_model.jl")

end # module RedGreenAttention
