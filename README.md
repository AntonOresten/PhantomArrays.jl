# PhantomArrays

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://AntonOresten.github.io/PhantomArrays.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://AntonOresten.github.io/PhantomArrays.jl/dev/)
[![Build Status](https://github.com/AntonOresten/PhantomArrays.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/AntonOresten/PhantomArrays.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/AntonOresten/PhantomArrays.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/AntonOresten/PhantomArrays.jl)

### Slow, then *instant*.
### Heavy, then *weightless*.

```julia
julia> using PhantomArrays

julia> a = phantom(rand(20, 30));

julia> b = phantom(rand(30, 40));

julia> @time a * b;
  0.348850 seconds (4.66 M allocations: 244.715 MiB, 13.32% gc time, 99.98% compilation time)

julia> @time a * b;
  0.000003 seconds
```

```julia
julia> p = phantom([3, 1, 4])
3-element PhantomVector{Int64, Tuple{3}, Tuple{3, 1, 4}}:
 3
 1
 4

julia> p |> sizeof
0

julia> p |> reify
3-element reinterpret(Int64, ::Vector{Tuple{Int64, Int64, Int64}}):
 3
 1
 4
```

## Building intuition

Phantoms exist in compile-time type space, and can only be effectively reached by putting our indices in the same space with `Val`:

```julia
julia> @code_warntype p[1]
MethodInstance for getindex(::PhantomVector{Int64, Tuple{3}, Tuple{3, 1, 4}}, ::Int64)
  from getindex(A::PhantomArray, i::Int64) @ PhantomArrays ~/.julia/dev/PhantomArrays/src/PhantomArrays.jl:50
Arguments
  #self#::Core.Const(getindex)
  A::Core.Const([3, 1, 4])
  i::Int64
Body::Int64
1 ─ %1 = PhantomArrays.values::Core.Const(values)
│   %2 = (%1)(A)::Core.Const((3, 1, 4))
│   %3 = Base.getindex(%2, i)::Int64
└──      return %3
```

The value `1` is not known to Julia at compile time, so the compiler only infers that the returned value is a `Float64`. However, by wrapping our indices with `Val`, the values themselves become visible:

```julia
julia> @code_warntype p[Val(1)]
MethodInstance for getindex(::PhantomVector{Int64, Tuple{3}, Tuple{3, 1, 4}}, ::Val{1})
  from getindex(A::PhantomArray, ::Val{N}) where N @ PhantomArrays ~/.julia/dev/PhantomArrays/src/PhantomArrays.jl:62
Static Parameters
  N = 1
Arguments
  #self#::Core.Const(getindex)
  A::Core.Const([3, 1, 4])
  _::Core.Const(Val{1}())
Body::Int64
1 ─ %1 = PhantomArrays.values::Core.Const(values)
│   %2 = (%1)(A)::Core.Const((3, 1, 4))
│   %3 = $(Expr(:static_parameter, 1))::Core.Const(1)
│   %4 = Base.getindex(%2, %3)::Core.Const(3)
└──      return %4
```

Julia correctly figures out that the returned value will be `3`.

## Making things instant

We can define an `exp` to method to better understand how we can get instant results once compiled.

```julia
@generated function Base.exp(A::PhantomArray)
    :($(phantom(exp(reify(A())))))
end
```

This method uses the `@generated` macro to compile specialized code for each distinct PhantomArray. Outside of `:(...)`, `A` is actually just the *type* of the array, from which we can instantiate the actual array, "reify" it, turning it into an array that sits in runtime memory, which we can then call `exp` on in order to get the result. The result gets wrapped in `phantom`, and passed as an expression such that the specialized code is completely deterministic and instant.

```julia
julia> p = phantom(rand(4, 4));

julia> @time exp(p); # first time ever is slow
  0.034701 seconds (185.85 k allocations: 9.281 MiB, 6.61% gc time, 99.96% compilation time)

julia> p = phantom(rand(4, 4));

julia> @time exp(p); # first time again on a new array is faster
  0.005821 seconds (14.87 k allocations: 718.750 KiB, 99.56% compilation time)

julia> @time exp(p); # second time on that same array is instant
  0.000001 seconds
```

It really is instant:

```julia
julia> using Chairmarks

julia> @b exp(p)
5.371 ns
```

Julia is simply *that* good.

The time (once compiled) is constant w.r.t. matrix size:

```julia
julia> m = rand(100, 100);

julia> @b exp(m)
274.292 μs (24 allocs: 471.203 KiB)

julia> p = phantom(m);

julia> @time exp(p);
  0.046001 seconds (331.53 k allocations: 13.906 MiB, 6.04% gc time, 99.60% compilation time)

julia> @time exp(p);
  0.000003 seconds

julia> @b exp(p)
5.816 ns
```

It's 50,000x faster, once compiled!

When we multiply by a scalar, however:

```julia
julia> @time exp(5 * p);
  1.171275 seconds (276.16 k allocations: 1.505 GiB, 2.82% gc time, 2.13% compilation time)

julia> @time exp(5 * p);
  1.163597 seconds (20.03 k allocations: 1.493 GiB, 2.42% gc time)
```

It's **8 orders of magnitude slower**, because multiplying by a scalar introduces type instability, and `PhantomArray` doesn't broadcasting support broadcasting like that yet, heh.
