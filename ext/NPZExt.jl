module NPZExt 

using Finch
using Finch: NPYPath
using Finch.JSON
using Finch.DataStructures

isdefined(Base, :get_extension) ? (using NPZ) : (using ..NPZ)

function Base.getindex(g::NPYPath, key::AbstractString)
    path = joinpath(g.dirname, key)
    if isfile(key, "$path.npy")
        npzread("$path.npy")
    else
        NPYPath(path)
    end
end
Base.setindex!(g::NPYPath, val::AbstractArray, key::AbstractString) = npzwrite(joinpath(mkpath(g.dirname), "$(key).npy"), val)
function Base.setindex!(g::NPYPath, val::AbstractDict, key::AbstractString)
    for (key_2, val) in val
        setindex!(g[key], val, key_2)
    end
end

Finch.bspread_header(g::NPYPath, key) = JSON.parsefile(joinpath(g.dirname, "$key.json"))
Finch.bspwrite_header(g::NPYPath, str::String, key) = write(joinpath(mkpath(g.dirname), "$(key).json"), str)
Finch.bspread_vector(g::NPYPath, key) = g[key]
Finch.bspwrite_vector(g::NPYPath, vec, key) = (g[key] = vec)

function Finch.bspread_bspnpy(fname)
    bspread(NPYPath(fname))
end

function Finch.bspwrite_bspnpy(fname, arr, attrs = OrderedDict())
    bspwrite(NPYPath(fname), arr, attrs)
    fname
end

end