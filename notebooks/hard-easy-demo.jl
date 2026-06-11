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
	using Random
	
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
    font-size: 3.0rem;
}

cm-editor .cm-scroller,
.cm-editor .cm-content {
    font-family: "Fira Code", monospace !important;
    font-size: 18px !important; /* Adjust size here */
}
</style>
""" 

# ╔═╡ e331cb74-b8bb-4805-a2cd-a79efc3e44c1
md"""
# Preamble
"""

# ╔═╡ c7283dc3-fa0f-4999-85c5-ae1bca7810b5
begin
	# world model parameters
	dimensions = S2V(400, 400);
	wm = WorldModel(
		BilliardBrownian(dimensions, 0.25, 0.01),
		MaskGraphics(1.0, 1.0, 3.0, 5.0),
		dimensions
	)
end;


# ╔═╡ 900f13c3-e404-4ade-b65e-b581dbcbb378
function visualize_trial_pair(a::WorldState, b::WorldState, steps = 100)
    visuals = Vector{Drawing}(undef, steps)
    for t = 1:steps
        a = RedGreenAttention.resolve_motion(wm.motion, a)
        b = RedGreenAttention.resolve_motion(wm.motion, b)
        visuals[t] = hcat(paint_state(a, wm), paint_state(b, wm); hpad=5)
    end
    return visuals
end;

# ╔═╡ 769e17ce-98b6-4c16-a86f-0529ceef84fd
function init_trial(hard=true)
	ylwy = hard ? 60 : -20
	static = StaticState([
		StaticObject(S2V(-70, -150), Rectangle(80, 10, 0.),   1.0),   # Red
		StaticObject(S2V(140,  -50), Rectangle(10, 80, 0.), 110.0),   # Green
		StaticObject(S2V(100, ylwy), Rectangle(10, 90, 0.),  60.0),   # Yellow
		])
	
	c = Circle(10.0)
	dynamic = DynamicState(
		[DynamicObject(1, c, 230.0), DynamicObject(1, c, 275.0)],
		[S2V(-70, 70),               S2V(0, 100)],
		[S2V(5, -3.5),                 S2V(0, 1)]
	)
	WorldState(dynamic, static)
end;

# ╔═╡ edc73e15-aba5-4823-84d8-fa90532683db
begin
	hard_trial = init_trial(true)
	easy_trial = init_trial(false)
end;

# ╔═╡ cee08ff5-817c-4ccb-b35b-f8f2286bb664
visuals = visualize_trial_pair(hard_trial, easy_trial);

# ╔═╡ 0ab31c00-630b-4559-9df4-1db3fce2f2fb
@bind state_step Slider(1:length(visuals), default=1, show_value=x->"  Frame $x")

# ╔═╡ c2561ac7-f228-4440-8529-d9cbcdcc843c
visuals[state_step]

# ╔═╡ 706d39a5-615f-47c5-b18f-005b004339ec
md"""
# Agent parameters
"""

# ╔═╡ 06f8c57c-a842-4d6c-8ddb-c593a1b900af
function init_agent(istate::WorldState)
	# Perception
    init_args = (0, istate, wm);
	pf_protocol = PFProtocol(;particles = 15);
	perception_protocol = RGPerception(pf_protocol, init_args, choicemap());
	# Decision Making
	decision_protocol = RedGreenCollision(;hsv_red = 1.0, max_sim_steps=48);

	# Attention
	ac = AdaptiveComputation(;
							 nns=20, buffer_size=500, base_steps=4, load=10, 
                             load_m=0.7, load_x0 = 1., itemp = 1.0,
                             vis_partition=WMPartition{RedGreenAttention.WMTrace}(),
                             cog_partition=WMPartition{RedGreenAttention.KMDTrace}())

	# Construct agent from modules
	perception_module = MentalModule(perception_protocol)
	decision_module = MentalModule(decision_protocol)
	attention_module = MentalModule(ac)
	
	Agent(perception_module, decision_module, attention_module)
end;

# ╔═╡ 930c22c7-f45e-4613-885a-73c3cc81ea28
md"""
# Simulations
"""

# ╔═╡ b5250028-6e6a-426a-ba7d-6a8ebdc61389
begin
	orig_pos = S2V(32.14281891084581, -171.66808073175952)
	new_pos = S2V(128.51643473013894, -146.08754313886317)
	function debug_state(hard=false)
		ylwy = hard ? 60 : -20
		static = StaticState([
			StaticObject(S2V(-70, -150), Rectangle(80, 10, 0.),   1.0),   # Red
			StaticObject(S2V(140,  -50), Rectangle(10, 80, 0.), 110.0),   # Green
			StaticObject(S2V(100, ylwy), Rectangle(10, 90, 0.),  60.0),   # Yellow
			])
		
		c = Circle(10.0)
		dynamic = DynamicState(
			[DynamicObject(1, c, 1.0), DynamicObject(1, c, 110.0)],
			[orig_pos, new_pos],
			[S2V(-4., -1.),                 S2V(0, 1)]
		)
		WorldState(dynamic, static)
	end;
	paint_state(debug_state(), wm)
end

# ╔═╡ 756de64b-2e24-4a36-bd8e-6c23cd7a2a7c
RedGreenAttention.collision_probability(Circle(10.0), Rectangle(80.0, 10.0, 0.), orig_pos, S2V(-70, -150), S2V(0., 0.))

# ╔═╡ d35220e7-12b6-4639-bfc7-b46339d12892
RedGreenAttention.collision_probability(Circle(10.0), Rectangle(80.0, 10.0, 0.), new_pos, S2V(-70, -150), S2V(0., 0.))

# ╔═╡ 40e67073-ca53-4c8b-9e5a-7f7e7d8248f3
# distance to red
d2r,_ = RedGreenAttention.distance(Circle(10.0), Rectangle(80.0, 10.0, 0.), new_pos, S2V(-70, -150))

# ╔═╡ 02d6f951-ab09-4a12-9584-b7514a104bb4
# distance to green
d2g,_ = RedGreenAttention.distance(Circle(10.0), Rectangle(10, 80, 0.), new_pos, S2V(140,  -50))

# ╔═╡ 2ef657f5-5543-4da9-845d-0509f4988d7c
begin
    @show proxy_red = d2g / (d2r + d2g)
    @show proxy_green = 1.0 - proxy_red
end;

# ╔═╡ fa617f27-bd93-4c24-a50e-908e13340721
proxy_diff = proxy_red - proxy_green

# ╔═╡ db324004-2603-475c-a5ed-6f14388cd315
proxy_ratio = proxy_diff * 0.5 + 0.5

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
function run_agent(istate::WorldState, steps = 30)
	Random.seed!(1234)
	experiment = PilotExp(wm, istate, steps)
	agent = init_agent(istate)
	snapshots = Vector{Drawing}(undef, steps)
	cumulative_load = Ref{Float64}(0.0)
	for t = 1:steps
		obs = experiment.observations[t]
		step_agent!(agent, t, obs)
		# Record attention stats
		update_load!(cumulative_load, agent.attention)
		# Visualizations
		drawing = paint_state(agent.perception, false)
		drawing = paint_state(agent.planning, drawing, false)
		snapshots[t] = paint_state(agent.attention, drawing)
	end
	println("Overall load: $(cumulative_load[])")
	return snapshots
end;

# ╔═╡ 74d32ba3-7683-4392-821d-d91b5c1dd82f
begin
    # Run on hard and easy trials
    println("\t\t ---HARD---")
    hard_sim = run_agent(hard_trial)
    println("\n\n\t\t ---EASY---")
    easy_sim = run_agent(easy_trial)
end;

# ╔═╡ f146a9fc-dc89-40a8-a78d-626c625dca5e
# Combine visualizations
# combined = hard_sim;
# combined = easy_sim;
combined = map(x -> hcat(x...; hpad=5), zip(hard_sim, easy_sim));

# ╔═╡ bbb7c065-645e-464f-a003-c98ed8aad104
@bind step Slider(1:length(combined), default=1, show_value=x->"  Step $x")

# ╔═╡ f34e7a5e-207a-4fdd-8ab0-cb8940518130
combined[step]

# ╔═╡ Cell order:
# ╟─94515ebc-6010-11f1-83cf-791b54166c74
# ╠═94b64dee-5f9f-4ff2-9b96-bfef6c9e759e
# ╟─e331cb74-b8bb-4805-a2cd-a79efc3e44c1
# ╠═c7283dc3-fa0f-4999-85c5-ae1bca7810b5
# ╠═900f13c3-e404-4ade-b65e-b581dbcbb378
# ╠═769e17ce-98b6-4c16-a86f-0529ceef84fd
# ╠═edc73e15-aba5-4823-84d8-fa90532683db
# ╠═cee08ff5-817c-4ccb-b35b-f8f2286bb664
# ╟─0ab31c00-630b-4559-9df4-1db3fce2f2fb
# ╠═c2561ac7-f228-4440-8529-d9cbcdcc843c
# ╟─706d39a5-615f-47c5-b18f-005b004339ec
# ╠═06f8c57c-a842-4d6c-8ddb-c593a1b900af
# ╟─930c22c7-f45e-4613-885a-73c3cc81ea28
# ╠═19511608-982f-4204-a665-37de6821e45e
# ╠═74d32ba3-7683-4392-821d-d91b5c1dd82f
# ╠═b5250028-6e6a-426a-ba7d-6a8ebdc61389
# ╠═756de64b-2e24-4a36-bd8e-6c23cd7a2a7c
# ╠═d35220e7-12b6-4639-bfc7-b46339d12892
# ╠═40e67073-ca53-4c8b-9e5a-7f7e7d8248f3
# ╠═02d6f951-ab09-4a12-9584-b7514a104bb4
# ╠═2ef657f5-5543-4da9-845d-0509f4988d7c
# ╠═fa617f27-bd93-4c24-a50e-908e13340721
# ╠═db324004-2603-475c-a5ed-6f14388cd315
# ╠═f146a9fc-dc89-40a8-a78d-626c625dca5e
# ╟─bbb7c065-645e-464f-a003-c98ed8aad104
# ╟─f34e7a5e-207a-4fdd-8ab0-cb8940518130
# ╟─90dc4133-d312-483c-9fd8-9c9591f18e39
# ╠═13190feb-2e64-4345-afae-566238dbb449
