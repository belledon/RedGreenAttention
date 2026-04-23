export von_mises, VonMises

struct VonMises <: Gen.Distribution{Float64} end

const vonmises = VonMises()

function Gen.random(::VonMises, mu::Float64, k::Float64)
    rand(Distributions.VonMises(mu, k))
end

function Gen.logpdf(::VonMises, x::Float64, mu::Float64, k::Float64)
    Distributions.logpdf(Distributions.VonMises(mu, k))
end

(::VonMises)(mu, k) = Gen.random(vonmises, mu, k)

# TODO: add gradients? 
Gen.has_output_grad(::VonMises) = false
Gen.logpdf_grad(::VonMises, value::Set, args...) = (nothing,)
