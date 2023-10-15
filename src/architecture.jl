abstract type AbstractDevice end
abstract type AbstractVirtualDevice end
abstract type AbstractTask end
abstract type AbstractVirtualTask end

struct CPU <: AbstractDevice
    n::Int
end
CPU() = CPU(Threads.nthreads())
@kwdef struct VirtualCPU <: AbstractVirtualDevice
    ex
    n
end
function virtualize(ex, ::Type{CPU}, ctx)
    sym = freshen(ctx, :cpu)
    push!(ctx.preamble, quote
        $sym = $ex
    end)
    VirtualCPU(sym, virtualize(:($sym.n), Int, ctx))
end
lower(device::VirtualCPU, ctx::AbstractCompiler, ::DefaultStyle) =
    something(device.ex, :(CPU($(ctx(device.n)))))

FinchNotation.finch_leaf(device::VirtualCPU) = virtual(device)

struct Serial <: AbstractTask end
const serial = Serial()
get_device(::Serial) = CPU(1)
get_task(::Serial) = nothing
struct VirtualSerial <: AbstractVirtualTask end
virtualize(ex, ::Type{Serial}, ctx) = VirtualSerial()
lower(task::VirtualSerial, ctx::AbstractCompiler, ::DefaultStyle) = :(Serial())
FinchNotation.finch_leaf(device::VirtualSerial) = virtual(device)
virtual_get_device(::VirtualSerial) = VirtualCPU(1)
virtual_get_task(::VirtualSerial) = nothing

struct CPUThread{Parent} <: AbstractTask
    tid::Int
    dev::CPU
    parent::Parent
end
get_device(task::CPUThread) = task.device
get_task(task::CPUThread) = task.parent
struct VirtualCPUThread <: AbstractVirtualTask
    tid
    dev::VirtualCPU
    parent
end
function virtualize(ex, ::Type{CPUThread{Parent}}, ctx) where {Parent}
    VirtualCPUThread(
        virtualize(:($sym.tid), Int, ctx),
        virtualize(:($sym.dev), CPU, ctx),
        virtualize(:($sym.parent), Parent, ctx)
    )
end
lower(task::VirtualCPUThread, ctx::AbstractCompiler, ::DefaultStyle) = :(CPUThread($(ctx(task.tid)), $(ctx(task.dev)), $(ctx(task.parent))))
FinchNotation.finch_leaf(device::VirtualCPUThread) = virtual(device)
virtual_get_device(task::VirtualCPUThread) = task.device
virtual_get_task(task::VirtualCPUThread) = task.parent

struct CPULocalMemory
    device::CPU
end
function moveto(vec::V, mem::CPULocalMemory) where {V <: Vector}
    CPULocalVector{V}(mem.device, [copy(vec) for _ in 1:mem.device.n])
end

struct CPULocalVector{V}
    device::CPU
    data::Vector{V}
end

CPULocalVector{V}(device::CPU) where {V} =
    CPULocalVector{V}(device, [V([]) for _ in 1:device.n])

Base.eltype(::Type{CPULocalVector{V}}) where {V} = eltype(V)
Base.ndims(::Type{CPULocalVector{V}}) where {V} = ndims(V)

function moveto(vec::Vector, device::CPU)
    return vec
end

function moveto(vec::Vector, task::CPUThread)
    return copy(vec)
end

function moveto(vec::CPULocalVector, task::CPUThread)
    return vec.data[task.tid]
end