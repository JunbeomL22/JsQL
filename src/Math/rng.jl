using Random # MersenneTwister

abstract type AbstractRandomSequenceGenerator end

mutable struct PseudoRsg <: AbstractRandomSequenceGenerator
    rng::MersenneTwister
    number::Int
    values::Vector{Float64}
    weight::Float64
end

PseudoRsg(seed::Int, number::Int = 1, weight::Float64 = 1.0) = PseudoRsg(MersenneTwister(seed), number, zeros(number), weight)

mutable struct InverseRsg <: AbstractRandomSequenceGenerator
    rng::MersenneTwister
    number::Int
    values::Vector{Float64}
    weight::Float64
end

InverseRsg(seed::Int, number::Int = 1, weight::Float64 = 1.0) = InverseRsg(MersenneTwister(seed), number, zeros(number), weight)

function next_sequence!(rsg::PseudoRsg)
    rsg.values = rand(rsg.rng, rsg.number)
    return rsg.values, rsg.weight
end

function next_sequence!(rsg::InverseRsg)
    rsg.values = randn(rsg.rng, rsg.number)
    return rsg.values, rsg.weight
end

last_sequence(rsg::AbstractRandomSequenceGenerator) = rsg.values, rsg.weight

function init_sequence_generator!(rsg::AbstractRandomSequenceGenerator, number::Int)
    rsg.number = number
    rsg.values = zeros(number)
  
    return rsg
end