### A Pluto.jl notebook ###
# v0.20.28

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 94b64dee-5f9f-4ff2-9b96-bfef6c9e759e
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	
	using Gen
	using Luxor
	using PlutoUI
	
	using Revise
	using GenRFS
	using RedGreenAttention

	using RedGreenAttention: S2V, Rectangle, Circle
	using RedGreenAttention: RGPerception, PFProtocol, MentalModule, PFChain, step_module!
end

# ╔═╡ 94515ebc-6010-11f1-83cf-791b54166c74
html"""
<style>
    @media screen {
        main {
            margin: 0 auto;
            max-width: 3000px;
            padding-left: max(100px, 10%);
            padding-right: max(100px, 10%);
        }
    }
	pluto-output {
    font-size: 1.2em; /* Adjust base text size */
    font-family: "Your Font", sans-serif;
	}

pluto-output h1 {
    font-size: 2.5rem; /* Adjust header sizes */
}

pluto-output h2 {
    font-size: 2.0rem;
}

cm-editor .cm-scroller,
.cm-editor .cm-content {
    font-family: "Fira Code", monospace !important;
    font-size: 16px !important; /* Adjust size here */
}
</style>
""" 

# ╔═╡ e331cb74-b8bb-4805-a2cd-a79efc3e44c1
md"""
# Preamble
"""

# ╔═╡ 769e17ce-98b6-4c16-a86f-0529ceef84fd
function initial_state()
	static = StaticState([
		StaticObject(S2V(-20, -150), Rectangle(50, 10, 0.),   1.0),   # Red
		StaticObject(S2V(170,  -50), Rectangle(10, 50, 0.), 110.0),   # Green
		StaticObject(S2V(130,  -10), Rectangle(10, 90, 0.),  60.0),   # Yellow
		])
	
	c = Circle(10.0)
	dynamic = DynamicState(
		[DynamicObject(1, c, 230.0), DynamicObject(1, c, 275.0)],
		[S2V(-70, 120),              S2V(0, 100)],
		[S2V(5, -4),                 S2V(0, 1)]
	)
	WorldState(dynamic, static)
end;

# ╔═╡ c7283dc3-fa0f-4999-85c5-ae1bca7810b5
begin
	# world model parameters
	dimensions = S2V(400, 400);
	wm = WorldModel(
		BilliardBrownian(dimensions, 0.5, 0.01),
		MaskGraphics(1.0, 1.0, 3.0, 5.0),
		dimensions)
	# Perception
	istate = initial_state();
	init_args = (0, istate, wm);
	pf_protocol = PFProtocol(;particles = 10);
	perception_protocol = RGPerception(pf_protocol, init_args, choicemap());
	# Decision Making
	decision_protocol = RedGreenCollision(;hsv_red = 1.0, max_sim_steps=48);
end;


# ╔═╡ b446ffce-2f35-4b91-8e18-8c614b559ff8
begin 
    ktrace, _ = generate(RedGreenAttention.kmodel_dynamic, (1, istate, wm, decision_protocol))
    new_ktrace = ktrace
    ratio1, _ = get_retval(ktrace)
    for _ = 1:10
        new_ktrace, _... = RedGreenAttention.object_ancestral_proposal(ktrace, 2)
        ratio2, _ = get_retval(new_ktrace)
        @show log(abs(ratio1 - ratio2))
    end
end;

# ╔═╡ 1be8ea82-e271-46ab-9505-241871cdffb1
begin
    display(RedGreenAttention.get_last_state(ktrace).dynamic[1])
    display(RedGreenAttention.get_last_state(new_ktrace).dynamic[1])
end

# ╔═╡ c111dcb4-65e6-431d-a8db-a10c181a99ad
begin
    display(RedGreenAttention.get_last_state(ktrace).dynamic[2])
    display(RedGreenAttention.get_last_state(new_ktrace).dynamic[2])
end

# ╔═╡ 900f13c3-e404-4ade-b65e-b581dbcbb378
begin
    states = Vector{WorldState}(undef, 100)
    cur_state = istate
    for t = 1:length(states)
        states[t] = cur_state = RedGreenAttention.resolve_motion(wm.motion, cur_state)
    end
    visuals = map(s -> paint_state(s, wm), states)
end;

# ╔═╡ 0ab31c00-630b-4559-9df4-1db3fce2f2fb
@bind state_step Slider(1:length(visuals), default=1, show_value=x->"  Frame $x")

# ╔═╡ c2561ac7-f228-4440-8529-d9cbcdcc843c
visuals[state_step]

# ╔═╡ 930c22c7-f45e-4613-885a-73c3cc81ea28
md"""
# Attention
"""

# ╔═╡ de5c0a6c-d11d-4ff9-ad17-674d72a41fcf
ac = AdaptiveComputation(;nns=10, buffer_size=1000, base_steps=4, load=10, 
                             load_m=35.0, itemp = 1.0,
                             vis_partition=WMPartition{RedGreenAttention.WMTrace}(),
                             cog_partition=WMPartition{RedGreenAttention.KMDTrace}())

# ╔═╡ 90dc4133-d312-483c-9fd8-9c9591f18e39
md"""
# Helpers
"""

# ╔═╡ 13190feb-2e64-4345-afae-566238dbb449
function update_load!(stat::Ref{Float64}, att::MentalModule{AdaptiveComputation})
    _, state = mparse(att)
    stat[] += state.avg_load
    return nothing
end;

# ╔═╡ 19511608-982f-4204-a665-37de6821e45e
function test_ac()
	steps = 50
	experiment = PilotExp(wm, istate, steps);
	perception_module = MentalModule(perception_protocol)
	decision_module = MentalModule(decision_protocol)
	attention_module = MentalModule(ac)
	snapshots = Vector{Drawing}(undef, steps)
	cumulative_load = Ref{Float64}(0.0)
	for t = 1:steps
		obs = experiment.observations[t]
		#display(obs
		step_module!(perception_module, t, obs)
		step_module!(decision_module, t, perception_module)
		step_module!(attention_module, t, perception_module, decision_module)
		# Record attention stats
		update_load!(cumulative_load, attention_module)
		# Visualizations
		drawing = paint_state(perception_module, false)
		drawing = paint_state(decision_module, drawing, false)
		snapshots[t] = paint_state(attention_module, drawing)
	end
	@show cumulative_load
	return snapshots
end;

# ╔═╡ 3267eba6-368f-4cce-be16-7b170d9ff8c8
# ╠═╡ disabled = true
#=╠═╡
ac_snapshots = test_ac();
  ╠═╡ =#

# ╔═╡ bbb7c065-645e-464f-a003-c98ed8aad104
#=╠═╡
@bind step Slider(1:length(ac_snapshots), default=1, show_value=x->"  Step $x")
  ╠═╡ =#

# ╔═╡ 73b20fbf-bb3a-48d8-a881-1cf1ee0e7ecf
#=╠═╡
ac_snapshots[step]
  ╠═╡ =#

# ╔═╡ Cell order:
# ╟─94515ebc-6010-11f1-83cf-791b54166c74
# ╠═94b64dee-5f9f-4ff2-9b96-bfef6c9e759e
# ╟─e331cb74-b8bb-4805-a2cd-a79efc3e44c1
# ╠═c7283dc3-fa0f-4999-85c5-ae1bca7810b5
# ╠═b446ffce-2f35-4b91-8e18-8c614b559ff8
# ╠═1be8ea82-e271-46ab-9505-241871cdffb1
# ╠═c111dcb4-65e6-431d-a8db-a10c181a99ad
# ╠═900f13c3-e404-4ade-b65e-b581dbcbb378
# ╠═769e17ce-98b6-4c16-a86f-0529ceef84fd
# ╠═0ab31c00-630b-4559-9df4-1db3fce2f2fb
# ╠═c2561ac7-f228-4440-8529-d9cbcdcc843c
# ╟─930c22c7-f45e-4613-885a-73c3cc81ea28
# ╠═de5c0a6c-d11d-4ff9-ad17-674d72a41fcf
# ╟─bbb7c065-645e-464f-a003-c98ed8aad104
# ╠═73b20fbf-bb3a-48d8-a881-1cf1ee0e7ecf
# ╠═3267eba6-368f-4cce-be16-7b170d9ff8c8
# ╟─90dc4133-d312-483c-9fd8-9c9591f18e39
# ╠═19511608-982f-4204-a665-37de6821e45e
# ╠═13190feb-2e64-4345-afae-566238dbb449
