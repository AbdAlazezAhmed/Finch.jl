struct UnfurlStyle end

combine_style(a::DefaultStyle, b::UnfurlStyle) = UnfurlStyle()
combine_style(a::ThunkStyle, b::UnfurlStyle) = ThunkStyle()
combine_style(a::UnfurlStyle, b::UnfurlStyle) = UnfurlStyle()
combine_style(a::UnfurlStyle, b::DimensionalizeStyle) = DimensionalizeStyle()
combine_style(a::UnfurlStyle, b::SimplifyStyle) = b
struct UnfurlVisitor
    ctx
    idx
    ext
end

truncate(node, ctx, ext, ext_2) = node

@kwdef struct Furlable
    fuse = nothing
    body
    tight = nothing
end

FinchNotation.finch_leaf(x::Furlable) = virtual(x)

#Base.show(io::IO, ex::Furlable) = Base.show(io, MIME"text/plain"(), ex)
#function Base.show(io::IO, mime::MIME"text/plain", ex::Furlable)
#    print(io, "Furlable()")
#end

struct FormatLimitation <: Exception
    msg::String
end
FormatLimitation() = FormatLimitation("")

"""
    unfurl_access(tns, ctx, ext, protos...)
    
Return an array object (usually a looplet nest) for lowering the virtual tensor
`tns`. `ext` is the extent of the looplet. `protos` is the list of protocols
that should be used for each index, but one doesn't need to unfurl all the
indices at once.
"""
function unfurl_access(tns::Furlable, ctx, ext, protos...)
    tns = tns.body(ctx, ext)
    return tns
end
unfurl_access(tns, ctx, ext, protos...) = tns

expand_reader(tns::Furlable, ctx::LowerJulia, idxs...) = tns
expand_updater(tns::Furlable, ctx::LowerJulia, idxs...) = tns

#TODO this is a bit of a hack, it would be much better to somehow add a
#statement like writes[] += 1 corresponding to tensor reads/writes that need to
#be toplevel, enforcing only writing once by symbolically or at runtime checking
#number of iterations.
function get_point_body(tns::Furlable, ctx, ext, idx)
    if tns.tight !== nothing && !query(call(==, measure(ext), 1), ctx)
        throw(FormatLimitation("$(typeof(something(tns.tight))) does not support random access, must loop column major over output indices first."))
    end
    nothing
end