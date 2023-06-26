"""
    Infintesimal(s)

The Infintesimal type represents an infinitestimal number.  The sign field is
used to represent positive, negative, or zero in this number system.


```jl-doctest
julia> tiny()
+0

julia> positive_tiny()
+ϵ

julia> negative_tiny()
-ϵ

julia> positive_tiny() + negative_tiny()
+0

julia> positive_tiny() * 2
+ϵ

julia> positive_tiny() * negative_tiny()
+0
"""
struct Infinitesimal <: Number
    sign::Int8
end

tiny(x) = Infinitesimal(x)
tiny() = tiny(Int8(0))
const Eps = tiny(Int8(1))

function Base.show(io::IO, x::Infinitesimal)
    print(io, "tiny(", x.sign, "ϵ)")
end

function Base.show(io::IO, mime::MIME"text/plain", x::Infinitesimal)
    if x.sign > 0
        print(io, "+ϵ")
    elseif x.sign < 0
        print(io, "-ϵ")
    elseif x.sign == 0
        print(io, "+0")
    else
        error(io, "unimplemented")
    end
end

#Core definitions for limit type
Base.:(+)(x::Infinitesimal, y::Infinitesimal) = tiny(min(max(x.sign + y.sign, Int8(-1)), Int8(1))) # only operation that needs to be fast
Base.:(-)(x::Infinitesimal, y::Infinitesimal) = tiny(min(max(x.sign - y.sign, Int8(-1)), Int8(1))) # only operation that needs to be fast
Base.:(*)(x::Infinitesimal, y::Infinitesimal) = tiny(0)
Base.:(<)(x::Infinitesimal, y::Infinitesimal) = x.sign < y.sign
Base.:(<=)(x::Infinitesimal, y::Infinitesimal) = x.sign <= y.sign
Base.:(==)(x::Infinitesimal, y::Infinitesimal) = x.sign == y.sign
Base.isless(x::Infinitesimal, y::Infinitesimal) = x < y
Base.isinf(x::Infinitesimal) = false
Base.zero(::Infinitesimal)= tiny(0)
Base.min(x::Infinitesimal, y::Infinitesimal) = tiny(min(x.sign, y.sign))
Base.max(x::Infinitesimal, y::Infinitesimal) = tiny(max(x.sign, y.sign))
Base.:(+)(x::Infinitesimal) = x
Base.:(-)(x::Infinitesimal) = tiny(-x.sign)

#Crazy julia multiple dispatch stuff don't worry about it
limit_types = [Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, BigInt, Float32, Float64]
for S in limit_types
    @eval begin
        (::Type{$S})(i::Infinitesimal) = zero($S)
        Base.convert(::Type{$S}, i::Infinitesimal) = zero($S)
        Base.:(*)(x::$S, y::Infinitesimal) = tiny(Int8(sign(x)) * y.sign)
        Base.:(*)(y::Infinitesimal, x::$S) = tiny(x.sign * Int8(sign(y)))
    end
end

Base.promote_rule(::Type{Infinitesimal}, ::Type{Infinitesimal}) = Infinitesimal
Base.convert(::Type{Infinitesimal}, i::Infinitesimal) = i
Base.hash(x::Infinitesimal, h::UInt) = hash(typeof(x), hash(x.sign, h))

"""
    Limit{T}(x, s)

The Limit type represents endpoints of closed and open intervals.  The val field
is the value of the endpoint.  The sign field is used to represent the
openness/closedness of the interval endpoint, using an Infinitesmal.

```jl-doctest
julia> limit(1.0)
1.0+0

julia> plus_eps(1.0)
1.0+ϵ

julia> minus_eps(1.0)
1.0-ϵ

julia> plus_eps(1.0) + minus_eps(1.0)
2.0+0.0

julia> plus_eps(1.0) * 2
2.0+2.0ϵ

julia> plus_eps(1.0) * minus_eps(1.0)
1.0-1.0ϵ

julia> plus_eps(-1.0) * minus_eps(1.0)
-1.0+2.0ϵ

julia> 1.0 < plus_eps(1.0)
true

julia> 1.0 < minus_eps(1.0)
false
"""
struct Limit{T} <: Number
    val
    sign::Infinitesimal
end

limit(x::T, s) where {T} = Limit{T}(x, s)
plus_eps(x) = limit(x, Eps)
minus_eps(x) = limit(x, -Eps)
limit(x) = limit(x, 0.0)

function Base.show(io::IO, x::Limit)
    print(io, "limit(", x.val, x.sign, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", x::Limit)
    show(io, mime, x.val)
    show(io, mime, x.sign)
end

#Core definitions for limit type
Base.:(+)(x::Limit, y::Limit) = limit(x.val + y.val, x.sign + y.sign)
Base.:(*)(x::Limit, y::Limit) = limit(x.val * y.val, x.val * y.sign + y.val * x.sign) 
Base.:(-)(x::Limit, y::Limit) = limit(x.val - y.val, x.sign - y.sign)
Base.:(<)(x::Limit, y::Limit) = x.val < y.val || (x.val == y.val && x.sign < y.sign)
Base.:(<=)(x::Limit, y::Limit) = x.val < y.val || (x.val == y.val && x.sign <= y.sign)
Base.:(==)(x::Limit, y::Limit) = x.val == y.val && x.sign == y.sign
Base.isless(x::Limit, y::Limit) = x < y
Base.isinf(x::Limit) = isinf(x.val)
Base.zero(x::Limit{T}) where {T} = limit(convert(T, 0))
Base.min(x::Limit) = x
Base.max(x::Limit) = x
Base.:(+)(x::Limit) = x
Base.:(-)(x::Limit) = limit(-x.val, -x.sign)

@inline Base.promote_rule(::Type{Limit{T}}, ::Type{Infinitesimal}) where {T} = Limit{T}

#Crazy julia multiple dispatch stuff don't worry about it
limit_types = [Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128, BigInt, Float32, Float64]
for S in limit_types
    @eval begin
        @inline Base.promote_rule(::Type{Limit{T}}, ::Type{$S}) where {T} = Limit{promote_type(T, $S)}
        @inline Base.promote_rule(::Type{Infinitesimal}, ::Type{$S}) = Limit{$S}
        Base.convert(::Type{Limit{T}}, i::$S) where {T} = limit(convert(T, i))
        Base.convert(::Type{Limit{T}}, i::Infinitesimal) where {T} = limit(zero(T), i)
        Limit(i::$S) = Limit{$S}(i, tiny())
        (::Type{$S})(i::Limit{T}) where {T} = convert($S, i.val)
        Base.convert(::Type{$S}, i::Limit) = convert($S, i.val)
        Base.:(<)(x::Limit, y::$S) = x < limit(y)
        Base.:(<)(x::$S, y::Limit) = limit(x) < y
        Base.:(<=)(x::Limit, y::$S) = x <= limit(y)
        Base.:(<=)(x::$S, y::Limit) = limit(x) <= y
        Base.:(==)(x::Limit, y::$S) = x == limit(y)
        Base.:(==)(x::$S, y::Limit) = limit(x) == y
        Base.isless(x::Limit, y::$S) = x < limit(y)
        Base.isless(x::$S, y::Limit) = limit(x) < y
        Base.:(<)(x::Infinitesimal, y::$S) = limit(x) < limit(y)
        Base.:(<)(x::$S, y::Infinitesimal) = limit(x) < limit(y)
        Base.:(<=)(x::Infinitesimal, y::$S) = limit(x) <= limit(y)
        Base.:(<=)(x::$S, y::Infinitesimal) = limit(x) <= limit(y)
        Base.:(==)(x::Infinitesimal, y::$S) = limit(x) == limit(y)
        Base.:(==)(x::$S, y::Infinitesimal) = limit(x) == limit(y)
        Base.isless(x::Infinitesimal, y::$S) = limit(x) < limit(y)
        Base.isless(x::$S, y::Infinitesimal) = limit(x) < limit(y)
    end
end

Base.promote_rule(::Type{Limit{T}}, ::Type{Limit{S}}) where {T, S} = promote_type(T, S)
Base.convert(::Type{Limit{T}}, i::Limit) where {T} = Limit{T}(convert(T, i.val), i.sign)
Base.hash(x::Limit, h::UInt) = hash(typeof(x), hash(x.val, hash(x.sign, h)))