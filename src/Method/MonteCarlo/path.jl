import Base.getindex, Base.setindex!, Base.length, Base.lastindex, Base.copy

struct Path
    dtg::DateTimeGrid
    values::Matrix{Float}
end

Path(dtg::DateTimeGrid, dimension::Int=1) = Path(dtg, Matrix{Float}(undef, dimension, length(dtg.times)))
Path(dtg::DateTimeGrid, v::Vector{Vector{Float}}) = Path(dtg, transpose(hcat(v...)))

getindex(p::Path, i::Int) = p.values[i]

function (p::Path)(d::Date)    
    d >= p.dtg.refDate || error("path refdate is later than the indexing")
    t = year_fraction(p.dtg.refDate, d)
    return p(t)
end 

function (p::Path)(t::Float)    
    t >= 0.0 || error("path time index is negative")
    i, ratio = interospect_index_ratio(t, p.dtg.times)
    prev_idx = max(i-1, 1)
    return p.values[:, prev_idx] .* ratio[2] .+ p.values[:, i] .* ratio[1]
end 

function (p::Path)(st::Date, ed::Date)   
    p.dtg.refDate <= st || error("path indexing, refDate is later than st date") 
    st <= ed || error("path indexing, st date is later than ed date") 

    return p.values[:, st .<= p.dtg.dates .<= ed]
end 

setindex!(p::Path, x::Float, i::Int) = p.values[i] = x
length(p::Path) = length(p.dtg.times)
lastindex(p::Path) = lastindex(p.values)

copy(p::Path) = Path(p.tg, copy(p.values))
