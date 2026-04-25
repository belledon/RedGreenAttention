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

# ╔═╡ 27efaaf7-0e78-43e7-96aa-04128f30bfee
html"""
<style>
    @media screen {
        main {
            margin: 0 auto;
            max-width: 2500px;
            padding-left: max(200px, 10%);
            padding-right: max(200px, 10%);
        }
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
	[S2V(-30, 20)],
	[S2V(10, 0)]
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
tr, _ = Gen.generate(world_model, (nframes, state, wm));

# ╔═╡ 5ca74938-8057-4eca-9055-ca62d8ed15ad
states = get_retval(tr);

# ╔═╡ 891ebf38-5e8d-4348-b510-fb633949c3eb
# Reactive drawing function
function animate_trace(trace, frame)
	_, _, wm = get_args(tr)
	states = get_retval(trace)
	state = states[frame]
	paint_state(state, wm)
end

# ╔═╡ 82635ed3-5e8d-4a40-9637-e8b6cd642438
@bind frames Slider(1:nframes, default=1)

# ╔═╡ bffb10ce-f30f-4d7d-89bb-029a3f8bb124
animate_trace(tr, frames)

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
# ╟─891ebf38-5e8d-4348-b510-fb633949c3eb
# ╟─82635ed3-5e8d-4a40-9637-e8b6cd642438
# ╟─bffb10ce-f30f-4d7d-89bb-029a3f8bb124
