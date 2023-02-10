mutable struct Scalar{D, Tv}# <: AbstractArray{Tv, 0}
    val::Tv
end

Scalar(D, args...) = Scalar{D}(args...)
Scalar{D}(args...) where {D} = Scalar{D, typeof(D)}(args...)
Scalar{D, Tv}() where {D, Tv} = Scalar{D, Tv}(D)

@inline Base.ndims(tns::Scalar) = 0
@inline Base.size(::Scalar) = ()
@inline Base.axes(::Scalar) = ()
@inline Base.eltype(::Scalar{D, Tv}) where {D, Tv} = Tv
@inline default(::Scalar{D}) where {D} = D

(tns::Scalar)() = tns.val
@inline Base.getindex(tns::Scalar) = tns.val

struct VirtualScalar
    ex
    Tv
    D
    name
    val
end

(ctx::Finch.LowerJulia)(tns::VirtualScalar) = :($Scalar{$(tns.D), $(tns.Tv)}($(tns.val)))
function virtualize(ex, ::Type{Scalar{D, Tv}}, ctx, tag) where {D, Tv}
    sym = ctx.freshen(tag)
    val = Symbol(tag, :_val) #TODO hmm this is risky
    push!(ctx.preamble, quote
        $sym = $ex
        $val = $sym.val
    end)
    VirtualScalar(sym, Tv, D, tag, val)
end

virtual_size(::VirtualScalar, ctx) = ()

virtual_default(tns::VirtualScalar) = tns.D
virtual_eltype(tns::VirtualScalar) = tns.Tv

IndexNotation.isliteral(::VirtualScalar) = false

function initialize!(tns::VirtualScalar, ctx)
    push!(ctx.preamble, quote
        $(tns.val) = $(tns.D)
    end)
    tns
end

function freeze!(tns::VirtualScalar, ctx, mode)
    return tns
end

function lowerjulia_access(ctx::LowerJulia, node, tns::VirtualScalar)
    @assert isempty(node.idxs)
    return tns.val
end

struct VirtualDirtyScalar
    ex
    Tv
    D
    name
    val
    dirty
end

virtual_size(::VirtualDirtyScalar, ctx) = ()

virtual_default(tns::VirtualDirtyScalar) = tns.D
virtual_eltype(tns::VirtualDirtyScalar) = tns.Tv

IndexNotation.isliteral(::VirtualDirtyScalar) = false

function lowerjulia_access(ctx::LowerJulia, node, tns::VirtualDirtyScalar)
    @assert isempty(node.idxs)
    push!(ctx.preamble, quote
        $(tns.dirty) = true
    end)
    return tns.val
end