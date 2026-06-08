
################################################################################
# Ancestral Proposals
################################################################################

function object_ancestral_proposal(trace::WMTrace,
                                   idx::Int)
    t, _... = get_args(trace)
    selection = select(:kernel => t => :jitter => idx)
    new_trace, w, _ = regenerate(trace, selection)

    if isinf(w) || isnan(w)
        find_inf_scores(new_trace)
        error("Invalid score from ancestral proposal")
    end
    (new_trace, w)
end
