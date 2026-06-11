### A Pluto.jl notebook ###
# v0.20.28

using Markdown
using InteractiveUtils

# ╔═╡ 94b64dee-5f9f-4ff2-9b96-bfef6c9e759e
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	
	using Luxor
	using PlutoUI
	
	using Revise
	using RedGreenAttention

	using RedGreenAttention: S2V, Rectangle, Circle
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

# ╔═╡ 769e17ce-98b6-4c16-a86f-0529ceef84fd
rect = Rectangle(10, 20, 0)

# ╔═╡ edc73e15-aba5-4823-84d8-fa90532683db
circ = Circle(10)

# ╔═╡ 00b0f987-482c-4f46-908f-21b804eba7ce
rect_pos = S2V(0, 0)

# ╔═╡ f9c55423-a645-4c44-b6b6-83c3955e02b0
circ_pos = S2V(-25, 0)

# ╔═╡ 0072de12-37c9-4d2e-9903-0df6144754eb
circ_vel = S2V(10, 2)

# ╔═╡ a9c6e14f-bc30-489d-ba0e-2e85e076385f
RedGreenAttention.collision_probability(circ, rect, circ_pos, rect_pos, circ_vel)

# ╔═╡ 1570795c-98e1-4e49-ab3e-1e125979f2a4
begin
    d = init_viz!(200.0, 100.0)
    paint!(rect, rect_pos, 0.0)
    paint!(circ, circ_pos, 100.0)
    finish()
    d
end

# ╔═╡ Cell order:
# ╟─94515ebc-6010-11f1-83cf-791b54166c74
# ╠═94b64dee-5f9f-4ff2-9b96-bfef6c9e759e
# ╠═769e17ce-98b6-4c16-a86f-0529ceef84fd
# ╠═edc73e15-aba5-4823-84d8-fa90532683db
# ╠═00b0f987-482c-4f46-908f-21b804eba7ce
# ╠═f9c55423-a645-4c44-b6b6-83c3955e02b0
# ╠═0072de12-37c9-4d2e-9903-0df6144754eb
# ╠═a9c6e14f-bc30-489d-ba0e-2e85e076385f
# ╠═1570795c-98e1-4e49-ab3e-1e125979f2a4
