using Dates

mutable struct DividendSchedule
    dividends::Vector{Dividend}
end

struct BondMixin
    fixingDays::Int
    paymentDays::Int # coupons
    issueDate::Date
    maturity::Date
end

get_payment_date(bond::Bond) = bond.bondMixin.paymentDays

mutable struct BondResults 
    dirtyPrice::Float64
    cleanPrice::Float64
    dv01::Float64
    duration::Float64
    modifiedDuration::Float64
    theta::Float64
    realizedPL::Float64
    tenors::Vector{Period}
    delta::Vector{Float64}
    gamma::Vector{Float64}
end

function BondResults()
    return BondResults(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Period[], Float64[], Float64[])    
end

mutable struct FixedCouponBond{DC <: DayCount, P <: PricingEngine, C <:CompoundingType, F <: Frequency, IR <: InterestRate} <: Bond
    lazyMixin::LazyMixin
    bondMixin::BondMixin
    
    faceAmount::Float64
    schedule::Schedule
    cashflows::FixedRateLeg{FixedRateCoupon{DC, InterestRate{DC, C, F}}}
    dc::DC

    ytm::IR
    pricingEngine::P
    results::BondResults
end

function FixedCouponBond(paymentDays::Int, faceAmount::Float64,
                        issueDate::Date, maturity::Date, calendar::C, 
                        couponFreq::Frequency, 
                        coup_rate::Float64, dc::DC, 
                        couponGenerationRule::DateGenerationRule = DateGenerationForwards(), 
                        couponConvention::B = Unadjusted(),
                        paymentConvention::B = Following(),
                        pricingEngine::P = DiscountingBondEngine(),
                        add_redemption::Bool=true,
                        ytm::Float64 = -Inf) where {DC <: DayCount, B <: BusinessDayConvention,
                                                    C <: BusinessCalendar, P <: PricingEngine}
    # BoB
    tp = TenorPeriod(couponFreq)

    schedule = Schedule(issueDate, maturity, tp, couponConvention, couponGenerationRule)

    coups = FixedRateLeg(schedule, faceAmount, coup_rate, calendar, 
                        0, paymentDays, couponConvention, paymentConvention,
                        dc; add_redemption=add_redemption)

    ytm_ir = InterestRate(ytm)
    return FixedCouponBond{DC, P, SimpleCompounding, typeof(schedule.tenor.freq), typeof(ytm_ir)}(LazyMixin(), 
                                                                                                BondMixin(0, paymentDays, issueDate, maturity),
                                                                                                faceAmount,
                                                                                                schedule,
                                                                                                coups,
                                                                                                dc,
                                                                                                ytm_ir,
                                                                                                pricingEngine,
                                                                                                BondResults())
end

function FixedCouponBond(paymentDays::Int, 
                        faceAmount::Float64, schedule::Schedule,
                        coup_rate::Float64, dc::DC, paymentConvention::B,
                        issueDate::Date, calendar::C, pricingEngine::P,
                        ytm::Float64 = -Inf) where {DC <: DayCount, B <: BusinessDayConvention,
                                                    C <: BusinessCalendar, P <: PricingEngine}
    maturity = schedule.dates[end]
    coups = FixedRateLeg(schedule, faceAmount, coup_rate, calendar, 
                        0, paymentDays, Unadjusted(), paymentConvention,
                        dc; add_redemption=true)
    ytm_ir = InterestRate(ytm)

    return FixedCouponBond{DC, P, SimpleCompounding, typeof(schedule.tenor.freq), typeof(ytm_ir)}(LazyMixin(), 
                                                                                                BondMixin(0, paymentDays, issueDate, maturity),
                                                                                                faceAmount,
                                                                                                schedule,
                                                                                                coups,
                                                                                                dc,
                                                                                                ytm_ir,
                                                                                                pricingEngine,
                                                                                                BondResults())
end
                                                                    
mutable struct ZeroCouponBond{BC <: BusinessCalendar, P <: PricingEngine, IR <: InterestRate} <: Bond
    lazyMixin::LazyMixin
    bondMixin::BondMixin
    faceAmount::Float64
    paymentDate::Date
    calendar::BC
    ytm::IR
    pricingEngine::P
    results::BondResults
end

function ZeroCouponBond(paymentDays::Int, calendar::B,
                        faceAmount::Float64, maturity::Date, paymentConvention::C = Following(),
                        issueDate::Date = Date(0),
                        ytm::Float64 = -Inf, 
                        pe::P = DiscountBondEngine()) where {B <: BusinessCalendar, C <: BusinessDayConvention, P <: PricingEngine}
    #BoB
    cf = ZeroCouponLeg(SimpleCashFlow(faceAmount, maturity))
    paymentDate = adjust(calendar, maturity, paymentConvention)
    ytm_ir = InterestRate(ytm)
    return ZeroCouponBond{B, P}(LazyMixin(), BondMixin(0, paymentDays, issueDate, maturity),
                                faceAmount, paymentDate, calendar, ytm_ir, pe, BondResults())
end

get_maturity(b::Bond) = b.bondMixin.maturity
get_frequency(b::Bond) = b.schedule.tenor.freq

function notional(bond::Bond, d::Date)
    if d > get_maturity(bond)  
        return 0.0
    else
        return bond.faceAmount
    end
end

accrued_amount(bond::Bond, settlement::Date) = accrued_amount(bond.cashflows, settlement)
get_redemption(b::Bond) = b.cashflows.redemption == nothing ? b.cashflows.coupons[end] : b.cashflows.redemption

