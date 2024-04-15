struct ToeplitzArray{dim, Body} <: AbstractCombinator
    body::Body
end

ToeplitzArray(body, dim) = ToeplitzArray{dim}(body)
ToeplitzArray{dim}(body::Body) where {dim, Body} = ToeplitzArray{dim, Body}(body)

Base.show(io::IO, ex::ToeplitzArray) = Base.show(io, MIME"text/plain"(), ex)
function Base.show(io::IO, mime::MIME"text/plain", ex::ToeplitzArray{dim}) where {dim}
	print(io, "ToeplitzArray{$dim}($(ex.body))")
end

#Base.getindex(arr::ToeplitzArray, i...) = ...

struct VirtualToeplitzArray <: AbstractVirtualCombinator
    body
    dim
    VirtualToeplitzArray(body,dim) = begin
      if body isa Thunk
        @assert(false)
      else
        new(body,dim)
      end
    end
end

function is_injective(ctx, lvl::VirtualToeplitzArray)
    sub = is_injective(ctx, lvl.body)
    return [sub[1:lvl.dim]..., false, sub[lvl.dim + 1:end]...]
end
is_atomic(ctx, lvl::VirtualToeplitzArray) = is_atomic(ctx, lvl.body)

Base.show(io::IO, ex::VirtualToeplitzArray) = Base.show(io, MIME"text/plain"(), ex)
function Base.show(io::IO, mime::MIME"text/plain", ex::VirtualToeplitzArray)
	print(io, "VirtualToeplitzArray($(ex.body), $(ex.dim))")
end

Base.summary(io::IO, ex::VirtualToeplitzArray) = print(io, "VToeplitz($(summary(ex.body)), $(ex.dim))")

FinchNotation.finch_leaf(x::VirtualToeplitzArray) = virtual(x)

function virtualize(ctx, ex, ::Type{ToeplitzArray{dim, Body}}) where {dim, Body}
    VirtualToeplitzArray(virtualize(ctx, :($ex.body), Body), dim)
end

"""
    toeplitz(tns, dim)

Create a `ToeplitzArray` such that
```
    Toeplitz(tns, dim)[i...] == tns[i[1:dim-1]..., i[dim] + i[dim + 1], i[dim + 2:end]...]
```
The ToplitzArray can be thought of as adding a dimension that shifts another dimension of the original tensor.
"""
toeplitz(body, dim) = ToeplitzArray(body, dim)
function virtual_call(ctx, ::typeof(toeplitz), body, dim)
    @assert isliteral(dim)
    VirtualToeplitzArray(body, dim.val)
end

unwrap(ctx, arr::VirtualToeplitzArray, var) = call(toeplitz, unwrap(ctx, arr.body, var), arr.dim)

lower(ctx::AbstractCompiler, tns::VirtualToeplitzArray, ::DefaultStyle) = :(ToeplitzArray($(ctx(tns.body)), $(tns.dim)))

function virtual_size(ctx::AbstractCompiler, arr::VirtualToeplitzArray)
    dims = virtual_size(ctx, arr.body)
    return (dims[1:arr.dim - 1]..., dimless, dimless, dims[arr.dim + 1:end]...)
end
function virtual_resize!(ctx::AbstractCompiler, arr::VirtualToeplitzArray, dims...)
    virtual_resize!(ctx, arr.body, dims[1:arr.dim - 1]..., dimless, dims[arr.dim + 2:end]...)
end

function instantiate(ctx, arr::VirtualToeplitzArray, mode, protos)
    VirtualToeplitzArray(instantiate(ctx, arr.body, mode, [protos[1:arr.dim]; protos[arr.dim + 2:end]]), arr.dim)
end

(ctx::Stylize{<:AbstractCompiler})(node::VirtualToeplitzArray) = ctx(node.body)
function stylize_access(ctx::Stylize{<:AbstractCompiler}, node, tns::VirtualToeplitzArray)
    stylize_access(ctx, node, tns.body)
end

#Note, popdim is NOT recursive, it should only be called on the node itself to
#reflect that the child lost a dimension and perhaps update this wrapper
#accordingly.
function popdim(node::VirtualToeplitzArray, ctx::AbstractCompiler)
    @assert length(virtual_size(ctx, node)) >= node.dim + 1
    return node
end

truncate(ctx, node::VirtualToeplitzArray, ext, ext_2) = VirtualToeplitzArray(truncate(ctx, node.body, ext, ext_2), node.dim)

function get_point_body(ctx, node::VirtualToeplitzArray, ext, idx)
    body_2 = get_point_body(ctx, node.body, ext, idx)
    if body_2 === nothing
        return nothing
    else
        return popdim(VirtualToeplitzArray(body_2, node.dim), ctx)
    end
end

(ctx::ThunkVisitor)(node::VirtualToeplitzArray) = VirtualToeplitzArray(ctx(node.body), node.dim)

function get_run_body(ctx, node::VirtualToeplitzArray, ext)
    body_2 = get_run_body(ctx, node.body, ext)
    if body_2 === nothing
        return nothing
    else
        return popdim(VirtualToeplitzArray(body_2, node.dim), ctx)
    end
end

function get_acceptrun_body(ctx, node::VirtualToeplitzArray, ext)
    body_2 = get_acceptrun_body(ctx, node.body, ext)
    if body_2 === nothing
        return nothing
    else
        return popdim(VirtualToeplitzArray(body_2, node.dim), ctx)
    end
end

function (ctx::SequenceVisitor)(node::VirtualToeplitzArray)
    map(ctx(node.body)) do (keys, body)
        return keys => VirtualToeplitzArray(body, node.dim)
    end
end

phase_body(ctx, node::VirtualToeplitzArray, ext, ext_2) = VirtualToeplitzArray(phase_body(ctx, node.body, ext, ext_2), node.dim)
phase_range(ctx, node::VirtualToeplitzArray, ext) = phase_range(ctx, node.body, ext)

get_spike_body(ctx, node::VirtualToeplitzArray, ext, ext_2) = VirtualToeplitzArray(get_spike_body(ctx, node.body, ext, ext_2), node.dim)
get_spike_tail(ctx, node::VirtualToeplitzArray, ext, ext_2) = VirtualToeplitzArray(get_spike_tail(ctx, node.body, ext, ext_2), node.dim)

visit_fill(node, tns::VirtualToeplitzArray) = visit_fill(node, tns.body)
visit_simplify(node::VirtualToeplitzArray) = VirtualToeplitzArray(visit_simplify(node.body), node.dim)

(ctx::SwitchVisitor)(node::VirtualToeplitzArray) = map(ctx(node.body)) do (guard, body)
    guard => VirtualToeplitzArray(body, node.dim)
end

stepper_range(ctx, node::VirtualToeplitzArray, ext) = stepper_range(ctx, node.body, ext)
stepper_body(ctx, node::VirtualToeplitzArray, ext, ext_2) = VirtualToeplitzArray(stepper_body(ctx, node.body, ext, ext_2), node.dim)
stepper_seek(ctx, node::VirtualToeplitzArray, ext) = stepper_seek(ctx, node.body, ext)

jumper_range(ctx, node::VirtualToeplitzArray, ext) = jumper_range(ctx, node.body, ext)
jumper_body(ctx, node::VirtualToeplitzArray, ext, ext_2) = VirtualToeplitzArray(jumper_body(ctx, node.body, ext, ext_2), node.dim)
jumper_seek(ctx, node::VirtualToeplitzArray, ext) = jumper_seek(ctx, node.body, ext)

function short_circuit_cases(ctx, node::VirtualToeplitzArray, op)
    map(short_circuit_cases(ctx, node.body, op)) do (guard, body)
        guard => VirtualToeplitzArray(body, node.dim)
    end
end


getroot(tns::VirtualToeplitzArray) = getroot(tns.body)

function unfurl(ctx, tns::VirtualToeplitzArray, ext, mode, protos...)
    if length(virtual_size(ctx, tns)) == tns.dim + 1
        Unfurled(tns,
            Lookup(
                body = (ctx, idx) -> VirtualPermissiveArray(VirtualOffsetArray(tns.body, ([literal(0) for _ in 1:tns.dim - 1]..., idx)), ([false for _ in 1:tns.dim - 1]..., true)), 
            )
        )
    else
        VirtualToeplitzArray(unfurl(ctx, tns.body, ext, mode, protos...), tns.dim)
    end
end
