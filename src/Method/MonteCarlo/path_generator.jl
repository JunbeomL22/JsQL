using Random
using LinearAlgebra

mutable struct PathGenerator{RSG <: AbstractRNG, S <: StochasticProcess, D <: AbstractDiscretization}
    generator::RSG
    dimension::Int
    timeNum::Int
    bmDimension::Int
    bmInd::Vectort{UnitRange{Int}}
    pathNum::Int # e.g., 100,000
    dtg::DateTimeGrid
    processes::Vector{S}
    corr::Matrix{Float}
    L::LowerTriangular{Float64, Matrix{Float64}}
    paths::Vector{Path}
    disc::D
end

function PathGenerator(processes::Vector{StochasticProcess}, dtg::DateTimeGrid, 
                        generator::AbstractRNG, pathNum::Int = 50000, corr::Matrix{Float} = ones(FLoat,1,1) )
    timeNum = length(dtg.times)
    dimension = length(processes)
    L = cholesky(corr).L
    paths = [Path(dtg, dimension) for _=1:pathNum]
    
    return PathGenerator(generator, dimension, timeNum, pathNUm, dtg, processes, corr, L, paths, EulerDiscretization())
end

function set_init!(pg::PathGenerator)
    x0=get_init.(pg.processes)
    @simd @inbounds for i = 1:pg.pathNum
        pg.paths[i].values[:, 1] = x0
    end
end

function generate_brownianmotion!(pg::PathGenerator)
    @simd @inbounds for i = 1:pg.pathNum
        pg.paths[i].values[2:end] = pg.L * randn(pg.generator, pg.dimension, pg.timeNum-1) .* sqrt.(dtg.dt)'
    end
end

abstract type p end
abstract type p1 <: p end
abstract type p2 <: p end