evolve(process::StochasticProcess1D, t0::Float64, x0::Float64, dt::Float64, dw::Float64) =
    apply(process, expectation(process, t0, x0, dt), std_deviation(process, t0, x0, dt) * dw) # dw ~ N(0, 1)

apply(::StochasticProcess1D, x0::Float64, dx::Float64) = x0 + dx

std_deviation(process::StochasticProcess1D, t0::Float64, x0::Float64, dt::Float64) = diffusion(process.disc, process, t0, x0, dt)

variance(process::StochasticProcess1D, t0::Float64, x0::Float64, dt::Float64) = variance(process.disc, process, t0, x0, dt)

"""
returns the number of brownian motion and the index \n
say process = (1d, 2d, 1d, 2d), then returns 6 and (1:1, 2:3, 4:4, 5:6)
"""
function bm_index(pr::Vector{StochasticProcess})
    count::Int = 0
    ind = Vector{UnitRange{Int}}[]
    dimensions = Int[]
    for p in pr
        if typeof(p) <: StochasticProcess1D
            append!(dimensions, 1)
        elseif typeof(p) <: StochasticProcess2D
            append!(dimensions, 2)
        end
    end #(1d, 2d, 1d) => [1, 2, 1]
    count = sum(dimensions)
    idx_ed = accumulate(+, dimensions)
    idx_st = [1]
    append!(idx_st, idx_ed[1:end-1] .+ 1)
    ind = map(x->x[1]:x[2], zip(idx_st, idx_ed))
    return count, ind
end