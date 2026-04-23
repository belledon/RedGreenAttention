### A Pluto.jl notebook ###
# v0.20.24

using Markdown
using InteractiveUtils

# ╔═╡ de724114-3eb9-11f1-a3ea-d5140221ca79
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	
	using Revise
	using RedGreenAttention
end

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

# ╔═╡ 33502428-91f0-488d-b226-b74e6b2176ed
Revise.retry()

# ╔═╡ Cell order:
# ╟─27efaaf7-0e78-43e7-96aa-04128f30bfee
# ╠═de724114-3eb9-11f1-a3ea-d5140221ca79
# ╠═335d2425-d149-4b5b-8c0e-f3e152e97bce
# ╠═3c9c7c71-0a31-4844-8ee5-5b3122d7c445
# ╠═33502428-91f0-488d-b226-b74e6b2176ed
