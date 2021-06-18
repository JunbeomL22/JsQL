using JsQL
import Base.length

# import Base.getindex, Base.lastindex

mutable struct TimeGrid
    times::Vector{Float64} # points
    dt::Vector{Float64} # difference between points
    mandatoryTimes::Vector{Float64}
end

mutable struct DateTimeGrid
    refDate::Date
    dates::Vector{Date} # The first date is the refDate
    times::Vector{Float64} # points
    dt::Vector{Float64} # difference between times,
    mandatoryDates::Vector{Date}
    mandatoryTimes::Vector{Float64}
end

length(grid::DateTimeGrid) = length(grid.dates)

function DateTimeGrid(refDate::Date, maturity::Date;
                cal::BusinessCalendar=SouthKoreaSettlementCalendar(), mandDates::Vector{Date}=Date[])
    maturity = adjust(cal, maturity)
    refDate <= maturity || error("refdate is later than maturity in DateTimeGrid.")

    days = (maturity - refDate).value
    dates = Vector{Date}(undef, days+1)
    
    dates[1] = deepcopy(refDate)
    idx = 1
    @inbounds @simd for i = 1:days
        d = refDate + Day(i)
        if is_business_day(cal, d) || d in mandDates
            idx +=1
            dates[idx] = d
        end 
    end
    dates = dates[1:idx]

    _fraction(x) = year_fraction(refDate, x)
    times = _fraction.(dates)
    mandTimes = _fraction.(mandDates)
    if length(times) == 1
        dt = [0.0]
    else
        dt = times[2:end] - times[1:end-1]
    end
    return DateTimeGrid(refDate, dates, times, dt, mandDates, mandTimes)
end

"""
TimeGrid(times::Vector{Float64}, steps::Int) \n
v = [1.0, 3.0, 10.]; steps = 5 \n
tg = TimeGrid(v, steps) \n
 => TimeGrid([0.0, 1.0, 3.0, 4.75, 6.5, 8.25, 10.0], [1.0, 2.0, 1.75, 1.75, 1.75, 1.75], [1.0, 3.0, 10.0])
"""
function TimeGrid(times::Vector{Float64}, steps::Int)
    sortedUniqueTimes = sort(unique(times))

    lastTime = sortedUniqueTimes[end]

    dtMax = lastTime / steps
    periodBegin = 0.0
    times = zeros(1)

    @inbounds @simd for t in sortedUniqueTimes
        periodEnd = t
        if periodEnd != 0.0
            nSteps = Int( floor(
                            (periodEnd - periodBegin) / dtMax + 0.5
                            ))
            nSteps = nSteps != 0 ? nSteps : 1
            dt = (periodEnd - periodBegin) / nSteps
            tempTimes = zeros(nSteps)
            for n = 1:nSteps   
                tempTimes[n] = periodBegin + n*dt
            end
        end
        periodBegin = periodEnd
        times = vcat(times, tempTimes)
    end

    dt = diff(times)

    return TimeGrid(times, dt, sortedUniqueTimes)
end

get_time(tg::TimeGrid, i::Int) = tg.times[i]
lastindex(tg::TimeGrid) = lastindex(tg.times)

is_empty(tg::TimeGrid) = length(tg.times) == 0

function closest_index(tg::TimeGrid, t::Float64)
  # stuff
    res = searchsortedfirst(tg.times, t)
    if res == 1
        return 1
    elseif res == length(tg.times) + 1
        return length(tg.times)
    else
        dt1 = tg.times[res] - t
        dt2 = t - tg.times[res - 1]
        if dt1 < dt2
            return res
        else
            return res - 1
        end
    end
end

function return_index(tg::TimeGrid, t::Float64)
    i = closest_index(tg, t)
    if t ≈ tg.times[i]
        return i
    else
        error("this time grid is wrong, $i $t $(tg.times[i]) $(tg.times[i-1]) $(tg.times[i+1])")
    end
end


  