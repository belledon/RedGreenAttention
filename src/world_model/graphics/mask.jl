export Mask, MaskRFS

struct Mask
    pos::S2V
    extents::S2V
    fill_ratio::Float64
    hsv::Float64
end

struct MaskRV <: Gen.Distribution{Mask} end

const maskrv = MaskRV()

function Gen.random(::MaskRV,
                    pos_mu::S2V,
                    pos_var::Float64,
                    extents_mu::S2V,
                    extents_var::Float64,
                    fill_mu::Float64,
                    fill_var::Float64,
                    color_mu::Float64,
                    color_var::Float64)

    # position - Normal
    x, y = Gen.random(broadcasted_normal, pos_mu, pos_var)
    # extents - Normal
    dx, dy = Gen.random(broadcasted_normal, extents_mu, extents_var)
    # fill - Beta (phi, kappa) -> (alpha, beta)
    alpha = fill_mu * fill_var
    beta = (1 - fill_mu) * fill_var
    f = Gen.random(Gen.beta, alpha, beta)
    # color - vonmises
    c = Gen.random(vonmises, color_mu, color_var)
    Mask(S2V(x,y), S2V(dx, dy), f, c)
end

function Gen.logpdf(::MaskRV,
                    x::Mask,
                    pos_mu::S2V,
                    pos_var::Float64,
                    extents_mu::S2V,
                    extents_var::Float64,
                    fill_mu::Float64,
                    fill_var::Float64,
                    color_mu::Float64,
                    color_var::Float64)
    # position - Normal
    w = Gen.logpdf(broadcasted_normal, x.pos, pos_mu, pos_var)
    # extents - Normal
    w += Gen.logpdf(broadcasted_normal, x.extents, extents_mu, extents_var)
    # fill - Beta (phi, kappa) -> (alpha, beta)
    alpha = fill_mu * fill_var
    beta = (1 - fill_mu) * fill_var
    w += Gen.logpdf(Gen.beta, x.fill_ratio, alpha, beta)
    # color - vonmises
    w += Gen.logpdf(vonmises, x.hsv, color_mu, color_var)
    return w
end

(::MaskRV)(pm, pv, em, ev, fm, fv, cm, cv) = Gen.random(maskrv, pm, pv, em, ev, fm, fv, cm, cv)

# TODO: add maskrv gradients? 
Gen.has_output_grad(::MaskRV) = false
Gen.logpdf_grad(::MaskRV, value, args...) = (nothing,)

# TODO: Implement mask visualization
# function paint!(p::ObjectPainter,  obs::AbstractVector{T}
#                        ) where {T<:Mask}
#     for i = eachindex(obs)
#         d = obs[i]
#         hue = 1.0 - ((d.i - 1) * .6 + .2)
#         sethue(hue, hue, hue)
#         setopacity(0.7)
#         box(Point(d.x, -d.y), 10.0, 10.0,
#             action = :fill)
#     end
#     return nothing
# end
