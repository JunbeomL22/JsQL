using BenchmarkTools
using Base.Threads

function f(r::Float64, n::Int)
    @simd for i = 1:n
        r *= 1.9999999999;
        r *= 0.5;   
    end
    return r
end

function f_thread(r::Float64, n::Int)
    N = nthreads()
    each_num = Int(n/N)
    @threads for i = 1:N
        println("result of $(i): ", f(deepcopy(r), each_num))
    end
end

function test()
    f(1.0, 10000000000)
    println("")
    @time f(1.0, 10000000000)
end