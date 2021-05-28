__precompile__()
module JsQL

const bp = 0.0001
const ε = 1.0e-10
const Float = Float64

include("Time/Time.jl")
include("Math/Math.jl")
using JsQL.Math, JsQL.Time

export bp, ε, Float

export # abstract_type.jl
LazyObject, Instrument, Swap, SwapType, Bond, Results, AbstractPayoff,
PositionType, AbstractCurrency, 
#
CompoundingType, TermStructure, YieldTermStructure, CreditTermStructure, ConvenienceTermStructure,
VolatilityTermStructure, OptionletVolatilityStructure, SwaptionVolatilityStructure,
CashFlows, Leg, CashFlow, Coupon, Duration, 
# term
VoltilityType, ImpliedVolatility,
# Performer
Worst, Best, Ave,
# Payoff and Exercise
Exercise, StrikedTypePayoff, PerformanceType, Worst, Best, ElsPayoff,
PowerSpreadPayoff,
# PricingEngine
PricingEngine,
# RandomNumber
AbstractRandomSequenceGenerator

export #Process
AbstractBlackScholesProcess, EulerDiscretization, BalckScholes, drift, diffusion, 
state_variable, black_variance, forward_price, BsmDiscreteDiv, accumulated_dividend, dividend_deduction,
QuantoCorrelation

export # lazy.jl
LazyMixin

export #interest_rate.jl
ContinuousCompounding, SimpleCompounding, ModifiedDuration, discount_factor, compound_factor, 
implied_rate

export # Quote/Quote.jl
Quote

export # TermStructure/curve.jl
Curve, InterpolatedCurve, ZeroCurve, InterpolatedDiscountCurve, discount

export # TermStructure/Yield
NullYieldTermStructure, FlatForwardTermStructure, forward_rate, zero_rate

export # Termstructures/Volatility
ConstantOptionVolatility, BlackConstantVol, local_vol,
local_vol_impl, FunctionalSurface

export # implied_Volatility.jl
LocalVolSurface, ImpliedVolatilitySurface, FunctionalSurface

export # Parameter
Parameter, Volatiltiy, ConstantVolatility, TimeStepVolatility

export # svi
RawSvi, RawSviBaseConstraint, 
RawSviButterFlyConstraint, CalendarConstraint, SviCost, RawSviIntialValue, Svi,
ProjectedSviJw, ProjCalendarConstraint, ProjectedSviJwButterFlyConstraint, 
ProjectedSviJwCost, ProjectedSviJwBaseConstraint, SVI_BUMP, SsviPhi, 
QuotientSsviBase, QuotientButterfly, SsviCalendar, SsviCost, Ssvi,
jw_to_raw, ssvi_to_jw, raw_to_jw, ssvi_to_raw

export # Time.jl
Act360, Act365, BondThirty360, EuroBondThirty360, NoFrequency, Annaul, SemiAnnaul, day_count, IsdaActAct

export #currencies.jl
AbstractCurrency, NullCurrency, Currency

export # indices.jl
OvernightIndex, IborIndex, LiborIndex, fixing_date, maturity_date, fixing, forcast_fixing, euribor_index,
usd_libor_index, is_valied_fixing_date, add_fixing!, value_date, fixing, InterestRateIndex, OvernightIndex

export # cash_flows/cash_flows.jl
CouponMixin, accrual_start_date, accrual_end_date, ref_period_start, 
ref_period_end, SimpleCashFlow, Leg, ZeroCouponLeg, npv

export # cash_flows/fixed_rate_coupon.jl, # cash_flows/floating_rate_coupon.jl
FixedRateCoupon, FixedRateLeg, FloatingCoupon, FloatingLeg

export # least_square
Monomial, MonomialFunction, path_basis_system!, get_type

export # 
value, gradient

export # Instruments
PlainVanillaPayoff, ForwardTypePayoff, Put, Call, FaceValueClaim,
Range, Barrier, LowerRange, UpperRange, LowerBarrier, UpperBarrier,

FixedCouponBond, ZeroCouponBond

export #exercise.jl 
EuropeanExercise, AmericanExercise, BermudanExercise

export #pricing_engine.jl
NullPricingEngine, DiscountingBondEngine, _calculate!, dirty_price, duration

export # utils.jl
interospect_index_ratio, CentralDifference, cdf

export 
Path

function value(::JsQL.Math.CostFunction, x::Vector{Float64})
    return 0.0
end
"""
It is recommended to write a custom gradient  \n
rather than using this brute force gradient. It will be much more stable.
"""
function gradient(t::JsQL.Math.CostFunction, x::Vector{Float64}) 
    ret = zeros(Float64, length(x))
    fp = fm = 0.0
    basis = zeros(Float64, length(x))
    epsilon = JsQL.Math.FINITE_DIFFERENCES_EPSILON
    for i = 1:length(ret)
        basis[i] = epsilon
        fp = JsQL.value(t, x + basis)
        basis[i] = -epsilon
        fm = JsQL.value(t, x + basis)
        basis[i] = 0.0
        ret[i] = (fp-fm) / (2.0epsilon)
    end
    return ret
end

# Abstract Types
include("abstract_type.jl")

include("Currency/currencies.jl")
include("InterestRate.jl")
include("observer.jl")
include("lazy.jl")
include("Quote/Quote.jl")
include("TermStructures/TermStructure.jl")
include("TermStructures/Yield/yield_term_structure.jl")
include("TermStructures/curve.jl")
include("TermStructures/yield/zero_curve.jl")
include("TermStructures/Volatility/vol_term_structure.jl")
include("TermStructures/Volatility/svi.jl")
include("TermStructures/Volatility/implied_volatility.jl")
include("TermStructures/Volatility/svi_jw.jl")
include("TermStructures/Volatility/ssvi.jl")
include("TermStructures/Volatility/svi_utils.jl")
include("TermStructures/Volatility/black_vol_term_structure.jl")
# Volatility
include("Parameter/volatility.jl")
# index -----------------------------------------
include("Index/indices.jl")
include("Index/overnight_index.jl")
# Cash Flows ------------------------------------
include("CashFlow/cash_flows.jl")
include("CashFlow/fixed_rate_coupon.jl")
include("CashFlow/floating_rate_coupon.jl")
# Method ----------------------------------------
include("Method/MonteCarlo/lsm_basis_system.jl")
# Process ---------------------------------------
include("Process/black_scholes_process.jl")
include("Process/discretization.jl")
# Exercise --------------------------------------
include("exercise.jl")
# Instrument ------------------------------------
include("Instrument/claim.jl")
include("Instrument/bond.jl")
include("Instrument/Condition/barrier.jl")
include("Method/MonteCarlo/path.jl")
include("Instrument/Payoff/performer.jl")
include("Instrument/Payoff/payoff.jl")
include("Instrument/Payoff/powerspread_payoff.jl")
include("Instrument/Payoff/els_payoff.jl")
# PricingEngine ---------------------------------
include("PricingEngine/pricing_engine.jl")
include("PricingEngine/Bond/discounting_bond_engine.jl")
# utils.jl --------------------------------------
include("utils.jl")

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

 
