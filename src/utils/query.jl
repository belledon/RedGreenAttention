export Query,
    SequentialQuery

struct SequentialQuery <: Query
    model::Gen.GenerativeFunction
    constraints::Gen.ChoiceMap
    args::Tuple
    argdiffs::Tuple
end


const WM_ARG_DIFFS =
    (Gen.UnknownChange(), Gen.NoChange(), Gen.NoChange())

"""

Returns the args and argdiffs for a particular time
"""
function (sq::SequentialQuery)(t::Int)
    args = step_increment_args((t,), sq.args, sq.argdiffs)
    (args, sq.argdiffs)
end

function step_increment_args(next_args::Tuple, args::Tuple, argdiffs::Tuple)
    new_args = collect(args)
    ndiff = count(x -> isa(x, UnknownChange), argdiffs)
    @assert length(next_args) == ndiff "Length missmatch for diff args"
    c = 1
    @inbounds for i = 1:length(args)
        if isa(argdiffs[i], UnknownChange)
            new_args[i] = next_args[c]
            c += 1
        end
    end
    return Tuple(new_args)
end
