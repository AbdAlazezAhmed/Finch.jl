```@meta
CurrentModule = Finch
```

# Development Guide

We welcome contributions to Finch! Before you start, please double-check in a
[Github issue](https://github.com/willow-ahrens/Finch.jl/issues) that there is
interest from a contributor in moderating your potential pull request.

## Testing

All pull requests should pass continuous integration testing before merging.
For more information about running tests (including filtering test suites or
updating the reference output), run the test script directly:

```
julia tests/runtests.jl --help
```

## Finch Compilation Pipeline

### Program Instances

Finch relies heavily on Julia's
[metaprogramming capabilities](https://docs.julialang.org/en/v1/manual/metaprogramming/) (
[macros](https://docs.julialang.org/en/v1/manual/metaprogramming/#Macros) and
[generated functions](https://docs.julialang.org/en/v1/manual/metaprogramming/#Generated-functions)
in particular) to produce code. To review briefly, a macro allows us to inspect
the syntax of it's arguments and generate replacement syntax. A generated
function allows us to inspect the type of the function arguments and produce
code for a function body.

In normal Finch usage, we might call Finch as follows:

```jldoctest example1; setup = :(using Finch)
julia> C = @fiber(sl(e(0)));

julia> A = @fiber(sl(e(0)), [0, 2, 0, 0, 3]);

julia> B = @fiber(d(e(0)), [11, 12, 13, 14, 15]);

julia> @finch (C .= 0; @loop i C[i] = A[i] * B[i]);

julia> C
SparseList (0) [1:5]
├─[2]: 24
├─[5]: 45
```

The
[`@macroexpand`](https://docs.julialang.org/en/v1/base/base/#Base.macroexpand)
macro allows us to see the result of applying a macro. Let's examine what
happens when we use the `@finch` macro (we've stripped line numbers from the
result to clean it up):

```jldoctest example1
julia> (@macroexpand @finch (C .= 0; @loop i C[i] = A[i] * B[i])) |> Finch.striplines |> Finch.regensym
quote
    _res_1 = (Finch.execute)((Finch.FinchNotation.sequence_instance)((Finch.FinchNotation.declare_instance)((Finch.FinchNotation.variable_instance)(:C, (Finch.FinchNotation.finch_leaf_instance)(C)), literal_instance(0)), begin
                    let i = index_instance(:i)
                        (Finch.FinchNotation.loop_instance)(i, (Finch.FinchNotation.assign_instance)((Finch.FinchNotation.access_instance)((Finch.FinchNotation.variable_instance)(:C, (Finch.FinchNotation.finch_leaf_instance)(C)), (Finch.FinchNotation.updater_instance)((Finch.FinchNotation.create_instance)()), (Finch.FinchNotation.variable_instance)(:i, (Finch.FinchNotation.finch_leaf_instance)(i))), (Finch.FinchNotation.literal_instance)((Finch.FinchNotation.initwrite)((Finch.default)(C))), (Finch.FinchNotation.call_instance)((Finch.FinchNotation.variable_instance)(:*, (Finch.FinchNotation.finch_leaf_instance)(*)), (Finch.FinchNotation.access_instance)((Finch.FinchNotation.variable_instance)(:A, (Finch.FinchNotation.finch_leaf_instance)(A)), (Finch.FinchNotation.reader_instance)(), (Finch.FinchNotation.variable_instance)(:i, (Finch.FinchNotation.finch_leaf_instance)(i))), (Finch.FinchNotation.access_instance)((Finch.FinchNotation.variable_instance)(:B, (Finch.FinchNotation.finch_leaf_instance)(B)), (Finch.FinchNotation.reader_instance)(), (Finch.FinchNotation.variable_instance)(:i, (Finch.FinchNotation.finch_leaf_instance)(i))))))
                    end
                end))
    begin
        C = Finch.get(_res_1, :C, C)
    end
    begin
        _res_1
    end
end

```

In the above output, `@finch` creates an AST of program instances, then calls
`Finch.execute` on it. A program instance is a struct that contains the program
to be executed along with its arguments. Although we can use the above
constructors (e.g. `loop_instance`) to make our own program instance, it is most
convenient to use the unexported macro `Finch.finch_program_instance`:

```jldoctest example1
julia> using Finch: @finch_program_instance

julia> prgm = Finch.@finch_program_instance (C .= 0; @loop i C[i] = A[i] * B[i])
sequence_instance(declare_instance(variable_instance(:C, C), literal_instance(0)), loop_instance(index_instance(:i), assign_instance(access_instance(variable_instance(:C, C), updater_instance(create_instance()), index_instance(:i)), literal_instance(Finch.FinchNotation.InitWriter{0}()), call_instance(variable_instance(:*, *), access_instance(variable_instance(:A, A), reader_instance(), index_instance(:i)), access_instance(variable_instance(:B, B), reader_instance(), index_instance(:i))))))
```

As we can see, our program instance contains not only the AST to be executed,
but also the data to execute the program with. The type of the program instance
contains only the program portion; there may be many program instances with
different inputs, but the same program type. We can run our program using
`Finch.execute`, which returns a `NamedTuple` of outputs.

```jldoctest example1
julia> typeof(prgm)
Finch.FinchNotation.SequenceInstance{Tuple{Finch.FinchNotation.DeclareInstance{Finch.FinchNotation.VariableInstance{:C, Fiber{SparseListLevel{Int64, Int64, ElementLevel{0, Int64}}}}, Finch.FinchNotation.LiteralInstance{0}}, Finch.FinchNotation.LoopInstance{Finch.FinchNotation.IndexInstance{:i}, Finch.FinchNotation.AssignInstance{Finch.FinchNotation.AccessInstance{Finch.FinchNotation.VariableInstance{:C, Fiber{SparseListLevel{Int64, Int64, ElementLevel{0, Int64}}}}, Finch.FinchNotation.UpdaterInstance{Finch.FinchNotation.CreateInstance}, Tuple{Finch.FinchNotation.IndexInstance{:i}}}, Finch.FinchNotation.LiteralInstance{Finch.FinchNotation.InitWriter{0}()}, Finch.FinchNotation.CallInstance{Finch.FinchNotation.VariableInstance{:*, Finch.FinchNotation.LiteralInstance{*}}, Tuple{Finch.FinchNotation.AccessInstance{Finch.FinchNotation.VariableInstance{:A, Fiber{SparseListLevel{Int64, Int64, ElementLevel{0, Int64}}}}, Finch.FinchNotation.ReaderInstance, Tuple{Finch.FinchNotation.IndexInstance{:i}}}, Finch.FinchNotation.AccessInstance{Finch.FinchNotation.VariableInstance{:B, Fiber{DenseLevel{Int64, ElementLevel{0, Int64}}}}, Finch.FinchNotation.ReaderInstance, Tuple{Finch.FinchNotation.IndexInstance{:i}}}}}}}}}

julia> C = Finch.execute(prgm).C
SparseList (0) [1:5]
├─[2]: 24
├─[5]: 45
```

This functionality is sufficient for building finch kernels programatically. For
example, if we wish to define a function `pointwise_sum()` that takes the
pointwise sum of a variable number of vector inputs, we might implement it as
follows:

```jldoctest example1
julia> function pointwise_sum(As...)
           B = @fiber(d(e(0)))
           isempty(As) && return B
           i = Finch.FinchNotation.index_instance(:i)
           A_vars = [Finch.FinchNotation.variable_instance(Symbol(:A, n), As[n]) for n in 1:length(As)]
           #create a list of variable instances with different names to hold the input tensors
           ex = @finch_program_instance 0
           for A_var in A_vars
               ex = @finch_program_instance $A_var[i] + $ex
           end
           prgm = @finch_program_instance (B .= 0; @loop i B[i] = $ex)
           return Finch.execute(prgm).B
       end
pointwise_sum (generic function with 1 method)

julia> pointwise_sum([1, 2], [3, 4])
Dense [1:2]
├─[1]: 4
├─[2]: 6

```

## Virtualization

TODO more on the way...

## Tensor Life Cycle

Every virtual tensor must be in one of two modes: read-only mode or update-only mode. The following functions may be called on virtual tensors throughout their life cycle.

```@docs
declare!
get_reader
get_updater
freeze!
trim!
```

## Fiber internals

Fiber levels are implemented using the following methods:

```@docs
default
declare_level!
assemble_level!
reassemble_level!
freeze_level!
level_ndims
level_size
level_axes
level_eltype
level_default
```