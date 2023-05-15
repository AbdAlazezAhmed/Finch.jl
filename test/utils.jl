reference_getindex(arr, inds...) = getindex(arr, inds...)
reference_getindex(arr::Fiber, inds...) = arr(inds...)

function reference_isequal(a,b)
    size(a) == size(b) || return false
    axes(a) == axes(b) || return false
    for i in CartesianIndices(axes(a))
        reference_getindex(a, Tuple(i)...) == reference_getindex(b, Tuple(i)...) || return false
    end
    return true
end

isstructequal(a, b) = a === b

isstructequal(a::T, b::T) where {T <: Fiber} = 
    isstructequal(a.lvl, b.lvl)

isstructequal(a::T, b::T) where {T <: Finch.SubFiber} = 
    isstructequal(a.lvl, b.lvl) &&
    isstructequal(a.ptr, b.ptr)

isstructequal(a::T, b::T)  where {T <: Pattern} = true

isstructequal(a::T, b::T) where {T <: Element} =
    a.val == b.val

isstructequal(a::T, b::T) where {T <: RepeatRLE} =
    a.shape == b.shape &&
    a.ptr == b.ptr &&
    a.idx == b.idx &&
    a.val == b.val

isstructequal(a::T, b::T) where {T <: Dense} =
    a.shape == b.shape &&
    isstructequal(a.lvl, b.lvl)

isstructequal(a::T, b::T) where {T <: SparseList} =
    a.shape == b.shape &&
    a.ptr == b.ptr &&
    a.idx == b.idx &&
    isstructequal(a.lvl, b.lvl)

isstructequal(a::T, b::T) where {T <: SparseCOO} =
    a.shape == b.shape &&
    a.ptr == b.ptr &&
    a.tbl == b.tbl &&
    isstructequal(a.lvl, b.lvl)

isstructequal(a::T, b::T) where {T <: SparseHash} =
    a.shape == b.shape &&
    a.ptr == b.ptr &&
    a.tbl == b.tbl &&
    a.srt == b.srt &&
    isstructequal(a.lvl, b.lvl)

isstructequal(a::T, b::T) where {T <: SparseVBL} =
    a.shape == b.shape &&
    a.ptr == b.ptr &&
    a.idx == b.idx &&
    a.ofs == b.ofs &&
    isstructequal(a.lvl, b.lvl)

isstructequal(a::T, b::T) where {T <: SparseByteMap} =
    a.shape == b.shape &&
    a.ptr == b.ptr &&
    a.tbl == b.tbl &&
    a.srt == b.srt &&
    isstructequal(a.lvl, b.lvl)

isstructequal(a::T, b::T) where {T <: SparseTriangle} =
    a.shape == b.shape &&
    isstructequal(a.lvl, b.lvl)