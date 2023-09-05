using Finch: level_ndims
using CIndices

bswrite_type_lookup = Dict(
    UInt8 => "uint8",
    UInt16 => "uint16",
    UInt32 => "uint32",
    UInt64 => "uint64",
    Int8 => "int8",
    Int16 => "int16",
    Int32 => "int32",
    Int64 => "int64",
    Float32 => "float32",
    Float64 => "float64",
    Bool => "bint8",
)

bswrite_cast_lookup = Dict(
    Bool => UInt8,
)

bsread_type_lookup = Dict(
    "uint8" => UInt8,
    "uint16" => UInt16,
    "uint32" => UInt32,
    "uint64" => UInt64,
    "int8" => Int8,
    "int16" => Int16,
    "int32" => Int32,
    "int64" => Int64,
    "float32" => Float32,
    "float64" => Float64,
    "bint8" => Bool,
)

bswrite_format_lookup = Dict(
    "CSR" => Dict(
        "swizzle" => [1, 2],
        "level" => Dict(
            "level" => "dense",
            "rank" => 1,
            "subformat" => Dict(
                "level" => "sparse",
                "rank" => 1,
                "subformat" => Dict(
                    "level" => "element",
                    "fill_value" => [0]
                )
            )
        )
    ),

    "CSC" => Dict(
        "swizzle" => [2, 1],
        "level" => Dict(
            "level" => "dense",
            "rank" => 1,
            "subformat" => Dict(
                "level" => "sparse",
                "rank" => 1,
                "subformat" => Dict(
                    "level" => "element",
                    "fill_value" => [0]
                )
            )
        )
    ),

    "DCSR" => Dict(
        "swizzle" => [1, 2],
        "level" => Dict(
            "level" => "sparse",
            "rank" => 1,
            "subformat" => Dict(
                "level" => "sparse",
                "rank" => 1,
                "subformat" => Dict(
                    "level" => "element",
                    "fill_value" => [0]
                )
            )
        )
    ),

    "DCSC" => Dict(
        "swizzle" => [2, 1],
        "level" => Dict(
            "level" => "sparse",
            "rank" => 1,
            "subformat" => Dict(
                "level" => "sparse",
                "rank" => 1,
                "subformat" => Dict(
                    "level" => "element",
                    "fill_value" => [0]
                )
            )
        )
    ),

    "COO" => Dict(
        "swizzle" => [1, 2],
        "level" => Dict(
            "level" => "sparse",
            "rank" => 2,
            "subformat" => Dict(
                "level" => "element",
                "fill_value" => [0]
            )
        )
    ),

    "DMAT" => Dict(
        "swizzle" => [1, 2],
        "level" => Dict(
            "level" => "dense",
            "rank" => 1,
            "subformat" => Dict(
                "level" => "dense",
                "rank" => 1,
                "subformat" => Dict(
                    "level" => "element",
                    "fill_value" => [0]
                )
            )
        )
    ),

    "DVEC" => Dict(
        "swizzle" => [1],
        "level" => Dict(
            "level" => "dense",
            "rank" => 1,
            "subformat" => Dict(
                "level" => "element",
                "fill_value" => [0]
            )
        )
    ),

    "VEC" => Dict(
        "swizzle" => [1],
        "level" => Dict(
            "level" => "sparse",
            "rank" => 1,
            "subformat" => Dict(
                "level" => "element",
                "fill_value" => [0]
            )
        )
    )
)

indices_one_to_zero(vec::Vector{<:Integer}) = vec .- one(eltype(vec))
indices_one_to_zero(vec::Vector{<:CIndex{Ti}}) where {Ti} = unsafe_wrap(Array, reinterpret(Ptr{Ti}, pointer(vec)), length(vec); own = false)
indices_zero_to_one(vec::Vector{Ti}) where {Ti} = unsafe_wrap(Array, reinterpret(Ptr{CIndex{Ti}}, pointer(vec)), length(vec); own = false)

function bswrite_data(f, desc, key, data)
    T = get(bswrite_cast_lookup, eltype(data), eltype(data))
    desc["data_types"]["$(key)_type"] = bswrite_type_lookup[eltype(data)]
    f[key] = reinterpret(T, data)
end

function bsread_data(f, desc, key)
    data = read(f[key])
    T = bsread_type_lookup[desc["data_types"]["$(key)_type"]]
    convert(Vector{T}, reinterpret(T, data))
end

Finch.bswrite(fname, fbr::Fiber, attrs = Dict()) = 
    bswrite(fname, swizzle(fbr, 1:ndims(fbr)), attrs)
function Finch.bswrite(fname, fbr::SwizzledArray{Fiber, dims}, attrs = Dict()) where {dims}
    h5open(fname, "w") do f
        desc = Dict(
            "format" => Dict(),
            "fill" => true,
            "swizzle" => reverse(collect(dims)),
            "shape" => size(fbr),
            "data_types" => Dict(),
            "attrs" => attrs,
        )
        bswrite_level(f, desc, desc["format"], fbr.lvl)
        desc["format"] = get(bswrite_format_lookup, (desc["format"], desc["format"]))
        f["binsparse"] = json(desc, 4)
    end
    fname
end

function Finch.bsread(fname)
    h5open(fname, "r") do f
        desc = JSON.parse(read(f["binsparse"]))
        fbr = Fiber(bsread_level(f, desc, desc["format"]))
        if !issorted(reverse(desc["swizzle"]))
            fbr = swizzle(fbr, reverse(desc["swizzle"]))
        end
    end
end
bsread_level(f, desc, fmt) = bsread_level(f, desc, fmt, Val(Symbol(fmt["level"])))

function bswrite_level(f, desc, fmt, lvl::ElementLevel{D}) where {D}
    fmt["level"] = "element"
    bswrite_data(f, desc, "values", lvl.val)
    bswrite_data(f, desc, "fill_value", [D])
end
function bsread_level(f, desc, fmt, ::Val{:element})
    val = bsread_data(f, desc, "values")
    D = bsread_data(f, desc, "fill_value")[1]
    ElementLevel(D, val)
end

function bswrite_level(f, desc, fmt, lvl::DenseLevel{D}) where {D}
    fmt["level"] = "dense"
    fmt["rank"] = 1
    fmt["subformat"] = Dict()
    bswrite_level(f, desc, fmt["subformat"], lvl.lvl)
end
function bsread_level(f, desc, fmt, ::Val{:dense})
    lvl = bsread_level(f, desc, fmt["subformat"])
    R = fmt["rank"]
    for r = 1:R
        n = level_ndims(typeof(lvl))
        shape = CIndex{Int}(desc["shape"][end - n])
        lvl = DenseLevel(lvl, shape)
    end
    lvl
end

function bswrite_level(f, desc, fmt, lvl::SparseListLevel)
    fmt["level"] = "sparse"
    fmt["rank"] = 1
    n = level_ndims(typeof(lvl))
    N = length(desc["shape"])
    if N - n > 0
        bswrite_data(f, desc, "pointers_to_$(N - n)", indices_one_to_zero(lvl.ptr))
    end
    bswrite_data(f, desc, "indices_$(N - n)", indices_one_to_zero(lvl.idx))
    fmt["subformat"] = Dict()
    bswrite_level(f, desc, fmt["subformat"], lvl.lvl)
end
function bswrite_level(f, desc, fmt, lvl::SparseCOOLevel{R}) where {R}
    fmt["level"] = "sparse"
    fmt["rank"] = R
    n = level_ndims(typeof(lvl))
    N = length(desc["shape"])
    if N - n > 0
        bswrite_data(f, desc, "pointers_to_$(N - n)", indices_one_to_zero(lvl.ptr))
    end
    for r = 1:R
        bswrite_data(f, desc, "indices_$(N - n + r - 1)", indices_one_to_zero(lvl.tbl[r]))
    end
    fmt["subformat"] = Dict()
    bswrite_level(f, desc, fmt["subformat"], lvl.lvl)
end
function bsread_level(f, desc, fmt, ::Val{:sparse})
    R = fmt["rank"]
    lvl = bsread_level(f, desc, fmt["subformat"])
    n = level_ndims(typeof(lvl)) + R
    N = length(desc["shape"])
    tbl = (map(1:R) do r
        indices_zero_to_one(bsread_data(f, desc, "indices_$(N - n + r - 1)"))
    end...,)
    if N - n > 0
        ptr = indices_zero_to_one(bsread_data(f, desc, "pointers_to_$(N - n)"))
    else
        ptr = [1, length(tbl[1]) + 1]
    end
    shape = ntuple(r->eltype(tbl[r])(desc["shape"][N - n + r]), R)
    if R == 1
        SparseListLevel(lvl, shape[1], ptr, tbl[1])
    else
        SparseCOOLevel{Int(R), typeof(shape), eltype(ptr)}(lvl, shape, tbl, ptr)
    end
end