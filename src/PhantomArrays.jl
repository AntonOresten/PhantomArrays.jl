module PhantomArrays

using StaticArraysCore: StaticArray
import StaticArraysCore: similar_type

export PhantomArray, PhantomVector, PhantomMatrix
export phantomtype, phantom, reify
export @validx

reify(::Val{x}) where x = x
reifytype(::Type{Val{x}}) where x = x

"""
    PhantomArray{T,N,Size,Values}

A PhantomArray is an array whose size and elements are known at compile time,
and can be used as a type parameter, similar to `Val` and `Tuple`.
"""
struct PhantomArray{T,N,Size<:Tuple,Values<:Tuple} <: StaticArray{Size,T,N} end

phantomtype(A::AbstractArray) = PhantomArray{eltype(A),ndims(A),Tuple{size(A)...},Tuple{values(A)...}}

PhantomArray{T,N,Size}(data::Tuple{Vararg{T}}) where {T,N,Size} = PhantomArray{T,N,Size,Tuple{data...}}()
PhantomArray(A::AbstractArray) = phantomtype(A)()
PhantomArray{<:Any,N}(A::AbstractArray{<:Any,N}) where N = PhantomArray(A)

phantom(A::AbstractArray) = PhantomArray(A)
reify(A::PhantomArray) = reshape(reinterpret(eltype(A), [values(A)]), size(A))
reifytype(::Type{A}) where A<:PhantomArray = reshape(reinterpret(eltype(A()), [values(A())]), size(A()))

Base.size(@nospecialize(_::PhantomArray{T,N,Size})) where {T,N,Size} = Tuple(Size.parameters)
Base.values(::PhantomArray{T,N,Size,Values}) where {T,N,Size,Values} = Tuple(Values.parameters)
Base.axes(A::PhantomArray) = Base.OneTo.(size(A))

# StaticArray interface requirements
Base.Tuple(A::PhantomArray) = values(A)

similar_type(::Type{<:PhantomArray{T,N,Size}}, a::Type{T′}=T, b::Type{Size′}=Size) where {T,N,Size,T′,Size′} =
    PhantomArray{T′,N,Size′}

const PhantomVector{T} = PhantomArray{T,1}
const PhantomMatrix{T} = PhantomArray{T,2}

Base.showarg(io::IO, A::PhantomArray, ::Bool) = begin
    type_str = ndims(A) == 1 ? "PhantomVector" :
               ndims(A) == 2 ? "PhantomMatrix" : "PhantomArray"
    print(io, "$type_str{$(eltype(A)), $(ndims(A)), $(Tuple{size(A)...}), Tuple{…}}")
end

# Integer-based indexing (mainly for fallback and printing)
Base.getindex(A::PhantomArray, i::Int) =
    values(A)[i]

Base.getindex(A::PhantomArray, i::CartesianIndex) =
    values(A)[LinearIndices(Tuple(size(A)))[i]]

Base.getindex(A::PhantomArray, i::Int...) = A[CartesianIndex(i)]

# fallback for arbitrary indices
Base.getindex(A::PhantomArray, i...) = PhantomArray(reify(A)[i...])

# Val-based indexing
@generated function Base.getindex(A::PhantomArray, ::Val{N}) where N
    if N isa Integer
        :(values(A)[N])
    else
        :($(PhantomArray(reifytype(A)[N])))
    end
end

@generated function Base.getindex(A::PhantomArray, i::Val...)
    return if j isa NTuple{N,Integer} where N
        :($(reifytype(A)[reifytype.(i)...]))
    else
        :($(PhantomArray(reifytype(A)[reifytype.(i)...])))
    end
end


# A[i,j] -> A[Val(i),Val(j)]
macro validx(expr)
    expr isa Expr && expr.head != :ref && error("@validx must be applied to an indexing expression")
    A = esc(expr.args[1])
    indices = map(expr.args[2:end]) do idx
        :(Val($idx))
    end
    return :($A[$(indices...)])
end


# Miscellaneous proof-of-concepts

Base.hash(A::PhantomArray, h::UInt) = hash(size(A), hash(values(A), h))

for op in (:+, :-, :*)
    quote
        @generated function (Base.$op)(A::PhantomArray, B::PhantomArray)
            A, B = collect(A()), collect(B())
            result = ($op)(A, B)
            return :($(PhantomArray(result)))
        end
    end |> eval
end

end
