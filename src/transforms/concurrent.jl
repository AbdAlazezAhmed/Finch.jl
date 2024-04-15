struct FinchConcurrencyError
    msg
end

"""
    is_injective(ctx, tns)

Returns a vector of booleans, one for each dimension of the tensor, indicating
whether the access is injective in that dimension.  A dimension is injective if
each index in that dimension maps to a different memory space in the underlying
array.
"""
function is_injective end

"""
    is_atomic(ctx, tns)

Returns a boolean indicating whether it is safe to update the same element of the
tensor from multiple simultaneous threads.
"""
function is_atomic end

"""
ensure_concurrent(root, ctx)

Ensures that all nonlocal assignments to the tensor root are consistently
accessed with the same indices and associative operator.  Also ensures that the
tensor is either atomic, or accessed by `i` and concurrent and injective on `i`.
"""
function ensure_concurrent(root, ctx)
    @assert @capture root loop(~idx, ~ext, ~body)

    #get local definitions
    locals = Set(filter(!isnothing, map(PostOrderDFS(body)) do node
        if @capture(node, declare(~tns, ~init)) tns end
    end))

    #get nonlocal assignments and group by root
    nonlocal_assigns = Dict()
    for node in PostOrderDFS(body)
        if @capture(node, assign(~lhs, ~op, ~rhs)) && !(getroot(lhs.tns) in locals) && getroot(lhs.tns) !== nothing #TODO remove the nothing check
            push!(get!(nonlocal_assigns, getroot(lhs.tns), []), node)
        end
    end

    for (root, agns) in nonlocal_assigns
        ops = map(agn -> (@capture agn assign(~lhs, ~op, ~rhs); op), agns)
        if !allequal(ops)
            throw(FinchConcurrencyError("Nonlocal assignments to $(root) are not all the same operator"))
        end

        accs = map(agn -> (@capture agn assign(~lhs, ~op, ~rhs); lhs), agns)
        if !allequal(accs)
            throw(FinchConcurrencyError("Nonlocal assignments to $(root) are not all the same access"))
        end
        acc = first(accs)

        if !(
                (@capture(acc, access(~tns, ~mode, ~i..., idx)) && is_injective(ctx, tns)[length(i) + 1]) ||
                isassociative(ctx.algebra, first(ops))
            )
            throw(FinchConcurrencyError("Nonlocal assignments to $(root) are not associative"))
        end

        if !(
            (is_atomic(ctx, acc.tns)) ||
            (@capture(acc, access(~tns, ~mode, ~i..., idx)) && is_injective(ctx, tns)[length(i) + 1])
        )
            throw(FinchConcurrencyError("Cannot prove that $(acc) is safe to update from multiple threads"))
        end
    end

    return root
end