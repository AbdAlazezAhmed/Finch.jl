"""
    SparseRLELevel{[Ti=Int], [Ptr, Left, Right]}(lvl, [dim]; [merge = true])

The sparse RLE level represent runs of equivalent slices `A[:, ..., :, i]`
which are not entirely [`default`](@ref). A sorted list is used to record the
left and right endpoints of each run. Optionally, `dim` is the size of the last dimension.

`Ti` is the type of the last tensor index, and `Tp` is the type used for
positions in the level. The types `Ptr`, `Left`, and `Right` are the types of the
arrays used to store positions and endpoints. 

The `merge` keyword argument is used to specify whether the level should merge
duplicate consecutive runs.

```jldoctest
julia> Tensor(Dense(SparseRLELevel(Element(0.0))), [10 0 20; 30 0 0; 0 0 40])
Dense [:,1:3]
├─ [:, 1]: SparseRLE (0.0) [1:3]
│  ├─ [1:1]: 10.0
│  └─ [2:2]: 30.0
├─ [:, 2]: SparseRLE (0.0) [1:3]
└─ [:, 3]: SparseRLE (0.0) [1:3]
   ├─ [1:1]: 20.0
   └─ [3:3]: 40.0
```
"""
struct SparseRLELevel{Ti, Ptr<:AbstractVector, Left<:AbstractVector, Right<:AbstractVector, merge, Lvl} <: AbstractLevel
    lvl::Lvl
    shape::Ti
    ptr::Ptr
    left::Left
    right::Right
    buf::Lvl
end

const SparseRLE = SparseRLELevel
SparseRLELevel(lvl; kwargs...) = SparseRLELevel{Int}(lvl; kwargs...)
SparseRLELevel(lvl, shape, args...; kwargs...) = SparseRLELevel{typeof(shape)}(lvl, shape, args...; kwargs...)
SparseRLELevel{Ti}(lvl; kwargs...) where {Ti} = SparseRLELevel(lvl, zero(Ti); kwargs...)
SparseRLELevel{Ti}(lvl, shape; kwargs...) where {Ti} = SparseRLELevel{Ti}(lvl, shape, postype(lvl)[1], Ti[], Ti[], deepcopy(lvl); kwargs...) #TODO if similar_level could return the same type, we could use it here
SparseRLELevel{Ti}(lvl::Lvl, shape, ptr::Ptr, left::Left, right::Right, buf::Lvl; merge=true) where {Ti, Lvl, Ptr, Left, Right} =
    SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}(lvl, Ti(shape), ptr, left, right, buf)

getmerge(lvl::SparseRLELevel{Ti, Ptr, Left, Right, merge}) where {Ti, Ptr, Left, Right, merge} = merge

Base.summary(lvl::SparseRLELevel) = "SparseRLE($(summary(lvl.lvl)))"
similar_level(lvl::SparseRLELevel, fill_value, eltype::Type, dim, tail...) =
    SparseRLE(similar_level(lvl.lvl, fill_value, eltype, tail...), dim)

function postype(::Type{SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}}) where {Ti, Ptr, Left, Right, merge, Lvl}
    return postype(Lvl)
end

function moveto(lvl::SparseRLELevel{Ti}, device) where {Ti}
    lvl_2 = moveto(lvl.lvl, device)
    ptr = moveto(lvl.ptr, device)
    left = moveto(lvl.left, device)
    right = moveto(lvl.right, device)
    buf = moveto(lvl.buf, device)
    return SparseRLELevel{Ti}(lvl_2, lvl.shape, lvl.ptr, lvl.left, lvl.right, lvl.buf; merge = getmerge(lvl))
end

pattern!(lvl::SparseRLELevel{Ti}) where {Ti} = 
    SparseRLELevel{Ti}(pattern!(lvl.lvl), lvl.shape, lvl.ptr, lvl.left, lvl.right, pattern!(lvl.buf); merge = getmerge(lvl))

function countstored_level(lvl::SparseRLELevel, pos)
    countstored_level(lvl.lvl, lvl.ptr[pos + 1]-1)
end

redefault!(lvl::SparseRLELevel{Ti}, init) where {Ti} = 
    SparseRLELevel{Ti}(redefault!(lvl.lvl, init), lvl.shape, lvl.ptr, lvl.left, lvl.right, redefault!(lvl.buf, init); merge = getmerge(lvl))

Base.resize!(lvl::SparseRLELevel{Ti}, dims...) where {Ti} = 
    SparseRLELevel{Ti}(resize!(lvl.lvl, dims[1:end-1]...), dims[end], lvl.ptr, lvl.left, lvl.right, resize!(lvl.buf, dims[1:end-1]...); merge = getmerge(lvl))

function Base.show(io::IO, lvl::SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}) where {Ti, Ptr, Left, Right, merge, Lvl}
    if get(io, :compact, false)
        print(io, "SparseRLE(")
    else
        print(io, "SparseRLE{$Ti}(")
    end
    show(io, lvl.lvl)
    print(io, ", ")
    show(IOContext(io, :typeinfo=>Ti), lvl.shape)
    print(io, ", ")
    if get(io, :compact, false)
        print(io, "…")
    else
        show(io, lvl.ptr)
        print(io, ", ")
        show(io, lvl.left)
        print(io, ", ")
        show(io, lvl.right)
        print(io, ", ")
        show(io, lvl.buf)
        print(io, "; merge =")
        show(io, merge)
    end
    print(io, ")")
end

labelled_show(io::IO, fbr::SubFiber{<:SparseRLELevel}) =
    print(io, "SparseRLE (", default(fbr), ") [", ":,"^(ndims(fbr) - 1), "1:", size(fbr)[end], "]")

function labelled_children(fbr::SubFiber{<:SparseRLELevel})
    lvl = fbr.lvl
    pos = fbr.pos
    pos + 1 > length(lvl.ptr) && return []
    map(lvl.ptr[pos]:lvl.ptr[pos + 1] - 1) do qos
        LabelledTree(cartesian_label([range_label() for _ = 1:ndims(fbr) - 1]..., range_label(lvl.left[qos], lvl.right[qos])), SubFiber(lvl.lvl, qos))
    end
end

@inline level_ndims(::Type{<:SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}}) where {Ti, Ptr, Left, Right, merge, Lvl} = 1 + level_ndims(Lvl)
@inline level_size(lvl::SparseRLELevel) = (level_size(lvl.lvl)..., lvl.shape)
@inline level_axes(lvl::SparseRLELevel) = (level_axes(lvl.lvl)..., Base.OneTo(lvl.shape))
@inline level_eltype(::Type{<:SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}}) where {Ti, Ptr, Left, Right, merge, Lvl} = level_eltype(Lvl)
@inline level_default(::Type{<:SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}}) where {Ti, Ptr, Left, Right, merge, Lvl}= level_default(Lvl)
data_rep_level(::Type{<:SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}}) where {Ti, Ptr, Left, Right, merge, Lvl} = SparseData(data_rep_level(Lvl))

(fbr::AbstractFiber{<:SparseRLELevel})() = fbr
function (fbr::SubFiber{<:SparseRLELevel})(idxs...)
    isempty(idxs) && return fbr
    lvl = fbr.lvl
    p = fbr.pos
    r1 = searchsortedlast(@view(lvl.left[lvl.ptr[p]:lvl.ptr[p + 1] - 1]), idxs[end])
    r2 = searchsortedfirst(@view(lvl.right[lvl.ptr[p]:lvl.ptr[p + 1] - 1]), idxs[end])
    q = lvl.ptr[p] + first(r1) - 1
    fbr_2 = SubFiber(lvl.lvl, q)
    r1 != r2 ? default(fbr_2) : fbr_2(idxs[1:end-1]...)
end

mutable struct VirtualSparseRLELevel <: AbstractVirtualLevel
    lvl
    ex
    Ti
    shape
    qos_fill
    qos_stop
    ptr
    left
    right
    buf
    merge
    prev_pos
end

is_level_injective(ctx, lvl::VirtualSparseRLELevel) = [false, is_level_injective(ctx, lvl.lvl)...]
is_level_concurrent(ctx, lvl::VirtualSparseRLELevel) = [false, is_level_concurrent(ctx, lvl.lvl)...]
is_level_atomic(ctx, lvl::VirtualSparseRLELevel) = false

postype(lvl::VirtualSparseRLELevel) = postype(lvl.lvl)

function virtualize(ctx, ex, ::Type{SparseRLELevel{Ti, Ptr, Left, Right, merge, Lvl}}, tag=:lvl) where {Ti, Ptr, Left, Right, merge, Lvl}
    sym = freshen(ctx, tag)
    shape = value(:($sym.shape), Int)
    qos_fill = freshen(ctx, sym, :_qos_fill)
    qos_stop = freshen(ctx, sym, :_qos_stop)
    dirty = freshen(ctx, sym, :_dirty)
    ptr = freshen(ctx, tag, :_ptr)
    left = freshen(ctx, tag, :_left)
    right = freshen(ctx, tag, :_right)
    buf = freshen(ctx, tag, :_buf)
    push!(ctx.preamble, quote
        $sym = $ex
        $ptr = $sym.ptr
        $left = $sym.left
        $right = $sym.right
        $buf = $sym.buf
    end)
    prev_pos = freshen(ctx, sym, :_prev_pos)
    lvl_2 = virtualize(ctx, :($sym.lvl), Lvl, sym)
    buf = virtualize(ctx, :($sym.buf), Lvl, sym)
    VirtualSparseRLELevel(lvl_2, sym, Ti, shape, qos_fill, qos_stop, ptr, left, right, buf, merge, prev_pos)
end
function lower(ctx::AbstractCompiler, lvl::VirtualSparseRLELevel, ::DefaultStyle)
    quote
        $SparseRLELevel{$(lvl.Ti)}(
            $(ctx(lvl.lvl)),
            $(ctx(lvl.shape)),
            $(lvl.ptr),
            $(lvl.left),
            $(lvl.right),
            $(ctx(lvl.buf));
            merge = $(lvl.merge)
        )
    end
end

Base.summary(lvl::VirtualSparseRLELevel) = "SparseRLE($(summary(lvl.lvl)))"

function virtual_level_size(ctx, lvl::VirtualSparseRLELevel)
    ext = make_extent(lvl.Ti, literal(lvl.Ti(1.0)), lvl.shape)
    (virtual_level_size(ctx, lvl.lvl)..., ext)
end

function virtual_level_resize!(ctx, lvl::VirtualSparseRLELevel, dims...)
    lvl.shape = getstop(dims[end])
    lvl.lvl = virtual_level_resize!(ctx, lvl.lvl, dims[1:end-1]...)
    lvl.buf = virtual_level_resize!(ctx, lvl.buf, dims[1:end-1]...)
    lvl
end

function virtual_moveto_level(ctx::AbstractCompiler, lvl::VirtualSparseRLELevel, arch)
    ptr_2 = freshen(ctx.code, lvl.ptr)
    left_2 = freshen(ctx.code, lvl.left)
    right_2 = freshen(ctx.code, lvl.right)
    push!(ctx.code.preamble, quote
        $ptr_2 = $(lvl.ptr)
        $left_2 = $(lvl.left)
        $right_2 = $(lvl.right)
        $(lvl.ptr) = $moveto($(lvl.ptr), $(ctx(arch)))
        $(lvl.left) = $moveto($(lvl.left), $(ctx(arch)))
        $(lvl.right) = $moveto($(lvl.right), $(ctx(arch)))
    end)
    push!(ctx.code.epilogue, quote
        $(lvl.ptr) = $ptr_2
        $(lvl.left) = $left_2
        $(lvl.right) = $right_2
    end)
    virtual_moveto_level(ctx, lvl.lvl, arch)
    virtual_moveto_level(ctx, lvl.buf, arch)
end

virtual_level_eltype(lvl::VirtualSparseRLELevel) = virtual_level_eltype(lvl.lvl)
virtual_level_default(lvl::VirtualSparseRLELevel) = virtual_level_default(lvl.lvl)

function declare_level!(ctx::AbstractCompiler, lvl::VirtualSparseRLELevel, pos, init)
    Tp = postype(lvl)
    Ti = lvl.Ti
    qos = call(-, call(getindex, :($(lvl.ptr)), call(+, pos, 1)), 1)
    push!(ctx.code.preamble, quote
        $(lvl.qos_fill) = $(Tp(0))
        $(lvl.qos_stop) = $(Tp(0))
    end)
    if issafe(ctx.mode)
        push!(ctx.code.preamble, quote
            $(lvl.prev_pos) = $(Tp(0))
        end)
    end
    lvl.buf = declare_level!(ctx, lvl.buf, qos, init)
    return lvl
end

function assemble_level!(ctx, lvl::VirtualSparseRLELevel, pos_start, pos_stop)
    pos_start = ctx(cache!(ctx, :p_start, pos_start))
    pos_stop = ctx(cache!(ctx, :p_start, pos_stop))
    return quote
        Finch.resize_if_smaller!($(lvl.ptr), $pos_stop + 1)
        Finch.fill_range!($(lvl.ptr), 0, $pos_start + 1, $pos_stop + 1)
    end
end

#=
function freeze_level!(ctx::AbstractCompiler, lvl::VirtualSparseRLELevel, pos_stop)
    (lvl.buf, lvl.lvl) = (lvl.lvl, lvl.buf)
    p = freshen(ctx.code, :p)
    pos_stop = ctx(cache!(ctx, :pos_stop, simplify(ctx, pos_stop)))
    qos_stop = freshen(ctx.code, :qos_stop)
    push!(ctx.code.preamble, quote
        resize!($(lvl.ptr), $pos_stop + 1)
        for $p = 1:$pos_stop
            $(lvl.ptr)[$p + 1] += $(lvl.ptr)[$p]
        end
        $qos_stop = $(lvl.ptr)[$pos_stop + 1] - 1
        resize!($(lvl.left), $qos_stop)
        resize!($(lvl.right), $qos_stop)
    end)
    lvl.lvl = freeze_level!(ctx, lvl.lvl, value(qos_stop))
    return lvl
end
=#

function freeze_level!(ctx::AbstractCompiler, lvl::VirtualSparseRLELevel, pos_stop)
    Tp = postype(lvl)
    p = freshen(ctx.code, :p)
    pos_stop = ctx(cache!(ctx, :pos_stop, simplify(ctx, pos_stop)))
    qos_stop = freshen(ctx.code, :qos_stop)
    push!(ctx.code.preamble, quote
        resize!($(lvl.ptr), $pos_stop + 1)
        for $p = 1:$pos_stop
            $(lvl.ptr)[$p + 1] += $(lvl.ptr)[$p]
        end
        $qos_stop = $(lvl.ptr)[$pos_stop + 1] - 1
    end)
    if lvl.merge
        lvl.buf = freeze_level!(ctx, lvl.buf, value(qos_stop))
        lvl.lvl = declare_level!(ctx, lvl.lvl, literal(1), literal(virtual_level_default(lvl.buf)))
        unit = ctx(get_smallest_measure(virtual_level_size(ctx, lvl)[end]))
        p = freshen(ctx.code, :p)
        q = freshen(ctx.code, :q)
        q_head = freshen(ctx.code, :q_head)
        q_stop = freshen(ctx.code, :q_stop)
        q_2 = freshen(ctx.code, :q_2)
        checkval = freshen(ctx.code, :check)
        push!(ctx.code.preamble, quote
            $(contain(ctx_2->assemble_level!(ctx_2, lvl.lvl, value(1, Tp), value(qos_stop, Tp)), ctx))
            $q = 1
            $q_2 = 1
            for $p = 1:$pos_stop
                $q_stop = $(lvl.ptr)[$p + 1]
                while $q < $q_stop
                    $q_head = $q
                    while $q + 1 < $q_stop && $(lvl.right)[$q] == $(lvl.left)[$q + 1] - $(unit)
                        $checkval = true
                        $(contain(ctx) do ctx_2
                            left = variable(freshen(ctx.code, :left))
                            ctx_2.bindings[left] = virtual(VirtualSubFiber(lvl.buf, value(q_head, Tp)))
                            right = variable(freshen(ctx.code, :right))
                            ctx_2.bindings[right] = virtual(VirtualSubFiber(lvl.buf, call(+, value(q, Tp), Tp(1))))
                            check = VirtualScalar(:UNREACHABLE, Bool, false, :check, checkval)
                            exts = virtual_level_size(ctx_2, lvl.buf)
                            inds = [index(freshen(ctx_2.code, :i, n)) for n = 1:length(exts)]
                            prgm = assign(access(check, updater), and, call(isequal, access(left, reader, inds...), access(right, reader, inds...)))
                            for (ind, ext) in zip(inds, exts)
                                prgm = loop(ind, ext, prgm)
                            end
                            prgm = instantiate!(ctx_2, prgm)
                            ctx_2(prgm)
                        end)
                        if !$checkval
                            break
                        else
                            $q += 1
                        end
                    end
                    $(lvl.left)[$q_2] = $(lvl.left)[$q_head]
                    $(lvl.right)[$q_2] = $(lvl.right)[$q]
                    $(contain(ctx) do ctx_2
                        src = variable(freshen(ctx.code, :src))
                        ctx_2.bindings[src] = virtual(VirtualSubFiber(lvl.buf, value(q_head, Tp)))
                        dst = variable(freshen(ctx.code, :dst))
                        ctx_2.bindings[dst] = virtual(VirtualSubFiber(lvl.lvl, value(q_2, Tp)))
                        exts = virtual_level_size(ctx_2, lvl.buf)
                        inds = [index(freshen(ctx_2.code, :i, n)) for n = 1:length(exts)]
                        prgm = assign(access(dst, updater, inds...), initwrite(virtual_level_default(lvl.lvl)), access(src, reader, inds...))
                        for (ind, ext) in zip(inds, exts)
                            prgm = loop(ind, ext, prgm)
                        end
                        prgm = instantiate!(ctx_2, prgm)
                        ctx_2(prgm)
                    end)
                    $q_2 += 1
                    $q += 1
                end
                $(lvl.ptr)[$p + 1] = $q_2
            end
            resize!($(lvl.left), $q_2 - 1)
            resize!($(lvl.right), $q_2 - 1)
            $qos_stop = $q_2 - 1
        end)
        lvl.lvl = freeze_level!(ctx, lvl.lvl, value(qos_stop))
        lvl.buf = declare_level!(ctx, lvl.buf, literal(1), literal(virtual_level_default(lvl.buf)))
        lvl.buf = freeze_level!(ctx, lvl.buf, literal(0))
        return lvl
    else
        push!(ctx.code.preamble, quote
            resize!($(lvl.left), $qos_stop)
            resize!($(lvl.right), $qos_stop)
        end)
        (lvl.lvl, lvl.buf) = (lvl.buf, lvl.lvl)
        lvl.lvl = freeze_level!(ctx, lvl.lvl, value(qos_stop))
        return lvl
    end
end

function thaw_level!(ctx::AbstractCompiler, lvl::VirtualSparseRLELevel, pos_stop)
    p = freshen(ctx.code, :p)
    pos_stop = ctx(cache!(ctx, :pos_stop, simplify(ctx, pos_stop)))
    qos_stop = freshen(ctx.code, :qos_stop)
    push!(ctx.code.preamble, quote
        $(lvl.qos_fill) = $(lvl.ptr)[$pos_stop + 1] - 1
        $(lvl.qos_stop) = $(lvl.qos_fill)
        $qos_stop = $(lvl.qos_fill)
        $(if issafe(ctx.mode)
            quote
                $(lvl.prev_pos) = Finch.scansearch($(lvl.ptr), $(lvl.qos_stop) + 1, 1, $pos_stop) - 1
            end
        end)
        for $p = $pos_stop:-1:1
            $(lvl.ptr)[$p + 1] -= $(lvl.ptr)[$p]
        end
    end)
    (lvl.lvl, lvl.buf) = (lvl.buf, lvl.lvl)
    lvl.buf = thaw_level!(ctx, lvl.buf, value(qos_stop))
    return lvl
end

function instantiate(ctx, fbr::VirtualSubFiber{VirtualSparseRLELevel}, mode::Reader, subprotos, ::Union{typeof(defaultread), typeof(walk)})
    (lvl, pos) = (fbr.lvl, fbr.pos) 
    tag = lvl.ex
    Tp = postype(lvl)
    Ti = lvl.Ti
    my_i_end = freshen(ctx.code, tag, :_i_end)
    my_i_stop = freshen(ctx.code, tag, :_i_stop)
    my_i_start = freshen(ctx.code, tag, :_i_start)
    my_q = freshen(ctx.code, tag, :_q)
    my_q_stop = freshen(ctx.code, tag, :_q_stop)

    Furlable(
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $my_q = $(lvl.ptr)[$(ctx(pos))]
                $my_q_stop = $(lvl.ptr)[$(ctx(pos)) + $(Tp(1))]
                if $my_q < $my_q_stop
                    $my_i_end = $(lvl.right)[$my_q_stop - $(Tp(1))]
                else
                    $my_i_end = $(Ti(0))
                end

            end,
            body = (ctx) -> Sequence([
                Phase(
                    stop = (ctx, ext) -> value(my_i_end),
                    body = (ctx, ext) -> Stepper(
                        seek = (ctx, ext) -> quote
                            if $(lvl.right)[$my_q] < $(ctx(getstart(ext)))
                                $my_q = Finch.scansearch($(lvl.right), $(ctx(getstart(ext))), $my_q, $my_q_stop - 1)
                            end
                        end,
                        preamble = quote
                            $my_i_start = $(lvl.left)[$my_q]
                            $my_i_stop = $(lvl.right)[$my_q]
                        end,
                        stop = (ctx, ext) -> value(my_i_stop),
                        body = (ctx, ext) -> Thunk( 
                            body = (ctx) -> Sequence([
                                Phase(
                                    stop = (ctx, ext) -> call(-, value(my_i_start), getunit(ext)),
                                    body = (ctx, ext) -> Run(Fill(virtual_level_default(lvl))),
                                ),
                                Phase(
                                    body = (ctx,ext) -> Run(
                                        body = Simplify(instantiate(ctx, VirtualSubFiber(lvl.lvl, value(my_q)), mode, subprotos))
                                    )
                                )
                            ]),
                            epilogue = quote
                                $my_q += ($(ctx(getstop(ext))) == $my_i_stop)
                            end
                        )
                    )
                ),
                Phase(
                    body = (ctx, ext) -> Run(Fill(virtual_level_default(lvl)))
                )
            ])
        )
    )
end


instantiate(ctx, fbr::VirtualSubFiber{VirtualSparseRLELevel}, mode::Updater, protos) = 
    instantiate(ctx, VirtualHollowSubFiber(fbr.lvl, fbr.pos, freshen(ctx.code, :null)), mode, protos)

function instantiate(ctx, fbr::VirtualHollowSubFiber{VirtualSparseRLELevel}, mode::Updater, subprotos, ::Union{typeof(defaultupdate), typeof(extrude)})
    (lvl, pos) = (fbr.lvl, fbr.pos) 
    tag = lvl.ex
    Tp = postype(lvl)
    Ti = lvl.Ti
    qos = freshen(ctx.code, tag, :_qos)
    qos_fill = lvl.qos_fill
    qos_stop = lvl.qos_stop
    dirty = freshen(ctx.code, tag, :dirty)
    
    Furlable(
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $qos = $qos_fill + 1
                $(if issafe(ctx.mode)
                    quote
                        $(lvl.prev_pos) < $(ctx(pos)) || throw(FinchProtocolError("SparseRLELevels cannot be updated multiple times"))
                    end
                end)
            end,

            body = (ctx) -> AcceptRun(
                body = (ctx, ext) -> Thunk(
                    preamble = quote
                        if $qos > $qos_stop
                            $qos_stop = max($qos_stop << 1, 1)
                            Finch.resize_if_smaller!($(lvl.left), $qos_stop)
                            Finch.resize_if_smaller!($(lvl.right), $qos_stop)
                            $(contain(ctx_2->assemble_level!(ctx_2, lvl.buf, value(qos, Tp), value(qos_stop, Tp)), ctx))
                        end
                        $dirty = false
                    end,
                    body = (ctx) -> instantiate(ctx, VirtualHollowSubFiber(lvl.buf, value(qos, Tp), dirty), mode, subprotos),
                    epilogue = quote
                        if $dirty
                            $(fbr.dirty) = true
                            $(lvl.left)[$qos] = $(ctx(getstart(ext)))
                            $(lvl.right)[$qos] = $(ctx(getstop(ext)))
                            $(qos) += $(Tp(1))
                            $(if issafe(ctx.mode)
                                quote
                                    $(lvl.prev_pos) = $(ctx(pos))
                                end
                            end)
                        end
                    end
                )
            ),
            epilogue = quote
                $(lvl.ptr)[$(ctx(pos)) + 1] += $qos - $qos_fill - 1
                $qos_fill = $qos - 1
            end
        )
    )
end
