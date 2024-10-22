using Documenter
using TCX2Graph

makedocs(
    sitename = "TCX2Graph Documentation",
    modules  = [TCX2Graph],
    format   = Documenter.HTML(),
)

deploydocs(
    repo = "https://github.com/firefly-cpp/TCX2Graph.jl.git",
    target = "build"
)
