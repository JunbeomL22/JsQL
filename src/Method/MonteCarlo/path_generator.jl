using Random
using LinearAlgebra

mutable struct PathGenerator{RNG <: AbstractRNG, S <: StochasticProcess, D <: AbstractDiscretization}
    generator::RNG
    dimension::Int
    timeNum::Int
    bmDimension::Int
    bmInd::Vectort{UnitRange{Int}}
    pathNum::Int # e.g., 100,000
    dtg::DateTimeGrid
    processes::Vector{S}
    corr::Matrix{Float}
    L::LowerTriangular{Float, Matrix{Float}}
    paths::Vector{Path}
    brownianMotion::Array{Float, 3}
    disc::D
end

function PathGenerator(processes::Vector{StochasticProcess}, dtg::DateTimeGrid, 
                        generator::AbstractRNG, pathNum::Int = 50000, corr::Matrix{Float} = ones(Float,1,1))
    timeNum = length(dtg.times)
    dimension = length(processes)
    L = cholesky(corr).L
    paths = [Path(dtg, dimension) for _=1:pathNum]

    count, ind = bm_index(processes)
    return PathGenerator(generator, dimension, timeNum, count, ind, pathNum, dtg, 
                            processes, corr, L, paths, Array{Float, 3}[], EulerDiscretization())
end

function set_init!(pg::PathGenerator)
    x0=get_init.(pg.processes)
    @simd @inbounds for i = 1:pg.pathNum
        pg.paths[i].values[:, 1] = x0
    end
end

function make_brownianmotion!(pg::PathGenerator, isParallel::Bool=true)
    pg.brownianMotion = Array{Float, 3}(undef, pg.pathNum, pg.bmDimension, length(pg.dtg.times[2:end]))
    randn!(pg.generator, pg.brownianMotion)
    @simd 
end

function generate_brownianmotion!(pg::PathGenerator)
    @simd @inbounds for i = 1:pg.pathNum
        pg.paths[i].values[2:end] = pg.L * randn(pg.generator, pg.dimension, pg.timeNum-1) .* sqrt.(dtg.dt)'
    end
end

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