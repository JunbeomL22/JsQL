abstract type Observer end

abstract type LazyObject <: Observer end
# Instruments
abstract type Instrument <: LazyObject end
abstract type Swap <: Instrument end
abstract type SwapType end
abstract type Bond <: Instrument end
abstract type Results end
abstract type AbstractPayoff end
abstract type PositionType end

# TermStructure
abstract type TermStructure <: LazyObject end
abstract type YieldTermStructure <: TermStructure end
abstract type CreditTermStructure <: TermStructure end
abstract type AbstractDefaultProbabilityTermStructure <: CreditTermStructure end
abstract type VolatilityTermStructure <: TermStructure end
abstract type OptionletVolatilityStructure <: VolatilityTermStructure end
abstract type SwaptionVolatilityStructure <: VolatilityTermStructure end
abstract type VolatilityType end

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
