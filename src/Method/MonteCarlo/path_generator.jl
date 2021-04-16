mutable struct PathGenerator{RSG <: AbstractRandomSequenceGenerator, S <: StochasticProcess}
    generator::RSG
    dimension::Int
    timeNumber::Int
    timeGrid::TimeGrid
    processes::Vector{S}
    nextSample::Vector{Sample{Path}}
    temp::Vector{Float64}
end

function PathGenerator(processes::Vector{StochasticProcess}, tg::TimeGrid, generator::AbstractRandomSequenceGenerator)
    generator.timeNumber == length(tg.times) - 1 || error("wrong dimensions")
    dimension = length(processes)
    return PathGenerator(generator, dimension, generator.timeNumber, tg, processes, 
                            fill(Sample(Path(tg), 1.0), dimension), zeros(generator.dimension))
end

function PathGenerator(processes::Vector{StochasticProcess}, len::Float64, timeSteps::Int, generator::AbstractRandomSequenceGenerator)
    timeNumber = generator.timeNumber
    timeSteps == timeNumber || error("sequence generator dimensionality error")
    dimension = length(processes)
    tg = TimeGrid(len, timeSteps)
  
    return PathGenerator(generator, dimension, timeNumber, tg, process, fill(Sample(Path(tg), 1.0), dimension), zeros(dims))
end
  
function get_next!(pg::PathGenerator, i::Int)
    sequenceVals, sequenceWeight = next_sequence!(pg.generator)
  
    pg.nextSample.weight = sequenceWeight
    process = pg.processes[i]
    pg.nextSample[i].value[1] = get_x0(process)
  
    @inbounds @simd for i = 2:length(pg.nextSample[i].value)
        t = pg.timeGrid[i-1]
        dt = pg.timeGrid.dt[i - 1]
        pg.nextSample[i].value[i] = evolve(process, t, pg.nextSample[i].value[i-1], dt, pg.temp[i-1])
    end
  
    return pg.nextSample[i]
end