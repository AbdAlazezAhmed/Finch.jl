@kwdef struct Unfurled <: AbstractVirtualCombinator
    arr
    ndims = 0
    body
    Unfurled(arr, ndims, body) = begin
        new(arr, ndims, body) 
    end
    Unfurled(arr, ndims, body::Unfurled) = begin
        Unfurled(arr, ndims, body.body) 
    end
    Unfurled(arr, body) = Unfurled(arr, 0, body)
end

Base.show(io::IO, ex::Unfurled) = Base.show(io, MIME"text/plain"(), ex)

function Base.show(io::IO, mime::MIME"text/plain", ex::Unfurled)
    print(io, "Unfurled(")
    print(io, ex.arr)
    print(io, ", ")
    print(io, ex.ndims)
    print(io, ", ")
    print(io, ex.body)
    print(io, ")")
end

Base.summary(io::IO, ex::Unfurled) = print(io, "Unfurled($(summary(ex.arr)), $(ex.ndims), $(summary(ex.body)))")

FinchNotation.finch_leaf(x::Unfurled) = virtual(x)

virtual_size(ctx, tns::Unfurled) = virtual_size(ctx, tns.arr)[1 : end - tns.ndims]
virtual_resize!(ctx, tns::Unfurled, dims...) = virtual_resize!(ctx, tns.arr, dims...) # TODO SHOULD NOT HAPPEN BREAKS LIFECYCLES
virtual_default(ctx, tns::Unfurled) = virtual_default(ctx, tns.arr)

instantiate(ctx, tns::Unfurled, mode, protos) = tns

(ctx::Stylize{<:AbstractCompiler})(node::Unfurled) = ctx(node.body)
function stylize_access(ctx::Stylize{<:AbstractCompiler}, node, tns::Unfurled)
    stylize_access(ctx, node, tns.body)
end

function popdim(node::Unfurled, ctx)
    #I think this is an equivalent form, but it doesn't pop the unfurled node
    #from scalars. I'm not sure if that's good or bad.
    @assert node.ndims + 1 <= length(virtual_size(ctx, node.arr))
    return Unfurled(node.arr, node.ndims + 1, node.body)
end

truncate(ctx, node::Unfurled, ext, ext_2) = Unfurled(node.arr, node.ndims, truncate(ctx, node.body, ext, ext_2))

function get_point_body(ctx, node::Unfurled, ext, idx)
    body_2 = get_point_body(ctx, node.body, ext, idx)
    if body_2 === nothing
        return nothing
    else
        return popdim(Unfurled(node.arr, node.ndims, body_2), ctx)
    end
end

(ctx::ThunkVisitor)(node::Unfurled) = Unfurled(node.arr, node.ndims, ctx(node.body))

function get_run_body(ctx, node::Unfurled, ext)
    body_2 = get_run_body(ctx, node.body, ext)
    if body_2 === nothing
        return nothing
    else
        return popdim(Unfurled(node.arr, node.ndims, body_2), ctx)
    end
end

function get_acceptrun_body(ctx, node::Unfurled, ext)
    body_2 = get_acceptrun_body(ctx, node.body, ext)
    if body_2 === nothing
        return nothing
    else
        return popdim(Unfurled(node.arr, node.ndims, body_2), ctx)
    end
end

function (ctx::SequenceVisitor)(node::Unfurled)
    map(ctx(node.body)) do (keys, body)
        return keys => Unfurled(node.arr, node.ndims, body)
    end
end

phase_body(ctx, node::Unfurled, ext, ext_2) = Unfurled(node.arr, node.ndims, phase_body(ctx, node.body, ext, ext_2))

phase_range(ctx, node::Unfurled, ext) = phase_range(ctx, node.body, ext)

get_spike_body(ctx, node::Unfurled, ext, ext_2) = Unfurled(node.arr, node.ndims, get_spike_body(ctx, node.body, ext, ext_2))

get_spike_tail(ctx, node::Unfurled, ext, ext_2) = Unfurled(node.arr, node.ndims, get_spike_tail(ctx, node.body, ext, ext_2))

visit_fill(node, tns::Unfurled) = visit_fill(node, tns.body)

visit_simplify(node::Unfurled) = Unfurled(node.arr, node.ndims, visit_simplify(node.body))

(ctx::SwitchVisitor)(node::Unfurled) = map(ctx(node.body)) do (guard, body)
    guard => Unfurled(node.arr, node.ndims, body)
end

function unfurl(ctx, tns::Unfurled, ext, mode, protos...)
    Unfurled(tns.arr, tns.ndims, unfurl(ctx, tns.body, ext, mode, protos...))
end

stepper_range(ctx, node::Unfurled, ext) = stepper_range(ctx, node.body, ext)
stepper_body(ctx, node::Unfurled, ext, ext_2) = Unfurled(node.arr, node.ndims, stepper_body(ctx, node.body, ext, ext_2))
stepper_seek(ctx, node::Unfurled, ext) = stepper_seek(ctx, node.body, ext)

jumper_range(ctx, node::Unfurled, ext) = jumper_range(ctx, node.body, ext)
jumper_body(ctx, node::Unfurled, ext, ext_2) = Unfurled(node.arr, node.ndims, jumper_body(ctx, node.body, ext, ext_2))
jumper_seek(ctx, node::Unfurled, ext) = jumper_seek(ctx, node.body, ext)

function short_circuit_cases(ctx, tns::Unfurled, op)
    map(short_circuit_cases(ctx, tns.body, op)) do (guard, body)
        guard => Unfurled(tns.arr, tns.ndims, body)
    end
end

function lower(ctx::AbstractCompiler, node::Unfurled, ::DefaultStyle)
    ctx(node.body)
end

getroot(tns::Unfurled) = getroot(tns.arr)

is_injective(ctx, lvl::Unfurled) = is_injective(ctx, lvl.arr)
is_atomic(ctx, lvl::Unfurled) = is_atomic(ctx, lvl.arr)

function lower_access(ctx::AbstractCompiler, node, tns::Unfurled)
    if !isempty(node.idxs)
        error("Unfurled not lowered completely")
    end
    lower_access(ctx, node, tns.body)
end
