using Random
using LinearAlgebra

mutable struct PathGenerator{RSG <: AbstractRNG, S <: StochasticProcess}
    generator::RSG
    dimension::Int
    timeNum::Int
    pathNum::Int # e.g., 100,000
    dtg::DateTimeGrid
    processes::Vector{S}
    corr::Matrix{Float}
    L::LowerTriangular{Float64, Matrix{Float64}}
    paths::Vector{Path}
end

function PathGenerator(processes::Vector{StochasticProcess}, dtg::DateTimeGrid, 
                        generator::AbstractRNG, pathNum::Int = 50000, corr::Matrix{Float} = ones(FLoat,1,1) )
    timeNum = length(dtg.times)
    dimension = length(processes)
    L = cholesky(corr).L
    paths = [Path(dtg, dimension) for _=1:pathNum]
    return PathGenerator(generator, dimension, timeNum, pathNUm, dtg, processes, corr, L, paths)
end

