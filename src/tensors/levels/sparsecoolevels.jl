"""
    SparseCOOLevel{[N], [TI=Tuple{Int...}], [Ptr, Tbl]}(lvl, [dims])

A subfiber of a sparse level does not need to represent slices which are
entirely [`default`](@ref). Instead, only potentially non-default slices are
stored as subfibers in `lvl`. The sparse coo level corresponds to `N` indices in
the subfiber, so fibers in the sublevel are the slices `A[:, ..., :, i_1, ...,
i_n]`.  A set of `N` lists (one for each index) are used to record which slices
are stored. The coordinates (sets of `N` indices) are sorted in column major
order.  Optionally, `dims` are the sizes of the last dimensions.

`TI` is the type of the last `N` tensor indices, and `Tp` is the type used for
positions in the level.

The type `Tbl` is an NTuple type where each entry k is a subtype `AbstractVector{TI[k]}`.

The type `Ptr` is the type for the pointer array.

```jldoctest
julia> Tensor(Dense(SparseCOO{1}(Element(0.0))), [10 0 20; 30 0 0; 0 0 40])
Tensor(Dense(SparseCOO{1}(Element{0.0, Float64, Int64}(…), (3,), …), 3))

julia> Tensor(SparseCOO{2}(Element(0.0)), [10 0 20; 30 0 0; 0 0 40])
Tensor(SparseCOO{2}(Element{0.0, Float64, Int64}(…), (3, 3), …))
```
"""
struct SparseCOOLevel{N, TI<:Tuple, Ptr, Tbl, Lvl} <: AbstractLevel
    lvl::Lvl
    shape::TI
    ptr::Ptr
    tbl::Tbl
end
const SparseCOO = SparseCOOLevel

SparseCOOLevel(lvl) = throw(ArgumentError("You must specify the number of dimensions in a SparseCOOLevel, e.g. Tensor(SparseCOO{2}(Element(0.0)))"))
SparseCOOLevel(lvl, shape::NTuple{N, Any}, args...) where {N} = SparseCOOLevel{N}(lvl, shape, args...)

SparseCOOLevel{N}(lvl) where {N} = SparseCOOLevel{N, NTuple{N, Int}}(lvl)
SparseCOOLevel{N}(lvl, shape::TI, args...) where {N, TI} = SparseCOOLevel{N, TI}(lvl, shape, args...)
SparseCOOLevel{N, TI}(lvl) where {N, TI} = SparseCOOLevel{N, TI}(lvl, ((zero(Ti) for Ti in TI.parameters)...,))
SparseCOOLevel{N, TI}(lvl, shape) where {N, TI} = 
    SparseCOOLevel{N, TI}(lvl, TI(shape), postype(lvl)[1], ((Ti[] for Ti in TI.parameters)...,))

SparseCOOLevel{N, TI}(lvl::Lvl, shape, ptr::Ptr, tbl::Tbl) where {N, TI, Lvl, Ptr, Tbl} = 
    SparseCOOLevel{N, TI, Ptr, Tbl, Lvl}(lvl, TI(shape), ptr, tbl)

Base.summary(lvl::SparseCOOLevel{N}) where {N} = "SparseCOO{$N}($(summary(lvl.lvl)))"
similar_level(lvl::SparseCOOLevel{N}) where {N} = SparseCOOLevel{N}(similar_level(lvl.lvl))
similar_level(lvl::SparseCOOLevel{N}, tail...) where {N} = SparseCOOLevel{N}(similar_level(lvl.lvl, tail[1:end-N]...), (tail[end-N+1:end]...,))

function postype(::Type{SparseCOOLevel{N, TI, Ptr, Tbl, Lvl}}) where {N, TI, Ptr, Tbl, Lvl}
    return postype(Lvl)
end

function moveto(lvl::SparseCOOLevel{N, TI}, device) where {N, TI}
    lvl_2 = moveto(lvl.lvl, device)
    ptr_2 = moveto(lvl.ptr, device)
    tbl_2 = ntuple(n->moveto(lvl.tbl[n], device), N)
    return SparseCOOLevel{N, TI}(lvl_2, lvl.shape, ptr_2, tbl_2)
end

pattern!(lvl::SparseCOOLevel{N, TI}) where {N, TI} = 
    SparseCOOLevel{N, TI}(pattern!(lvl.lvl), lvl.shape, lvl.ptr, lvl.tbl)

function countstored_level(lvl::SparseCOOLevel, pos)
    countstored_level(lvl.lvl, lvl.ptr[pos + 1] - 1)
end

redefault!(lvl::SparseCOOLevel{N, TI}, init) where {N, TI} = 
    SparseCOOLevel{N, TI}(redefault!(lvl.lvl, init), lvl.shape, lvl.ptr, lvl.tbl)

Base.resize!(lvl::SparseCOOLevel{N, TI}, dims...) where {N, TI} = 
    SparseCOOLevel{N, TI}(resize!(lvl.lvl, dims[1:end-N]...), (dims[end-N + 1:end]...,), lvl.ptr, lvl.tbl)

function Base.show(io::IO, lvl::SparseCOOLevel{N, TI}) where {N, TI}
    if get(io, :compact, false)
        print(io, "SparseCOO{$N}(")
    else
        print(io, "SparseCOO{$N, $TI}(")
    end
    show(io, lvl.lvl)
    print(io, ", ")
    show(IOContext(io, :typeinfo=>TI), lvl.shape)
    print(io, ", ")
    if get(io, :compact, false)
        print(io, "…")
    else
        show(io, lvl.ptr)
        print(io, ", (")
        for (n, Ti) = enumerate(TI.parameters)
            show(io, lvl.tbl[n])
            print(io, ", ")
        end
        print(io, ") ")
    end
    print(io, ")")
end

function display_fiber(io::IO, mime::MIME"text/plain", fbr::SubFiber{<:SparseCOOLevel{N}}, depth) where {N}
    p = fbr.pos
    lvl = fbr.lvl
    if p + 1 > length(lvl.ptr)
        print(io, "SparseCOO(undef...)")
        return
    end

    crds = fbr.lvl.ptr[p]:fbr.lvl.ptr[p + 1] - 1

    print_coord(io, q) = join(io, map(n -> fbr.lvl.tbl[n][q], 1:N), ", ")
    get_fbr(q) = fbr(map(n -> fbr.lvl.tbl[n][q], 1:N)...)

    print(io, "SparseCOO (", default(fbr), ") [", ":,"^(ndims(fbr) - N), "1:")
    join(io, fbr.lvl.shape, ",1:") 
    print(io, "]")
    display_fiber_data(io, mime, fbr, depth, N, crds, print_coord, get_fbr)
end

Base.show(io::IO, node::LabelledFiberTree{<:SubFiber{<:SparseCOOLevel{N}}}) where {N} =
    print(io, "SparseCOO{", N, "} (", default(node.fbr), ") [", ":,"^(ndims(node.fbr) - 1), "1:", size(node.fbr)[end], "]")

function AbstractTrees.children(node::LabelledFiberTree{<:SubFiber{<:SparseCOOLevel{N}}}) where {N}
    fbr = node.fbr
    lvl = fbr.lvl
    pos = fbr.pos
    OrderedDict(map(lvl.ptr[pos]:lvl.ptr[pos + 1] - 1) do qos
        cartesian_fiber_label(map(n -> lvl.tbl[n][qos], 1:N)...) =>
        LabelledFiberTree(SubFiber(lvl.lvl, qos))
    end)
end

@inline level_ndims(::Type{<:SparseCOOLevel{N, TI, Ptr, Tbl, Lvl}}) where {N, TI, Ptr, Tbl, Lvl} = N + level_ndims(Lvl)
@inline level_size(lvl::SparseCOOLevel) = (level_size(lvl.lvl)..., lvl.shape...)
@inline level_axes(lvl::SparseCOOLevel) = (level_axes(lvl.lvl)..., map(Base.OneTo, lvl.shape)...)
@inline level_eltype(::Type{<:SparseCOOLevel{N, TI, Ptr, Tbl, Lvl}}) where {N, TI, Ptr, Tbl, Lvl} = level_eltype(Lvl)
@inline level_default(::Type{<:SparseCOOLevel{N, TI, Ptr, Tbl, Lvl}}) where {N, TI, Ptr, Tbl, Lvl} = level_default(Lvl)
data_rep_level(::Type{<:SparseCOOLevel{N, TI, Ptr, Tbl, Lvl}}) where {N, TI, Ptr, Tbl, Lvl} = (SparseData^N)(data_rep_level(Lvl))

(fbr::AbstractFiber{<:SparseCOOLevel})() = fbr
(fbr::SubFiber{<:SparseCOOLevel})() = fbr
function (fbr::SubFiber{<:SparseCOOLevel{N, TI}})(idxs...) where {N, TI}
    isempty(idxs) && return fbr
    idx = idxs[end-N + 1:end]
    lvl = fbr.lvl
    target = lvl.ptr[fbr.pos]:lvl.ptr[fbr.pos + 1] - 1
    for n = N:-1:1
        target = searchsorted(view(lvl.tbl[n], target), idx[n]) .+ (first(target) - 1)
    end
    isempty(target) ? default(fbr) : SubFiber(lvl.lvl, first(target))(idxs[1:end-N]...)
end

mutable struct VirtualSparseCOOLevel <: AbstractVirtualLevel
    lvl
    ex
    N
    TI
    ptr
    tbl
    Lvl
    shape
    qos_fill
    qos_stop
    prev_pos
end

is_level_injective(lvl::VirtualSparseCOOLevel, ctx) = [is_level_injective(lvl.lvl, ctx)..., (true for _ in 1:lvl.N)...]
is_level_atomic(lvl::VirtualSparseCOOLevel, ctx) = false

function virtualize(ex, ::Type{SparseCOOLevel{N, TI, Ptr, Tbl, Lvl}}, ctx, tag=:lvl) where {N, TI, Ptr, Tbl, Lvl}
    sym = freshen(ctx, tag)
    shape = map(n->value(:($sym.shape[$n]), Int), 1:N)
    qos_fill = freshen(ctx, sym, :_qos_fill)
    qos_stop = freshen(ctx, sym, :_qos_stop)
    ptr = freshen(ctx, tag, :_ptr)
    tbl = map(n->freshen(ctx, tag, :_tbl, n), 1:N)
    push!(ctx.preamble, quote
        $sym = $ex
        $ptr = $ex.ptr
    end)
    for n = 1:N
        push!(ctx.preamble, quote
            $(tbl[n]) = $ex.tbl[$n]
        end)
    end
    lvl_2 = virtualize(:($sym.lvl), Lvl, ctx, sym)
    prev_pos = freshen(ctx, sym, :_prev_pos)
    prev_coord = map(n->freshen(ctx, sym, :_prev_coord_, n), 1:N)
    VirtualSparseCOOLevel(lvl_2, sym, N, TI, ptr, tbl, Lvl, shape, qos_fill, qos_stop, prev_pos)
end
function lower(lvl::VirtualSparseCOOLevel, ctx::AbstractCompiler, ::DefaultStyle)
    quote
        $SparseCOOLevel{$(lvl.N), $(lvl.TI)}(
            $(ctx(lvl.lvl)),
            ($(map(ctx, lvl.shape)...),),
            $(lvl.ptr),
            ($(lvl.tbl...),)
        )
    end
end

Base.summary(lvl::VirtualSparseCOOLevel) = "SparseCOO{$(lvl.N)}($(summary(lvl.lvl)))"

function virtual_level_size(lvl::VirtualSparseCOOLevel, ctx::AbstractCompiler)
    ext = map((ti, stop)->Extent(literal(ti(1)), stop), lvl.TI.parameters, lvl.shape)
    (virtual_level_size(lvl.lvl, ctx)..., ext...)
end

function virtual_level_resize!(lvl::VirtualSparseCOOLevel, ctx::AbstractCompiler, dims...)
    lvl.shape = map(getstop, dims[end - lvl.N + 1:end])
    lvl.lvl = virtual_level_resize!(lvl.lvl, ctx, dims[1:end - lvl.N]...)
    lvl
end

virtual_level_eltype(lvl::VirtualSparseCOOLevel) = virtual_level_eltype(lvl.lvl)
virtual_level_default(lvl::VirtualSparseCOOLevel) = virtual_level_default(lvl.lvl)

postype(lvl::VirtualSparseCOOLevel) = postype(lvl.lvl)

function declare_level!(lvl::VirtualSparseCOOLevel, ctx::AbstractCompiler, pos, init)
    TI = lvl.TI
    Tp = postype(lvl)

    push!(ctx.code.preamble, quote
        $(lvl.qos_fill) = $(Tp(0))
        $(lvl.qos_stop) = $(Tp(0))
    end)
    if issafe(ctx.mode)
        push!(ctx.code.preamble, quote
            $(lvl.prev_pos) = $(Tp(0))
        end)
    end
    lvl.lvl = declare_level!(lvl.lvl, ctx, literal(Tp(0)), init)
    return lvl
end

function trim_level!(lvl::VirtualSparseCOOLevel, ctx::AbstractCompiler, pos)
    Tp = postype(lvl)
    qos = freshen(ctx.code, :qos)

    push!(ctx.code.preamble, quote
        resize!($(lvl.ptr), $(ctx(pos)) + 1)
        $qos = $(lvl.ptr)[end] - $(Tp(1))
        $(Expr(:block, map(1:lvl.N) do n
            :(resize!($(lvl.tbl[n]), $qos))
        end...))
    end)
    lvl.lvl = trim_level!(lvl.lvl, ctx, value(qos, Tp))
    return lvl
end

function assemble_level!(lvl::VirtualSparseCOOLevel, ctx, pos_start, pos_stop)
    pos_start = ctx(cache!(ctx, :p_start, pos_start))
    pos_stop = ctx(cache!(ctx, :p_start, pos_stop))
    return quote
        Finch.resize_if_smaller!($(lvl.ptr), $pos_stop + 1)
        Finch.fill_range!($(lvl.ptr), 0, $pos_start + 1, $pos_stop + 1)
    end
end

function freeze_level!(lvl::VirtualSparseCOOLevel, ctx::AbstractCompiler, pos_stop)
    p = freshen(ctx.code, :p)
    pos_stop = ctx(cache!(ctx, :pos_stop, simplify(pos_stop, ctx)))
    qos_stop = freshen(ctx.code, :qos_stop)
    push!(ctx.code.preamble, quote
        for $p = 2:($pos_stop + 1)
            $(lvl.ptr)[$p] += $(lvl.ptr)[$p - 1]
        end
        $qos_stop = $(lvl.ptr)[$pos_stop + 1] - 1
    end)
    lvl.lvl = freeze_level!(lvl.lvl, ctx, value(qos_stop))
    return lvl
end

function virtual_moveto_level(lvl::VirtualSparseCOOLevel, ctx::AbstractCompiler, arch)
    ptr_2 = freshen(ctx.code, lvl.ptr)
    push!(ctx.code.preamble, quote
        $ptr_2 = $(lvl.ptr)
        $(lvl.ptr) = $moveto($(lvl.ptr), $(ctx(arch)))
    end)
    push!(ctx.code.epilogue, quote
        $(lvl.ptr) = $ptr_2
    end)
    tbl_2 = map(lvl.tbl) do idx
        idx_2 = freshen(ctx.code, idx)
        push!(ctx.code.preamble, quote
            $idx_2 = $idx
            $idx = $moveto($idx, $(ctx(arch)))
        end)
        push!(ctx.code.epilogue, quote
            $idx = $idx_2
        end)
        idx_2
    end
    virtual_moveto_level(lvl.lvl, ctx, arch)
end

struct SparseCOOWalkTraversal
    lvl
    R
    start
    stop
end

function instantiate(fbr::VirtualSubFiber{VirtualSparseCOOLevel}, ctx, mode::Reader, protos)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    Tp = postype(lvl)
    start = value(:($(lvl.ptr)[$(ctx(pos))]), Tp)
    stop = value(:($(lvl.ptr)[$(ctx(pos)) + 1]), Tp)

    instantiate(SparseCOOWalkTraversal(lvl, lvl.N, start, stop), ctx, mode, protos)
end

function instantiate(trv::SparseCOOWalkTraversal, ctx, mode::Reader, subprotos, ::Union{typeof(defaultread), typeof(walk)})
    (lvl, R, start, stop) = (trv.lvl, trv.R, trv.start, trv.stop)
    tag = lvl.ex
    TI = lvl.TI
    Tp = postype(lvl)
    my_i = freshen(ctx.code, tag, :_i)
    my_q = freshen(ctx.code, tag, :_q)
    my_q_step = freshen(ctx.code, tag, :_q_step)
    my_q_stop = freshen(ctx.code, tag, :_q_stop)
    my_i_stop = freshen(ctx.code, tag, :_i_stop)

    Furlable(
        body = (ctx, ext) -> Thunk(
            preamble = quote
                $my_q = $(ctx(start))
                $my_q_stop = $(ctx(stop))
                if $my_q < $my_q_stop
                    $my_i = $(lvl.tbl[R])[$my_q]
                    $my_i_stop = $(lvl.tbl[R])[$my_q_stop - 1]
                else
                    $my_i = $(TI.parameters[R](1))
                    $my_i_stop = $(TI.parameters[R](0))
                end
            end,
            body = (ctx) -> Sequence([
                Phase(
                    stop = (ctx, ext) -> value(my_i_stop),
                    body = (ctx, ext) -> 
                        if R == 1
                            Stepper(
                                seek = (ctx, ext) -> quote
                                    if $(lvl.tbl[R])[$my_q] < $(ctx(getstart(ext)))
                                        $my_q = Finch.scansearch($(lvl.tbl[R]), $(ctx(getstart(ext))), $my_q, $my_q_stop - 1)
                                    end
                                end,
                                preamble = :($my_i = $(lvl.tbl[R])[$my_q]),
                                stop =  (ctx, ext) -> value(my_i),
                                chunk = Spike(
                                    body = Fill(virtual_level_default(lvl)),
                                    tail = instantiate(VirtualSubFiber(lvl.lvl, my_q), ctx, mode, subprotos),
                                ),
                                next = (ctx, ext) -> :($my_q += $(Tp(1)))
                            )
                        else
                            Stepper(
                                seek = (ctx, ext) -> quote
                                    if $(lvl.tbl[R])[$my_q] < $(ctx(getstart(ext)))
                                        $my_q = Finch.scansearch($(lvl.tbl[R]), $(ctx(getstart(ext))), $my_q, $my_q_stop - 1)
                                    end
                                end,
                                preamble = quote
                                    $my_i = $(lvl.tbl[R])[$my_q]
                                    $my_q_step = $my_q
                                    if $(lvl.tbl[R])[$my_q_step] == $my_i
                                        $my_q_step = Finch.scansearch($(lvl.tbl[R]), $my_i + 1, $my_q_step, $my_q_stop - 1)
                                    end
                                end,
                                stop = (ctx, ext) -> value(my_i),
                                chunk = Spike(
                                    body = Fill(virtual_level_default(lvl)),
                                    tail = instantiate(SparseCOOWalkTraversal(lvl, R - 1, value(my_q, Tp), value(my_q_step, Tp)), ctx, mode, subprotos),
                                ),
                                next = (ctx, ext) -> :($my_q = $my_q_step)
                            )
                        end
                ),
                Phase(
                    body = (ctx, ext) -> Run(Fill(virtual_level_default(lvl)))
                )
            ])
        )
    )
end

struct SparseCOOExtrudeTraversal
    lvl
    qos
    fbr_dirty
    coords
    prev_coord
end

instantiate(fbr::VirtualSubFiber{VirtualSparseCOOLevel}, ctx, mode::Updater, protos) =
    instantiate(VirtualHollowSubFiber(fbr.lvl, fbr.pos, freshen(ctx.code, :null)), ctx, mode, protos)
function instantiate(fbr::VirtualHollowSubFiber{VirtualSparseCOOLevel}, ctx, mode::Updater, protos)
    (lvl, pos) = (fbr.lvl, fbr.pos)
    tag = lvl.ex
    TI = lvl.TI
    Tp = postype(lvl)
    qos_fill = lvl.qos_fill
    qos_stop = lvl.qos_stop

    qos = freshen(ctx.code, tag, :_q)
    prev_coord = freshen(ctx.code, tag, :_prev_coord)
    Thunk(
        preamble = quote
            $qos = $qos_fill + 1
            $(if issafe(ctx.mode)
                quote
                    $(lvl.prev_pos) < $(ctx(pos)) || throw(FinchProtocolError("SparseCOOLevels cannot be updated multiple times"))
                    $prev_coord = ()
                end
            end)
        end,
        body = (ctx) -> instantiate(SparseCOOExtrudeTraversal(lvl, qos, fbr.dirty, [], prev_coord), ctx, mode, protos),
        epilogue = quote
            $(lvl.ptr)[$(ctx(pos)) + 1] = $qos - $qos_fill - 1
            $(if issafe(ctx.mode)
                quote
                    if $qos - $qos_fill - 1 > 0
                        $(lvl.prev_pos) = $(ctx(pos))
                    end
                end
            end)
            $qos_fill = $qos - 1
        end
    )
end

function instantiate(trv::SparseCOOExtrudeTraversal, ctx, mode::Updater, subprotos, ::Union{typeof(defaultupdate), typeof(extrude)})
    (lvl, qos, fbr_dirty, coords) = (trv.lvl, trv.qos, trv.fbr_dirty, trv.coords)
    TI = lvl.TI
    Tp = postype(lvl)
    qos_fill = lvl.qos_fill
    qos_stop = lvl.qos_stop
    Furlable(
        body = (ctx, ext) -> 
            if length(coords) + 1 < lvl.N
                Lookup(
                    body = (ctx, i) -> instantiate(SparseCOOExtrudeTraversal(lvl, qos, fbr_dirty, (i, coords...), trv.prev_coord), ctx, mode, subprotos),
                )
            else
                dirty = freshen(ctx.code, :dirty)
                Lookup(
                    body = (ctx, idx) -> Thunk(
                        preamble = quote
                            if $qos > $qos_stop
                                $qos_stop = max($qos_stop << 1, 1)
                                $(Expr(:block, map(1:lvl.N) do n
                                    :(Finch.resize_if_smaller!($(lvl.tbl[n]), $qos_stop))
                                end...))
                                $(contain(ctx_2->assemble_level!(lvl.lvl, ctx_2, value(qos, Tp), value(qos_stop, Tp)), ctx))
                            end
                            $dirty = false
                        end,
                        body = (ctx) -> instantiate(VirtualHollowSubFiber(lvl.lvl, value(qos, Tp), dirty), ctx, mode, subprotos),
                        epilogue = begin
                            coords_2 = map(ctx, (idx, coords...))
                            quote
                                if $dirty
                                    $(if issafe(ctx.mode)
                                        quote
                                            $(trv.prev_coord) < ($(reverse(coords_2)...),) || begin
                                                throw(FinchProtocolError("SparseCOOLevels cannot be updated multiple times"))
                                            end
                                            $(trv.prev_coord) = ($(reverse(coords_2)...),)
                                        end
                                    end)
                                    $(fbr_dirty) = true
                                    $(Expr(:block, map(enumerate(coords_2)) do (n, i)
                                        :($(lvl.tbl[n])[$qos] = $i)
                                    end...))
                                    $qos += $(Tp(1))
                                end
                            end
                        end
                    )
                )
            end
    )
end
