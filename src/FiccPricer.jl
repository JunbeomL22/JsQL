__precompile__()
module FiccPricer

const bp = 0.0001
const ε = 1.0e-10

include("Time/Times.jl")
include("Math/Math.jl")
using FiccPricer.Math, FiccPricer.Times

export bp, ε

export # abstract_type.jl
LazyObject, Instrument, Swap, SwapType, Bond, Results, AbstractPayoff,
PositionType, AbstractCurrency,
#
CompoundingType, TermStructure, YieldTermStructure, CreditTermStructure, ConvenienceTermStructure,
VolatilityTermStructure, OptionletVolatilityStructure, SwaptionVolatilityStructure,
CashFlows, Leg, CashFlow, Coupon, Duration, IborCouponPricer,
# term
VoltilityType

export # lazy.jl
LazyMixin

export #interest_rate.jl
ContinuousCompounding, SimpleCompounding, ModifiedDuration, discount_factor, compound_factor, 
implied_rate

export # Quote/Quote.jl
Quote

export # TermStructure/curve.jl
Curve, InterpolatedCurve, ZeroCurve, InterpolatedDiscountCurve

export # Termstructures/volatility
ConstantOptionVolatility, BlackConstantVol, local_vol

export # Times.jl
Act360, Act365, BondThirty360, EuroBondThirty360, NoFrequency, Annaul, SemiAnnaul, day_count

export #currencies.jl
AbstractCurrency, NullCurrency, Currency

export # indices.jl
IborIndex, LiborIndex, fixing_date, maturity_date, fixing, forcast_fixing, euribor_index,
usd_libor_index, is_valied_fixing_date, add_fixing!

export # cash_flows/cash_flows.jl
CouponMixin, accrual_start_date, accrual_end_date, ref_period_start, 
ref_period_end, SimpleCashFlow, Leg, ZeroCouponLeg

export # cash_flows/fixed_rate_coupon.jl
FixedRateCoupon, FixedRateLeg
export # cash_flows/floating_rate_coupon.jl
BlackIborCouponPricer, IborCoupon, IborLeg, update_pricer!

export Monomial, MonomialFunction, path_basis_system!, get_type

export value, gradient

function value(::FiccPricer.Math.CostFunction, x::Vector{Float64})
    return 0.0
end
"""
It is recommended to write a custom gradient  \n
rather than using this brute force gradient. It will be much more stable.
"""
function gradient(t::FiccPricer.Math.CostFunction, x::Vector{Float64}) 
    ret = zeros(Float64, length(x))
    fp = fm = 0.0
    basis = zeros(Float64, length(x))
    epsilon = FiccPricer.Math.FINITE_DIFFERENCES_EPSILON
    for i = 1:length(ret)
        basis[i] = epsilon
        fp = FiccPricer.value(t, x + basis)
        basis[i] = -epsilon
        fm = FiccPricer.value(t, x + basis)
        basis[i] = 0.0
        ret[i] = (fp-fm) / (2.0epsilon)
    end
    return ret
end

#IRRFinder, operator, 
#amount, date, duration, yield, previous_cashflow_date,
#accrual_days, accrual_days, next_cashflow, has_occurred, accrued_amount, 
#next_coupon_rate, maturity_date, initialize!,

# Abstract Types
include("abstract_type.jl")

include("currencies/currencies.jl")
include("Time/DayCount.jl")
include("InterestRate.jl")
include("observer.jl")
include("lazy.jl")
include("Quote/Quote.jl")
include("TermStructures/TermStructure.jl")
include("TermStructures/curve.jl")
include("TermStructures/yield/zero_curve.jl")
include("TermStructures/volatility/vol_term_structure.jl")
include("TermStructures/volatility/black_vol_term_structure.jl")
include("indices/indices.jl")

# Cash Flows ------------------------------------
include("cash_flows/cash_flows.jl")
include("cash_flows/fixed_rate_coupon.jl")
include("cash_flows/floating_rate_coupon.jl")

# Method ----------------------
include("Method/MonteCarlo/lsm_basis_system.jl")

# Process ---------------------
include("Process/BlackScholesProcess.jl")

mutable struct Settings
    evaluation_date::Date
    counter::Int
    currency::Currency
end

settings = Settings(Date(0), 0, KRWCurrency())

function set_eval_date!(sett::Settings, d::Date, cur::Currency = KRWCurrency())
    sett.evaluation_date = d
    sett.currency = cur
end

export Settings, settings, set_eval_date!

end # module

 
