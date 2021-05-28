abstract type Observer end

abstract type LazyObject <: Observer end
# Instruments
abstract type Instrument <: LazyObject end
abstract type Swap <: Instrument end
abstract type SwapType end
abstract type Bond <: Instrument end

abstract type AbstractClaim end

abstract type AbstractPayoff end
abstract type StrikedTypePayoff <: AbstractPayoff end
abstract type Option{E} <: Instrument end
abstract type OneAssetOption{E} <: Option{E} end
abstract type OptionType end
abstract type PositionType end
abstract type CallType end
abstract type CDSProtectionSide end
abstract type Results end
# TermStructure
abstract type TermStructure <: LazyObject end
abstract type YieldTermStructure <: TermStructure end
abstract type CreditTermStructure <: TermStructure end
abstract type AbstractDefaultProbabilityTermStructure <: CreditTermStructure end
abstract type VolatilityTermStructure <: TermStructure end
abstract type OptionletVolatilityStructure <: VolatilityTermStructure end
abstract type SwaptionVolatilityStructure <: VolatilityTermStructure end
abstract type VolatilityType end
abstract type BlackVolTermStructure <: VolatilityTermStructure end
abstract type LocalVolTermStructure <: VolatilityTermStructure end
# Curves
abstract type Curve <: YieldTermStructure end
abstract type InterpolatedCurve{P} <: Curve end
#Cash-Flows
abstract type CashFlows end
abstract type Leg <: CashFlows end
abstract type CashFlow end
abstract type Coupon <: CashFlow end
abstract type Duration end
#Indeces
abstract type InterestRateIndex end
# Currencies
abstract type AbstractCurrency end
# Compounding Type
abstract type CompoundingType end
# cash_flows.jl/floating_rate_coupon.jl
abstract type IborCouponPricer end    

# Monte Carlo
abstract type AbstractMonteCarloModel end
abstract type AbstractPathPricer end
abstract type EarlyExercisePathPricer <: AbstractPathPricer end
abstract type LsmBasisSystemPolynomType end
abstract type LsmBasisSystemFunction <: Function end
# Process
abstract type StochasticProcess end
abstract type StochasticProcess1D <: StochasticProcess end
abstract type AbstractBlackScholesProcess <: StochasticProcess1D end
abstract type BlackScholesType end
abstract type AbstractDiscretization end
# Exercise
abstract type Exercise end
abstract type EarlyExercise <: Exercise end
# Pricing Engine
abstract type PricingEngine end
# Implied Volatility
abstract type ImpliedVolatility end
# Random Number GeneralBlackScholesType
abstract type AbstractRandomSequenceGenerator end

abstract type Parameter end
abstract type Volatility <: Parameter end