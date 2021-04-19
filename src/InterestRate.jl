import Dates.Date

struct ContinuousCompounding <: CompoundingType end
struct SimpleCompounding <: CompoundingType end

struct ModifiedDuration <: Duration end

struct InterestRate{DC <: DayCount, C <: CompoundingType, F <: Frequency}
    rate::Float64
    dc::DC
    comp::C
    freq::F
end

discount_factor(ir::InterestRate, time_frac::Float64) = 1.0 / compound_factor(ir, time_frac)
function discount_factor(ir::InterestRate, d1::Date, d2::Date, ::Date, ::Date) 
    t = year_fraction(ir.dc, d1, d2)
    return 1.0 / compound_factor(ir, t)
end

function compound_factor(ir::InterestRate, time_frac::Float64)
    time_frac < 0.0 && error("negative time is not allowed")
    return _compound_factor(ir.comp, ir.rate, time_frac, ir_freq)
end

_compound_factor(::SimpleCompounding, rate::Float64, time_frac::Float64, ::Frequency)     = 1.0 + rate*time_frac
_compound_factor(::ContinuousCompounding, rate::Float64, time_frac::Float64, ::Frequency) = exp(rate*time_frac)

function compound_factor(ir::InterestRate, date1::Date, date2::Date, ref_start::Date = Date(0), ref_end::Date = Date(0))
    date2 < date1 && error("Date1 $date1 later than date2 $date2")
  
    return compound_factor(ir, year_fraction(ir.dc, date1, date2))
  end
"""
Basically, the inverse of a compoun factor, i.e., 

using JsQL

compound = 1.05; dc = Act360(); comp = SimpleCompounding(); time_frac = 1.0; freq = NoFrequency()

ir = implied_rate(1.05, dc, comp, time_frac, freq)

dump(ir) # see the result
"""
function implied_rate(compound::Float64, dc::DC, comp::C, time_frac::Float64, freq::F) where {DC <: DayCount, C<: CompoundingType, F<: Frequency} 
    rate = compound ≈ 1.0 ? 0.0 : _implied_rate(comp, compound, time_frac, freq)
    return InterestRate{DC, C, F}(rate, dc, comp, freq)
end


function implied_rate(compound::Float64, dc::DayCount, comp::CompoundingType, st::Date, ed::Date)
    #
    st > ed && error("date1 is later than date2, in implied_rate, InterestRate.jl")

    return implied_rate(compound, dc, comp, year_fraction(dc, st, ed), freq)
end

_implied_rate(::SimpleCompounding, compound::Float64, time_frac::Float64, ::Frequency) = (compound -1.0) / time_frac
_implied_rate(::ContinuousCompounding, compound::Float64, time_frac::Float64, ::Frequency) = log(compound) / time_frac
