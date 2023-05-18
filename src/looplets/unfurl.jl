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

function (ctx::UnfurlVisitor)(node)
    if istree(node)
        similarterm(node, operation(node), map(ctx, arguments(node)))
    else
        node
    end
end

function (ctx::UnfurlVisitor)(node::FinchNode, eldim = nodim)
    if node.kind === access && node.tns.kind === virtual
        unfurl_access(node, ctx, eldim, node.tns.val)
    elseif node.kind === access && node.tns.kind === variable
        unfurl_access(node, ctx, eldim, ctx.ctx.bindings[node.tns])
    elseif istree(node)
        #TODO propagate eldim here
        similarterm(node, operation(node), map(ctx, arguments(node)))
    else
        node
    end
end

#TODO propagate eldim here
unfurl_access(node, ctx, eldim, tns) = similarterm(node, operation(node), map(ctx, arguments(node)))

function (ctx::LowerJulia)(root::FinchNode, ::UnfurlStyle)
    if root.kind === loop
        idx = root.idx
        @assert root.ext.kind === virtual
        ext = root.ext.val
        body = (UnfurlVisitor(ctx, idx, ext))(root.body)
        ctx(loop(
            idx,
            ext,
            body
        ))
    else
        error("unimplemented")
    end
end

truncate(node, ctx, ext, ext_2) = node

struct SelectVisitor
    ctx
    idxs
end

function (ctx::SelectVisitor)(node)
    if istree(node)
        similarterm(node, operation(node), map(ctx, arguments(node)))
    else
        node
    end
end

function (ctx::SelectVisitor)(node::FinchNode)
    if node.kind === access && node.tns.kind === virtual
        select_access(node, ctx, node.tns.val)
    elseif node.kind === access && node.tns.kind === variable
        select_access(node, ctx, ctx.ctx.bindings[node.tns])
    elseif istree(node)
        similarterm(node, operation(node), map(ctx, arguments(node)))
    else
        node
    end
end
select_access(node, ctx, tns) = similarterm(node, operation(node), map(ctx, arguments(node)))

struct SelectStyle end

combine_style(a::SelectStyle, b::ThunkStyle) = b
combine_style(a::SelectStyle, b::UnfurlStyle) = a
combine_style(a::SelectStyle, b::SelectStyle) = a
combine_style(a::SelectStyle, b::SimplifyStyle) = b

function (ctx::LowerJulia)(root, ::SelectStyle)
    idxs = Dict()
    root = SelectVisitor(ctx, idxs)(root)
    for (idx, val) in pairs(idxs)
        root = loop(idx, Extent(val, val), root)
    end
    contain(ctx) do ctx_2
        ctx_2(root)
    end
end

@kwdef struct Furlable
    val = nothing
    fuse = nothing
    size
    body
    tight = nothing
end

virtual_default(tns::Furlable) = Some(tns.val)
virtual_size(tns::Furlable, ::LowerJulia, dim=nothing) = tns.size

FinchNotation.finch_leaf(x::Furlable) = virtual(x)

#Base.show(io::IO, ex::Furlable) = Base.show(io, MIME"text/plain"(), ex)
#function Base.show(io::IO, mime::MIME"text/plain", ex::Furlable)
#    print(io, "Furlable()")
#end

function stylize_access(node, ctx::Stylize{LowerJulia}, tns::Furlable)
    if !isempty(node.idxs)
        if getunbound(node.idxs[end]) ⊆ keys(ctx.ctx.bindings)
            return SelectStyle()
        elseif ctx.root isa FinchNode && ctx.root.kind === loop && ctx.root.idx == get_furl_root(node.idxs[end])
            return UnfurlStyle()
        end
    end
    return DefaultStyle()
end

function select_access(node, ctx::Finch.SelectVisitor, tns::Furlable)
    if !isempty(node.idxs)
        if getunbound(node.idxs[end]) ⊆ keys(ctx.ctx.bindings)
            var = index(ctx.ctx.freshen(:s))
            val = cache!(ctx.ctx, :s, node.idxs[end])
            ctx.idxs[var] = val
            ext = first(virtual_size(tns, ctx.ctx))
            ext_2 = Extent(val, val)
            tns_2 = truncate(tns, ctx.ctx, ext, ext_2)
            return access(tns_2, node.mode, node.idxs[1:end-1]..., var)
        end
    end
    return similarterm(node, operation(node), map(ctx, arguments(node)))
end

struct FormatLimitation <: Exception
    msg::String
end
FormatLimitation() = FormatLimitation("")

function unfurl_access(node, ctx, eldim, tns::Furlable)
    if !isempty(node.idxs)
        if ctx.idx == get_furl_root(node.idxs[end])
            tns = exfurl(tns.body(ctx.ctx, virtual_size(tns, ctx.ctx, eldim)[end]), ctx.ctx, node.idxs[end], virtual_size(tns, ctx.ctx, eldim)[end])
            return access(tns, node.mode, map(ctx, node.idxs[1:end-1])..., get_furl_root(node.idxs[end]))
        else
            if tns.tight !== nothing && !query(call(==, measure(ctx.ext), 1), ctx.ctx)
                throw(FormatLimitation("$(typeof(something(tns.tight))) does not support random access, must loop column major over output indices first."))
            end
            idxs = map(ctx, node.idxs)
            return access(node.tns, node.mode, idxs...)
        end
    end
    return node
end

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

refurl(tns, ctx, mode) = tns
function exfurl(tns, ctx, idx::FinchNode, ext)
    if idx.kind === index
        return tns
    elseif idx.kind === access && idx.tns.kind === virtual
        exfurl_access(tns, ctx, ext, idx.tns.val)
    else
        error("unimplemented")
    end
end

function get_furl_root_access(idx, tns::Furlable)
    if tns.fuse !== nothing
        get_furl_root(idx.idxs[end])
    else
        nothing
    end
end

function exfurl_access(tns, ctx, ext, node::Furlable)
    @assert node.fuse !== nothing
    node.fuse(tns, ctx, ext)
end