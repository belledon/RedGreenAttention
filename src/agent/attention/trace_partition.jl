export TracePartition,
    latent_size,
    get_coord,
    select_prop,
    WMPartition

""" A procedure to selectively index and process traces"""
abstract type TracePartition{T<:Gen.Trace} end

"""
    latent_size(p::TracePartition{T}, tr::T) where {T<:Gen.Trace}

Determine the number of latents exposed for selective processing.
"""
function latent_size end


"""
    get_coord(p::TracePartition{T}, tr::T, i::Int) where {T<:Gen.Trace}

Get the representational coordinate of latent `i` in the trace.
"""
function get_coord end


@with_kw struct WMPartition <: TracePartition{WMTrace}
    "Seperation factor for time dimension"
    time_factor::Float64 = 100.0
end

function get_coord(p::WMPartition, tr::WMTrace, idx::Int)
    t, _... = get_args(tr)
    obj = get_dynamic_object(tr, idx)
    x, y = obj.pos
    S3V(x, y, p.time_factor * t)
end

function get_prop(::WMPartition, ::WMTrace, ::Int)
    object_ancestral_proposal
end
