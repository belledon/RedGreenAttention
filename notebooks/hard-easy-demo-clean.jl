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
# Preamble - Demo trials

Two trials that have the same initial animations but differ in Red vs. Green ratios
"""

# ╔═╡ c7283dc3-fa0f-4999-85c5-ae1bca7810b5
begin
	# world model parameters
	dimensions = S2V(400, 400);
	wm = WorldModel(
		BilliardBrownian(dimensions, 0.5, 0.01),
		MaskGraphics(1.0, 1.0, 3.0, 5.0),
		dimensions
	)
end;


# ╔═╡ 900f13c3-e404-4ade-b65e-b581dbcbb378
function visualize_trial_pair(a::WorldState, b::WorldState, steps = 100)
    avisuals = Vector{Drawing}(undef, steps)
	bvisuals = Vector{Drawing}(undef, steps)
	visuals = Vector{Drawing}(undef, steps)
    for t = 1:steps
        a = RedGreenAttention.resolve_motion(wm.motion, a)
        b = RedGreenAttention.resolve_motion(wm.motion, b)
		avisuals[t] = paint_state(a, wm)
		bvisuals[t] = paint_state(b, wm)
        visuals[t] = hcat(avisuals[t], bvisuals[t]; hpad=5)
    end
    return avisuals, bvisuals, visuals
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
(hard_visuals, easy_visuals, visuals) = visualize_trial_pair(hard_trial, easy_trial);

# ╔═╡ 0ab31c00-630b-4559-9df4-1db3fce2f2fb
@bind state_step Slider(1:length(visuals), default=1, show_value=x->"  Frame $x")

# ╔═╡ c2561ac7-f228-4440-8529-d9cbcdcc843c
visuals[state_step]

# ╔═╡ 706d39a5-615f-47c5-b18f-005b004339ec
md"""
# Adaptive Computation Architecture

### 5-min overview

Addresses three open computational challenges:
1. Identifies a bounded general resource, $C_k$
2. Defines task-relevance as the *instantaneous need for computation*, $\Delta_k^t$
3. Rations these resources across objects and moments, at the scale of visual processing

In case studies of MOT and indoor scene perception: 
1. Predicted intra-trial sub-second patterns of spatio-temporal attention (via probe detection)
2. Predicted trial-level variability in retrospective subjective effort impressions
3. Predicted representational precision (via change detection and localization error)
3. Demonstrated *emergent* resource rationality: used less resources on easier trials (faster runtimes) and achieved higher accuracy in harder trials (with same resource constraints).
"""

# ╔═╡ f6245827-b712-43a9-9073-ffffa7faf737
md"""
**1) Computation Resource**

Perception (and cognition) often involve approximation, e.g., perceptual inference $Pr(S \mid X)$.

Broad family of approximation algorithms involve incremental computations that drive convergence (e.g., moving the base distribution to the target).

AC interface requires these computations, $C_k$, be:
1. targetable (to a particular representation, object, or latent)
2. time-consistent / unitized, i.e., stable $\mathcal{O}_t$

$C_k:: S \to S_{-k} \cup s'_k$

Example of a probablisitic program used later that resamples an object's recent movements:
```julia
function object_ancestral_proposal(trace::WMTrace, k::Int)
    t, _... = get_args(trace)
    selection = select(:states => t => :jitter => k)
    new_trace, w, _ = regenerate(trace, selection)
    (new_trace, w)
end
```
"""

# ╔═╡ 7bdbc415-176c-4bd6-95e2-ffe365194836
md"""

**2) Task-relevance**

Factorizes into two *impacts* of further applying computation steps on a representation $k$: 

$\Delta_k^t = \delta_k \pi \cdot \delta_k S$


1. Impact on decision-making: $\delta_k \pi$
2. Impact on perception (convergence): $\delta_k S$

To build an intuition...


"""

# ╔═╡ 514c36ad-e404-4cec-b387-4b60fbaecb07
@bind single_step Slider(1:12, default=1, show_value=x->"  Frame $x")

# ╔═╡ 027e8aa4-fc67-4253-9bef-15d2ee297e45
hard_visuals[single_step]

# ╔═╡ 7532a73e-095e-476a-a7e3-921386074ba6
md"""
- computations over the light blue's state could lead to different Red-Green ratios $\to$ higher $\delta_k \pi$
- not the case for the purple object $\to$ lower $\delta_k \pi$
- . $\delta_k S$ will largely be uniform except for unexpected movement or occlusion (mostly regularizing term for estimation)
"""

# ╔═╡ 1df60712-1781-4cf3-abad-4f16181e86fb
md"""
**3) Real-time Rationing Algorithm**

Determing distribution of resources across objects and moments:
- **Importance**, $\text{softmax}(\vec{\Delta}^t)$: proportion of computations across objects
- **Load**, $\exp(\frac{\|\vec{\Delta}^t\| - x_0}{m})$: total need for computation ($x_0,m$ are hyper-parameters)

Tractable (sub-realtime) estimation of $\Delta$ using *feed-back* loop:
- at $t$: perform some base amount of pre-attentive computation, measure impacts $\delta_k \pi, \delta_k S$
- at $t+1$: aggregate impacts from $t$ to estimate $\Delta$, load, and importance. 
- repeat
"""

# ╔═╡ 930c22c7-f45e-4613-885a-73c3cc81ea28
md"""
# Simulations

The *Agent* has three algorithmic components:
1. Perception (particle filter) - approximates $Pr(S \mid X)$
2. Decision-making (importance resampling) - approximates decision threshold over posterior predictive, $\mathbf{E}[\pi \mid S]$
3. Attention (adaptive computation) - further deploys perception and decision-making computations to resolve needs for computation
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
							 nns=50, buffer_size=500, base_steps=4, load=10, 
                             load_m=2.0, load_x0 = 15.0, itemp = 1.0,
                             vis_partition=WMPartition{RedGreenAttention.WMTrace}(),
                             cog_partition=WMPartition{RedGreenAttention.KMDTrace}())

	# Construct agent from modules
	perception_module = MentalModule(perception_protocol)
	decision_module = MentalModule(decision_protocol)
	attention_module = MentalModule(ac)
	
	Agent(perception_module, decision_module, attention_module)
end;

# ╔═╡ 6c9ee12c-de4a-47e6-b72f-7a5abf984dc0
md"""
The AC model uses more computations in the HARD vs. Easy trial
"""

# ╔═╡ 4e22fac7-88fa-441b-b25a-9925336f0148
md"""
Comparing model internal steps...
"""

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
function run_agent(istate::WorldState, steps = 27)
	Random.seed!(123)
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
    hard_sim_run = @timed run_agent(hard_trial)
	hard_sim = hard_sim_run.value
    println("\n\t\t ---EASY---")
    easy_sim_run = @timed run_agent(easy_trial)
	easy_sim = easy_sim_run.value
	println("\n\t\t----------")
	println("\nOverall time: $(round(easy_sim_run.time+hard_sim_run.time;digits=2))s")
end;

# ╔═╡ f146a9fc-dc89-40a8-a78d-626c625dca5e
# Combine visualizations
combined = map(x -> hcat(x...; hpad=5), zip(hard_sim, easy_sim));

# ╔═╡ bbb7c065-645e-464f-a003-c98ed8aad104
@bind step Slider(1:length(combined), default=1, show_value=x->"  Step $x")

# ╔═╡ f34e7a5e-207a-4fdd-8ab0-cb8940518130
combined[step]

# ╔═╡ Cell order:
# ╟─94515ebc-6010-11f1-83cf-791b54166c74
# ╟─94b64dee-5f9f-4ff2-9b96-bfef6c9e759e
# ╟─e331cb74-b8bb-4805-a2cd-a79efc3e44c1
# ╟─0ab31c00-630b-4559-9df4-1db3fce2f2fb
# ╟─c2561ac7-f228-4440-8529-d9cbcdcc843c
# ╟─c7283dc3-fa0f-4999-85c5-ae1bca7810b5
# ╟─900f13c3-e404-4ade-b65e-b581dbcbb378
# ╟─769e17ce-98b6-4c16-a86f-0529ceef84fd
# ╟─edc73e15-aba5-4823-84d8-fa90532683db
# ╟─cee08ff5-817c-4ccb-b35b-f8f2286bb664
# ╟─706d39a5-615f-47c5-b18f-005b004339ec
# ╟─f6245827-b712-43a9-9073-ffffa7faf737
# ╟─7bdbc415-176c-4bd6-95e2-ffe365194836
# ╟─514c36ad-e404-4cec-b387-4b60fbaecb07
# ╟─027e8aa4-fc67-4253-9bef-15d2ee297e45
# ╟─7532a73e-095e-476a-a7e3-921386074ba6
# ╟─1df60712-1781-4cf3-abad-4f16181e86fb
# ╟─930c22c7-f45e-4613-885a-73c3cc81ea28
# ╟─19511608-982f-4204-a665-37de6821e45e
# ╠═06f8c57c-a842-4d6c-8ddb-c593a1b900af
# ╟─6c9ee12c-de4a-47e6-b72f-7a5abf984dc0
# ╠═74d32ba3-7683-4392-821d-d91b5c1dd82f
# ╟─f146a9fc-dc89-40a8-a78d-626c625dca5e
# ╟─4e22fac7-88fa-441b-b25a-9925336f0148
# ╟─bbb7c065-645e-464f-a003-c98ed8aad104
# ╟─f34e7a5e-207a-4fdd-8ab0-cb8940518130
# ╟─90dc4133-d312-483c-9fd8-9c9591f18e39
# ╟─13190feb-2e64-4345-afae-566238dbb449
