export InferenceProtocol

abstract type InferenceProtocol end

include("proposals.jl")
include("particle_filter.jl")
