# Red-Green Attention

> This is a WIP, things may break at any time

## Organization

```
.
├── Manifest.toml # Local julia manifest. Do not commit.
├── notebooks     # Interactive demos.
│   ├── attention-draft.jl
│   ├── hard-easy-demo-clean.jl <-- Start here!
│   ├── hard-easy-demo.jl
│   ├── rg-dev.jl
│   └── test-collision.jl
├── Project.toml  # Julia depencencies
├── README.md     
└── src           
    ├── RedGreenAttention.jl   # Main entry 
    ├── world_model            # Definition of the generative model
    ├── experiments            # Implements experiments on the agent
    ├── agent                  # Perception, decision-making and attention
    └── utils                  # Utilities and helper programs
```

## Setup

This project was built in Julia v1.12. (See instructions for installing [Julia](https://github.com/JuliaLang/juliaup))

1. Clone the repo `git clone https://github.com/belledon/RedGreenAttention.git`
2. Go inside the directory: `cd RedGreenAttention`
2. Install project depencencies: `julia --project=. -e "using Pkg; Pkg.instantiate;"`
3. Start Pluto: `julia --project=. -e "using Pluto;Pluto.run();"`
4. In Pluto, open `notebooks/hard-easy-demo-clean.jl`

If you get an error for a custom dependency (i.e., `GenRFS`, please leave an issue.)
