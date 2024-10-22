using Documenter
using TCX2Graph

makedocs(
    sitename = "TCX2Graph Documentation",
    modules  = [TCX2Graph],
    format   = Documenter.HTML(),
    pages    = [
            "Home" => "index.md",
            "Functions" => "functions.md",
        ]
)

deploydocs(
    repo = "github.com/firefly-cpp/TCX2Graph.jl.git",
    target = "build"
)
