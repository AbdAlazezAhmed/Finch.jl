abstract type AbstractTensor end
abstract type AbstractVirtualTensor end

"""
    declare!(ctx, tns, init)

Declare the read-only virtual tensor `tns` in the context `ctx` with a starting value of `init` and return it.
Afterwards the tensor is update-only.
"""
declare!(ctx, tns, init) = @assert virtual_default(ctx, tns) == init

"""
    instantiate(ctx, tns, mode, protos)
    
Return an object (usually a looplet nest) capable of unfurling the 
virtual tensor `tns`. Before executing a statement, each
subsequent in-scope access will be initialized with a separate call to
`instantiate`. `protos` is the list of protocols in each case.

The fallback for `instantiate` will iteratively move the last element of
`protos` into the arguments of a function. This allows fibers to specialize on
the last arguments of protos rather than the first, as Finch is column major.
"""
function instantiate(ctx, tns, mode, subprotos, protos...)
    if isempty(subprotos)
        throw(FinchProtocolError("$(typeof(tns)) does not support reads with protocol $(protos)"))
    else
        instantiate(ctx, tns, mode, subprotos[1:end-1], subprotos[end], protos...)
    end
end

"""
    freeze!(ctx, tns)

Freeze the update-only virtual tensor `tns` in the context `ctx` and return it.
This may involve trimming any excess overallocated memory.  Afterwards, the
tensor is read-only.
"""
function freeze! end

"""
    thaw!(ctx, tns)

Thaw the read-only virtual tensor `tns` in the context `ctx` and return it. Afterwards,
the tensor is update-only.
"""
thaw!(ctx, tns) = throw(FinchProtocolError("cannot modify $(typeof(tns)) in place (forgot to declare with .= ?)"))

"""
    default(arr)

Return the initializer for `arr`. For SparseArrays, this is 0. Often, the
`default` value becomes the `fill` or `background` value of a tensor.
"""
function default end

"""
    virtual default(arr)

Return the initializer for virtual array `arr`.
"""
function virtual_default end

"""
    virtual_eltype(arr)

Return the element type of the virtual tensor `arr`.
"""
function virtual_eltype end

function virtual_resize!(ctx, tns, dims...)
    for (dim, ref) in zip(dims, virtual_size(ctx, tns))
        if dim !== dimless && ref !== dimless #TODO this should be a function like checkdim or something haha
            push!(ctx.code.preamble, quote
                $(ctx(getstart(dim))) == $(ctx(getstart(ref))) || throw(DimensionMismatch("mismatched dimension start"))
                $(ctx(getstop(dim))) == $(ctx(getstop(ref))) || throw(DimensionMismatch("mismatched dimension stop"))
            end)
        end
    end
    tns
end

"""
    virtual_size(ctx, tns)

Return a tuple of the dimensions of `tns` in the context `ctx`. This is a
function similar in spirit to `Base.axes`.
"""
function virtual_size end

"""
    virtual_resize!(ctx, tns, dims...)

Resize `tns` in the context `ctx`. This is a
function similar in spirit to `Base.resize!`.
"""
function virtual_resize! end

"""
    moveto(arr, device)

If the array is not on the given device, it creates a new version of this array on that device
and copies the data in to it, according to the `device` trait.
"""
function moveto end

"""
    virtual_moveto(device, arr)

If the virtual array is not on the given device, copy the array to that device. This
function may modify underlying data arrays, but cannot change the virtual itself. This
function is used to move data to the device before a kernel is launched.
"""
function virtual_moveto end