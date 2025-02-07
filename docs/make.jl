using PhantomArrays
using Documenter

DocMeta.setdocmeta!(PhantomArrays, :DocTestSetup, :(using PhantomArrays); recursive=true)

makedocs(;
    modules=[PhantomArrays],
    authors="Anton Oresten <antonoresten@gmail.com> and contributors",
    sitename="PhantomArrays.jl",
    format=Documenter.HTML(;
        canonical="https://AntonOresten.github.io/PhantomArrays.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/AntonOresten/PhantomArrays.jl",
    devbranch="main",
)
