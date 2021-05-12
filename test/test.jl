using BenchmarkTools
using Distributed

addprocs()

@everywhere function f(x)
    for i = 1:2000000000
        x = x*0.9999999
    end
    return x
end
v = rand(3)
@time map(f, v)
@time pmap(f, v)