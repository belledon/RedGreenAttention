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

# ╔═╡ de724114-3eb9-11f1-a3ea-d5140221ca79
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	
	using Gen
	using Luxor
	using PlutoUI
	
	using Revise
	using GenRFS
	using RedGreenAttention
end

# ╔═╡ 0642923c-d494-4738-a756-c9891681daad
begin
	using RedGreenAttention: S2V, Rectangle, Circle
end

# ╔═╡ a220ca7c-a89b-4444-bb4d-bd24aca8bc5e
using RedGreenAttention: predict, render_mask

# ╔═╡ d3b63cfc-4068-4c1b-92e3-531fd49e7b7e
using RedGreenAttention: resolve_motion

# ╔═╡ 9f5e8d46-c74b-4cc2-ac45-558e2c0c09fd
using RedGreenAttention: distance

# ╔═╡ e71f7fa9-0628-497e-967e-55499d0f2c1e
using RedGreenAttention: resolve_collision

# ╔═╡ 1a3aba19-8c51-492d-875c-5806dcd37fe8
using RedGreenAttention: RGPerception, PFProtocol, MentalModule, PFChain, step_module!

# ╔═╡ 27efaaf7-0e78-43e7-96aa-04128f30bfee
html"""
<style>
    @media screen {
        main {
            margin: 0 auto;
            max-width: 3000px;
            padding-left: max(200px, 10%);
            padding-right: max(200px, 10%);
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

# ╔═╡ 335d2425-d149-4b5b-8c0e-f3e152e97bce
RedGreenAttention.greet()

# ╔═╡ 3c9c7c71-0a31-4844-8ee5-5b3122d7c445
@doc RedGreenAttention.StaticObject

# ╔═╡ b22bf6da-689d-424d-95ff-c6e5a5c53664
md"""

# Visuals
"""

# ╔═╡ d3bb3df7-4e77-4e8f-a0c2-c20eba95c072
r = Rectangle(50, 20, 0.)

# ╔═╡ 80b4cab8-32ec-4370-8646-3bceae9d4ef7
c = Circle(20.0)

# ╔═╡ f3ddf5a0-a482-4680-982d-459c1a178665
@draw begin
	d = init_viz!(400., 400.)
	paint!(c, S2V(-30, 40), Float64(pi))
	paint!(r, S2V(0, 0), 0.0)
	finish()
	d
end

# ╔═╡ 87ce7f5b-3a88-4c59-8449-883ee7730c5e
md"""

# Initializing World Model
"""

# ╔═╡ a9383266-592a-493b-a70a-218d1e7c6d0b
dimensions = S2V(400, 400);

# ╔═╡ 6eb22ff5-5e4b-440f-907a-ff43b4f6e768
wm = WorldModel(
	BilliardBrownian(dimensions, 1.0, 0.0001),
	MaskGraphics(1.0, 1.0, 3.0, 5.0),
	dimensions,
)

# ╔═╡ 51a6bbed-d6cd-4735-925a-acbf172c996c
md"""

# Initializing State
"""

# ╔═╡ 4c09b8ce-9aab-49e2-bdcf-605feb1fdbdd
static = StaticState(
	[
		StaticObject(S2V(0, 0), r, 0.0)
	]
)

# ╔═╡ ed426ae0-49cc-4ef9-a6aa-4b299c652761
dynamic = DynamicState(
	[DynamicObject(1, c, Float64(pi))],
	[S2V(-30, 45)],
	[S2V(5, 0)]
)

# ╔═╡ 332ff5ab-b61f-4b95-ae4e-1cc625c79d25
state = WorldState(dynamic, static)

# ╔═╡ 520431cf-fb2d-4fc6-b4a2-e3ea53895699
paint_state(state, wm)

# ╔═╡ 9a305bc7-53a6-4216-be60-5ce68af8d0e2
md"""

## Graphics
"""

# ╔═╡ 5c8e3ab5-073b-439d-9d1e-63e16a255705
rfes = predict(wm.graphics, state)

# ╔═╡ b8a21d6c-0624-4c95-81cd-6ccc2f8fb94e
begin
	sampled_masks = MaskRFS(rfes)
	paint_masks(sampled_masks, wm)
end

# ╔═╡ 7b857a98-5c31-4d41-97e0-5bc5ee065832
md"""

## Motion
"""

# ╔═╡ c84c7f31-7751-4b9c-ba7c-ae4ddef133b0
nframes = 60;

# ╔═╡ d5ac5705-cbd9-4673-8257-8f6945540feb
tr, _ = Gen.generate(vis_model, (nframes, state, wm));

# ╔═╡ 5ca74938-8057-4eca-9055-ca62d8ed15ad
states = get_retval(tr);

# ╔═╡ cdaab024-45c8-4d82-af23-cbe89fe28ccc
# Reactive drawing function
function animate_states(states, wm, frame)
	state = states[frame]
	paint_state(state, wm)
end

# ╔═╡ 891ebf38-5e8d-4348-b510-fb633949c3eb
# Reactive drawing function
function animate_trace(trace, frame)
	_, _, wm = get_args(tr)
	states = get_retval(trace)
	animate_states(states, wm, frame)
end

# ╔═╡ 82635ed3-5e8d-4a40-9637-e8b6cd642438
@bind frames Slider(1:nframes, default=1, show_value=x->"  Frame $x")

# ╔═╡ bffb10ce-f30f-4d7d-89bb-029a3f8bb124
animate_trace(tr, frames)

# ╔═╡ 29eed906-3602-4ea1-8feb-38062c1eba62
md"""

### Debugging collision

Looking at detection and resolution
"""

# ╔═╡ 354ac3ba-79fe-482c-92e5-3bc0c63a3e61
function test_collision()

	c = Circle(20.0)
	r = Rectangle(50, 20, 0.)
	
	static = StaticState([StaticObject(S2V(0, 0), r, 0.0)])
	dynamic = DynamicState(
		[DynamicObject(1, c, Float64(pi))],
		[S2V(-30, 50)],
		[S2V(0, -5)]
	)
	state = WorldState(dynamic, static)
	
	dimensions = S2V(400, 400)
	motion = BilliardBrownian(dimensions, 1.0, 0.0001)
	states = Vector{WorldState}(undef, 10)
	for t = 1:10
		states[t] = state = resolve_motion(motion, state)
	end

	return states
end

# ╔═╡ d4201646-e2aa-438c-b307-eabd91811577
test_states = test_collision();

# ╔═╡ 5d83855c-d0f6-42f0-9592-544f16584a08
@bind test_frames Slider(1:10, default=1, show_value=x->"  Frame $x")

# ╔═╡ 1d4f979c-bc17-4e56-9593-834c67ed5e03
animate_states(test_states, wm, test_frames)

# ╔═╡ 1037869f-9e59-4f27-a938-9aeda621affd
function test_distance()
	c = Circle(20.0)
	r = Rectangle(50, 20, 0.)
	d = distance(c, r, S2V(-30, 40), S2V(0, 0))
	@show d
	return nothing
end

# ╔═╡ 4d8148b2-0899-4d45-bc7d-c6d739b8b54f
test_distance()

# ╔═╡ c2bb534d-7432-4a05-878b-dc18bec1127e
function test_resolve_collision()
	c = Circle(20.0)
	r = Rectangle(50, 20, 0.)
	d, a = distance(c, r, S2V(-30, 40), S2V(0, 0))

	dimensions = S2V(400, 400)
	motion = BilliardBrownian(dimensions, 1.0, 0.0001)
	_, v = resolve_collision(motion, c, S2V(-30, 40), S2V(0, -5), a)
	@show v
	return nothing
end

# ╔═╡ 5dea973e-fff0-4e46-8b07-9f243aab00ae
test_resolve_collision()

# ╔═╡ d5579c06-0de8-474c-8f95-9b2505d17620
md"""
# Perception
"""

# ╔═╡ 7048765c-7a2b-431e-ae69-ab0094178f26
pf_protocol = PFProtocol(;particles = 10);

# ╔═╡ ae6fb0e3-5a4f-4e92-a911-fae25f62c1c1
function initial_state()
	c = Circle(20.0)
	r = Rectangle(80, 10, 0.)
	
	static = StaticState([StaticObject(S2V(0,  100), r, 1.0),
						      StaticObject(S2V(0, -100), r, 110.0)])
	dynamic = DynamicState(
		[DynamicObject(1, c, 230.0)],
		[S2V(0, 0)],
		[S2V(0, -5)]
	)
	WorldState(dynamic, static)
end;

# ╔═╡ 4281651f-1115-42a3-a1bd-397c6e2ca4b4
istate = initial_state();

# ╔═╡ a03e912c-1a92-4888-8902-f56ded89fea7
init_args = (0, istate, wm);

# ╔═╡ 4fd8123d-2ece-466a-9d30-a45e33a8b690
perception_protocol = RGPerception(pf_protocol, init_args, choicemap());


# ╔═╡ 7e399920-7aca-4cf2-9aa4-04a2be8f75f2
function test_perception()
	steps = 30
	experiment = PilotExp(wm, istate, steps);
	perception_module = MentalModule(perception_protocol)
	snapshots = Vector{Drawing}(undef, steps)
	for t = 1:steps
		obs = experiment.observations[t]
		#display(obs)
	    step_module!(perception_module, t, obs)
		snapshots[t] = paint_state(perception_module)
	end
	return snapshots
end;

# ╔═╡ e232d4b6-eba9-4a63-a142-c740b2ee23c2
snapshots = test_perception();

# ╔═╡ f15c2cf3-fada-4561-ad9f-1858b420d5d5
@bind sim_step Slider(1:length(snapshots), default=1, show_value=x->"  Frame $x")

# ╔═╡ 4b170648-c374-423d-a8fc-c79e6dafcb20
snapshots[sim_step]

# ╔═╡ 6f77443d-a3c9-40a8-8a48-5bc1bc503af8
md"""
# Decision Making
"""

# ╔═╡ 864a4c76-efac-4ec7-864c-c68ec7f1742a
decision_protocol = RedGreenCollision(;hsv_red = 1.0);

# ╔═╡ 188d081f-7282-48e4-8080-d8c83a0c6b82
function test_decision_making()
	steps = 30
	experiment = PilotExp(wm, istate, steps);
	perception_module = MentalModule(perception_protocol)
	decision_module = MentalModule(decision_protocol)
	snapshots = Vector{Drawing}(undef, steps)
	for t = 1:steps
		obs = experiment.observations[t]
		#display(obs)
	    step_module!(perception_module, t, obs)
		step_module!(decision_module, t, perception_module)
		snapshots[t] = paint_state(perception_module)
		@show decision_expectation(decision_module)
	end
	return snapshots
end;

# ╔═╡ 0695d472-2b03-4781-9033-31faf9f6eae2
dm_snapshots = test_decision_making();

# ╔═╡ 543dbe46-0694-4fd0-9086-c72f5331d8b9
@bind dm_step Slider(1:length(snapshots), default=1, show_value=x->"  Frame $x")

# ╔═╡ c146ea3f-2c12-4f8f-9607-dc325a808acb
dm_snapshots[dm_step]

# ╔═╡ Cell order:
# ╟─27efaaf7-0e78-43e7-96aa-04128f30bfee
# ╠═de724114-3eb9-11f1-a3ea-d5140221ca79
# ╠═0642923c-d494-4738-a756-c9891681daad
# ╠═335d2425-d149-4b5b-8c0e-f3e152e97bce
# ╠═3c9c7c71-0a31-4844-8ee5-5b3122d7c445
# ╟─b22bf6da-689d-424d-95ff-c6e5a5c53664
# ╠═d3bb3df7-4e77-4e8f-a0c2-c20eba95c072
# ╠═80b4cab8-32ec-4370-8646-3bceae9d4ef7
# ╠═f3ddf5a0-a482-4680-982d-459c1a178665
# ╟─87ce7f5b-3a88-4c59-8449-883ee7730c5e
# ╠═a9383266-592a-493b-a70a-218d1e7c6d0b
# ╠═6eb22ff5-5e4b-440f-907a-ff43b4f6e768
# ╟─51a6bbed-d6cd-4735-925a-acbf172c996c
# ╠═4c09b8ce-9aab-49e2-bdcf-605feb1fdbdd
# ╠═ed426ae0-49cc-4ef9-a6aa-4b299c652761
# ╠═332ff5ab-b61f-4b95-ae4e-1cc625c79d25
# ╠═520431cf-fb2d-4fc6-b4a2-e3ea53895699
# ╟─9a305bc7-53a6-4216-be60-5ce68af8d0e2
# ╠═a220ca7c-a89b-4444-bb4d-bd24aca8bc5e
# ╠═5c8e3ab5-073b-439d-9d1e-63e16a255705
# ╠═b8a21d6c-0624-4c95-81cd-6ccc2f8fb94e
# ╟─7b857a98-5c31-4d41-97e0-5bc5ee065832
# ╠═c84c7f31-7751-4b9c-ba7c-ae4ddef133b0
# ╠═d5ac5705-cbd9-4673-8257-8f6945540feb
# ╠═5ca74938-8057-4eca-9055-ca62d8ed15ad
# ╠═cdaab024-45c8-4d82-af23-cbe89fe28ccc
# ╠═891ebf38-5e8d-4348-b510-fb633949c3eb
# ╠═82635ed3-5e8d-4a40-9637-e8b6cd642438
# ╠═bffb10ce-f30f-4d7d-89bb-029a3f8bb124
# ╟─29eed906-3602-4ea1-8feb-38062c1eba62
# ╠═d3b63cfc-4068-4c1b-92e3-531fd49e7b7e
# ╠═354ac3ba-79fe-482c-92e5-3bc0c63a3e61
# ╠═d4201646-e2aa-438c-b307-eabd91811577
# ╟─5d83855c-d0f6-42f0-9592-544f16584a08
# ╠═1d4f979c-bc17-4e56-9593-834c67ed5e03
# ╠═9f5e8d46-c74b-4cc2-ac45-558e2c0c09fd
# ╠═1037869f-9e59-4f27-a938-9aeda621affd
# ╠═4d8148b2-0899-4d45-bc7d-c6d739b8b54f
# ╠═e71f7fa9-0628-497e-967e-55499d0f2c1e
# ╠═c2bb534d-7432-4a05-878b-dc18bec1127e
# ╠═5dea973e-fff0-4e46-8b07-9f243aab00ae
# ╟─d5579c06-0de8-474c-8f95-9b2505d17620
# ╠═1a3aba19-8c51-492d-875c-5806dcd37fe8
# ╠═7048765c-7a2b-431e-ae69-ab0094178f26
# ╠═ae6fb0e3-5a4f-4e92-a911-fae25f62c1c1
# ╠═4281651f-1115-42a3-a1bd-397c6e2ca4b4
# ╠═a03e912c-1a92-4888-8902-f56ded89fea7
# ╠═4fd8123d-2ece-466a-9d30-a45e33a8b690
# ╠═7e399920-7aca-4cf2-9aa4-04a2be8f75f2
# ╠═e232d4b6-eba9-4a63-a142-c740b2ee23c2
# ╠═f15c2cf3-fada-4561-ad9f-1858b420d5d5
# ╠═4b170648-c374-423d-a8fc-c79e6dafcb20
# ╟─6f77443d-a3c9-40a8-8a48-5bc1bc503af8
# ╠═864a4c76-efac-4ec7-864c-c68ec7f1742a
# ╠═188d081f-7282-48e4-8080-d8c83a0c6b82
# ╠═0695d472-2b03-4781-9033-31faf9f6eae2
# ╠═543dbe46-0694-4fd0-9086-c72f5331d8b9
# ╠═c146ea3f-2c12-4f8f-9607-dc325a808acb
