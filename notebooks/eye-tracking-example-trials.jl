### A Pluto.jl notebook ###
# v0.20.24

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
# Trial 1

"""

# ╔═╡ 769e17ce-98b6-4c16-a86f-0529ceef84fd
function init_trial_1()
	static = StaticState([
		StaticObject(S2V(-110, 150), Rectangle(80, 20, 0.), 110.0),   # Green
		StaticObject(S2V(140,   30), Rectangle(40, 40, 0.),   1.0),   # Red
		StaticObject(S2V(20, 62), Rectangle(20, 70, 0.),  60.0),   # Obstacle 1
		StaticObject(S2V(35, -140), Rectangle(30, 60, 0.),  60.0),   # Obstacle 2
		])
	
	c = Circle(12.0)
	dynamic = DynamicState(
		[DynamicObject(1, c, 230.0)],
		[S2V(-160, -60)],
		[S2V(5, -2.95)]
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
		dimensions
	)
end;


# ╔═╡ 900f13c3-e404-4ade-b65e-b581dbcbb378
function visualize_trial(a::WorldState, steps = 148)
	visuals = Vector{Drawing}(undef, steps)
    for t = 1:steps
        a = RedGreenAttention.resolve_motion(wm.motion, a)
		visuals[t] = paint_state(a, wm)
    end
    return visuals
end;

# ╔═╡ cee08ff5-817c-4ccb-b35b-f8f2286bb664
begin
    trial_1 = init_trial_1();
    trial_1_visuals = visualize_trial(trial_1);
end;

# ╔═╡ 0ab31c00-630b-4559-9df4-1db3fce2f2fb
@bind state_step Slider(1:length(trial_1_visuals), default=1, show_value=x->"  Frame $x")

# ╔═╡ c2561ac7-f228-4440-8529-d9cbcdcc843c
trial_1_visuals[state_step]

# ╔═╡ 715ed46c-906f-4f56-8bf9-37ad1171095c
md"""
# Trial 2

Uncertainty across observers
"""

# ╔═╡ c5c40b0c-d711-4741-a6a6-1d8f7857cdf0
function init_trial_2()
	static = StaticState([
		StaticObject(S2V(120, -20), Rectangle(20, 25, 0.), 110.0),   # Green
		StaticObject(S2V(-170, -110), Rectangle(20, 35, 0.),   1.0),   # Red
		StaticObject(S2V(-20, 0), Rectangle(40, 25, 0.),  60.0),   # Obstacle 1
		])
	
	c = Circle(12.0)
	dynamic = DynamicState(
		[DynamicObject(1, c, 230.0)],
		[S2V(60, -100)],
		[S2V(5, -2.35)]
	)
	WorldState(dynamic, static)
end;

# ╔═╡ b5a7e562-8422-4f6c-a50d-bd35751a0ac4
begin
    trial_2 = init_trial_2();
    trial_2_visuals = visualize_trial(trial_2, 100);
end;

# ╔═╡ 3a8a7c5e-1949-4ef1-aefc-94d3bb9a4f33
@bind trial_2_frame Slider(1:length(trial_2_visuals), default=1, show_value=x->"  Frame $x")

# ╔═╡ 2689ca55-a47e-4603-9b71-1f29c6552864
trial_2_visuals[trial_2_frame]

# ╔═╡ 5a0f2a82-0da8-4a37-93cd-8171c1b8f928
md"""
# Trial 3
"""

# ╔═╡ 5b9aefbd-ef66-4ad9-8f99-ef1eed1281be
function init_trial_3()
	static = StaticState([
		StaticObject(S2V(120, 50), Rectangle(50, 35, 0.), 110.0),   # Green
		StaticObject(S2V(-140, -90), Rectangle(30, 70, 0.),   1.0),   # Red
		StaticObject(S2V(-10, -70), Rectangle(20, 20, 0.),  60.0),   # Obstacle 1
		StaticObject(S2V(120, -150), Rectangle(20, 35, 0.),  60.0),   # Obstacle 2
		])
	
	c = Circle(12.0)
	dynamic = DynamicState(
		[DynamicObject(1, c, 230.0)],
		[S2V(40, -20)],
		[S2V(5, -1.5)]
	)
	WorldState(dynamic, static)
end;

# ╔═╡ 852b9242-797e-4365-a692-dda0cee3ec1b
begin
    trial_3 = init_trial_3();
    trial_3_visuals = visualize_trial(trial_3, 92);
end;

# ╔═╡ ec787142-3bfc-42c1-8056-a874030d9226
@bind trial_3_frame Slider(1:length(trial_3_visuals), default=1, show_value=x->"  Frame $x")

# ╔═╡ ee8d1429-9fcc-49aa-9833-ec9f1349fec6
trial_3_visuals[trial_3_frame]

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
                             load_m=6.7, load_x0 = 21.4, itemp = 1.0,
							 map_metric_weights=fill(1/3, 3),
                             vis_partition=WMPartition{RedGreenAttention.WMTrace}(),
                             cog_partition=WMPartition{RedGreenAttention.KMDTrace}())

	# Construct agent from modules
	perception_module = MentalModule(perception_protocol)
	decision_module = MentalModule(decision_protocol)
	attention_module = MentalModule(ac)
	
	Agent(perception_module, decision_module, attention_module)
end;

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
	# Random.seed!(123)
	experiment = PilotExp(wm, istate, steps)
	agent = init_agent(istate)
	snapshots = Vector{Drawing}(undef, steps)
	cumulative_load = Ref{Float64}(0.0)
	for t = 1:steps
		println("\t\t--- TIME: $t ---")
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

# ╔═╡ 9b96902d-e27e-4486-bef8-e8653fa61a9b
begin
    trial_1_run = @timed run_agent(trial_1, length(trial_1_visuals))
    trial_1_model = trial_1_run.value
end;

# ╔═╡ b3f24bac-d443-4799-8e66-15bc93be338b
@bind trial_1_model_step Slider(1:length(trial_1_model), default=58, show_value=x->"  Frame $x")

# ╔═╡ bf1dd631-607a-4821-b19c-9f9a62af1d85
trial_1_model[trial_1_model_step]

# ╔═╡ 30522f9f-e60d-43d0-97cb-faf89d370574
begin
    trial_2_run = @timed run_agent(trial_2, length(trial_2_visuals))
    trial_2_model = trial_2_run.value
end;

# ╔═╡ a19d9b94-4793-4249-9d66-27517050891d
@bind trial_2_model_step Slider(1:length(trial_2_model), default=1, show_value=x->"  Frame $x")

# ╔═╡ fa00f98b-ef0a-43cd-86c6-64b093c2c0b8
trial_2_model[trial_2_model_step]

# ╔═╡ 167630c8-fe5d-44d0-9bd7-632c4a0ae76d
begin
    trial_3_run = @timed run_agent(trial_3, length(trial_3_visuals))
    trial_3_model = trial_3_run.value
end;

# ╔═╡ d90ea6ac-4ba9-40fd-882c-c1594ebc648e
@bind trial_3_model_step Slider(1:length(trial_3_model), default=1, show_value=x->"  Frame $x")

# ╔═╡ cf48fafa-2f92-474d-baed-509a25c4d724
trial_3_model[trial_3_model_step]

# ╔═╡ Cell order:
# ╟─94515ebc-6010-11f1-83cf-791b54166c74
# ╟─94b64dee-5f9f-4ff2-9b96-bfef6c9e759e
# ╟─e331cb74-b8bb-4805-a2cd-a79efc3e44c1
# ╠═0ab31c00-630b-4559-9df4-1db3fce2f2fb
# ╠═c2561ac7-f228-4440-8529-d9cbcdcc843c
# ╠═769e17ce-98b6-4c16-a86f-0529ceef84fd
# ╠═9b96902d-e27e-4486-bef8-e8653fa61a9b
# ╠═b3f24bac-d443-4799-8e66-15bc93be338b
# ╟─bf1dd631-607a-4821-b19c-9f9a62af1d85
# ╠═c7283dc3-fa0f-4999-85c5-ae1bca7810b5
# ╠═900f13c3-e404-4ade-b65e-b581dbcbb378
# ╠═cee08ff5-817c-4ccb-b35b-f8f2286bb664
# ╟─715ed46c-906f-4f56-8bf9-37ad1171095c
# ╠═c5c40b0c-d711-4741-a6a6-1d8f7857cdf0
# ╠═3a8a7c5e-1949-4ef1-aefc-94d3bb9a4f33
# ╠═2689ca55-a47e-4603-9b71-1f29c6552864
# ╠═b5a7e562-8422-4f6c-a50d-bd35751a0ac4
# ╠═30522f9f-e60d-43d0-97cb-faf89d370574
# ╠═a19d9b94-4793-4249-9d66-27517050891d
# ╠═fa00f98b-ef0a-43cd-86c6-64b093c2c0b8
# ╟─5a0f2a82-0da8-4a37-93cd-8171c1b8f928
# ╠═5b9aefbd-ef66-4ad9-8f99-ef1eed1281be
# ╠═ec787142-3bfc-42c1-8056-a874030d9226
# ╠═ee8d1429-9fcc-49aa-9833-ec9f1349fec6
# ╠═852b9242-797e-4365-a692-dda0cee3ec1b
# ╠═167630c8-fe5d-44d0-9bd7-632c4a0ae76d
# ╠═d90ea6ac-4ba9-40fd-882c-c1594ebc648e
# ╠═cf48fafa-2f92-474d-baed-509a25c4d724
# ╠═706d39a5-615f-47c5-b18f-005b004339ec
# ╟─f6245827-b712-43a9-9073-ffffa7faf737
# ╟─7bdbc415-176c-4bd6-95e2-ffe365194836
# ╟─514c36ad-e404-4cec-b387-4b60fbaecb07
# ╟─7532a73e-095e-476a-a7e3-921386074ba6
# ╟─1df60712-1781-4cf3-abad-4f16181e86fb
# ╟─930c22c7-f45e-4613-885a-73c3cc81ea28
# ╠═19511608-982f-4204-a665-37de6821e45e
# ╠═06f8c57c-a842-4d6c-8ddb-c593a1b900af
# ╟─90dc4133-d312-483c-9fd8-9c9591f18e39
# ╟─13190feb-2e64-4345-afae-566238dbb449
