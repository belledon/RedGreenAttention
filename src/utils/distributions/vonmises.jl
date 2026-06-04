export vonmises, VonMises

struct VonMises <: Gen.Distribution{Float64} end

const vonmises = VonMises()

function Gen.random(::VonMises, mu::Float64, k::Float64)
    (rand(Distributions.VonMises(k)) + mu) % pi
end

function Gen.logpdf(::VonMises, x::Float64, mu::Float64, k::Float64)
    d = Distributions.VonMises(k)
    s = (x - mu) % pi
    # @show minimum(d)
    # @show maximum(d)
    # @show s
    Distributions.logpdf(d, s)
end

(::VonMises)(mu, k) = Gen.random(vonmises, mu, k)

# TODO: add gradients? 
Gen.has_output_grad(::VonMises) = false
Gen.logpdf_grad(::VonMises, value::Set, args...) = (nothing,)
