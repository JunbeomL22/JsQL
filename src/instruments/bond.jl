using Dates

mutable struct DividendSchedule
    dividends::Vector{Dividend}
end

struct BondMixin
    fixingDays::Int
    settlementDays::Int
    issueDate::Date
    maturity::Date
end

get_settlement_date(bond::Bond) = bond.bondMixin.settlementDays

mutable struct BondResults 
    dirtyPrice::Float64
    cleanPrice::Float64
    dv01::Float64
    duration::Float64
    modifiedDuration::Float64
    tenors::Vector{Period}
    delta::Vector{Float64}
    gamma::Vector{Float64}
end

function BondResults()
    return BondResults(0.0, 0.0, 0.0, 0.0, 0.0, Period[], Float64[], Float64[])    
end

mutable struct FixedRateBond{DC <: DayCount, P <: PricingEngine, C <:CompoundingType, F <: Frequency} <: Bond
    lazyMixin::LazyMixin
    bondMixin::BondMixin
    faceAmount::Float64
    schedule::Schedule
    cashflows::FixedRateLeg{FixedRateCoupon{DC, InterestRate{DC, C, F}}}
    dc::DC

    ytm::Float64
    pricingEngine::P
    results::BondResults
end

function FixedRateBond(settlementDays::Int, 
                        faceAmount::Float64, schedule::Schedule,
                        coup_rate::Float64, dc::DC, paymentConvention::B,
                        issueDate::Date, calendar::C, pricingEngine::P,
                        ytm::Float64 = -Inf) where {DC <: DayCount, B <: BusinessDayConvention,
                                                    C <: BusinessCalendar, P <: PricingEngine}
    maturity = schedule.dates[end]
    coups = FixedRateLeg(schedule, faceAmount, coup_rate, calendar, 
                        0, settlementDays, Unadjusted(), paymentConvention,
                        dc; add_redemption=true)
    return FixedRateBond{DC, P, SimpleCompounding, typeof(schedule.tenor.freq)}(LazyMixin(), 
                                                                                BondMixin(0, settlementDays, issueDate, maturity),
                                                                                faceAmount,
                                                                                schedule,
                                                                                coups,
                                                                                dc,
                                                                                ytm,
                                                                                pricingEngine,
                                                                                BondResults())
end
                                                                    
mutable struct ZeroCouponBond{BC <: BusinessCalendar, P <: PricingEngine} <: Bond
    lazyMixin::LazyMixin
    bondMixin::BondMixin
    faceAmount::Float64
    calendar::BC
    ytm::Float64
    pricingEngine::P
    results::BondResults
end

function ZeroCouponBond(settlementDays::Int, calendar::B,
                        faceAmount::Float64, maturity::Date, paymentConvention::C = Following(),
                        issueDate::Date = Date(0),
                        ytm::Float64 = -Inf, 
                        pe::P = DiscountBondEngine()) where {B <: BusinessCalendar, C <: BusinessDayConvention, P <: PricingEngine}
    #BoB
    cf = ZeroCouponLeg(SimpleCashFlow(faceAmount, maturity))
    return ZeroCouponBond{B, P}(LazyMixin(), BondMixin(0, settlementDays, issueDate, maturity),
                                faceAmount, calendar, ytm, pe, BondResults())
end


