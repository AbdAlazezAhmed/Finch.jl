using Finch
y = @fiber d(e(0.0))
A = @fiber d(sl(e(0.0)))
x = @fiber sl(e(0.0))
println(@elapsed Finch.execute_code(:ex, typeof(Finch.@finch_program_instance @loop i j y[i] += A[i, j] * x[i])))
# With no precompilation or anything, this takes 71.272644599s on my garbage macbookpro
# With precompilation, this takes 48.013980111s on my garbage macbookpro