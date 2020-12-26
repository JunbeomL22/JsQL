__precompile__()
module FiccPricer

const basisPoint = 0.0001
const ε = 1.0e-10

include("Time/Times.jl")
include("Math/Math.jl")
using FiccPricer.Math, FiccPricer.Times

export
# abstract_type.jl
LazyObject, Instrument, Swap, SwapType, Bond, Results, AbstractPayoff,
PositionType,
#
CompoundingType, TermStructure, YieldTermStructure, CreditTermStructure, ConvenienceTermStructure,
VolatilityTermStructure, OptionletVolatilityTermStructure, SwaptionVolatilityTermStructure,
CashFlows, Leg, CashFlow, Coupon, Duration,
# lazy.jl
LazyMixin,
#interest_rate.jl
ContinuousCompounding, SimpleCompounding, ModifiedDuration, discount_factor, compound_factor, 
implied_rate,
# Quote/Quote.jl
Quote,
# TermStructure/curve.jl
Curve, InterpolatedCurve, ZeroCurve

# experimental! different from original quentlib, dunno waht will happen by adding the following lines
# basically for examples
export 
# Times.jl
Act360, Act365, BondThirty360, EuroBondThirty360, NoFrequency, Annaul, SemiAnnaul, day_count

include("abstract_type.jl")
include("Time/DayCount.jl")
include("InterestRate.jl")
include("observer.jl")
include("lazy.jl")
include("Quote/Quote.jl")
include("TermStructures/TermStructure.jl")
include("TermStructures/curve.jl")
include("TermStructures/Yield/zero_curve.jl")

mutable struct Settings
    evaluation_date::Date
    counter::Int
end

settings = Settings(Date(0), 0)

function set_eval_date!(sett::Settings, d::Date)
    sett.evaluation_date = d
end

export Settings, settings, set_eval_date!

end # module

 
