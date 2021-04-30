using JsQL.Time, JsQL.Math
"""
Coupon (<: CashFlow, both are abstract) has CouponMixin \n
CashFlow >: Coupon >: FixedRateCoupon
"""
mutable struct CouponMixin{DC <: DayCount}
    fixingDate::Date
    calcStartDate::Date # being used to refer to the reset dates, take your leeway otherwise
    calcEndDate::Date
    paymentDate::Date
    dc::DC
    accrual::Float64 # period
end

function CouponMixin(fixingDate::Date, calcStartDate::Date, calcEndDate::Date, 
                    paymentDate::Date, dc::DC) where {DC <: DayCount}
    accrual = year_fraction(dc, calcStartDate, calcEndDate + Day(1))
    return CouponMixin{DC}(fixingDate, calcStartDate, calcEndDate, paymentDate, dc, accrual)
end

fixing_date(coup::Coupon) = coup.couponMixin.fixingDate
calc_start_date(coup::Coupon) = coup.couponMixin.calcStartDate
calc_end_date(coup::Coupon) = coup.couponMixin.calcEndDate
date(coup::Coupon) = coup.couponMixin.paymentDate
payment_date(coup::Coupon) = coup.couponMixin.paymentDate
get_dc(coup::Coupon) = coup.couponMixin.dc
accrual(coup::Coupon) = coup.couponMixin.accrual

struct SimpleCashFlow <: CashFlow
    amount::Float64
    date::Date
end

struct Dividend <: CashFlow
    amount::Float64
    date::Date
end

amount(cf::SimpleCashFlow) = cf.amount
date(cf::SimpleCashFlow) = cf.date
amount(div::Dividend) = div.amount
date(div::Dividend) = div.date

# legs to build cash flows
"""
CashFlows >: Leg >: ZeroCouponLeg
"""
struct ZeroCouponLeg <: Leg
  redemption::SimpleCashFlow # this includes notional payment  at maturity as well.
end

""" to be implemented """
mutable struct IRRFinder 
    # to be implemented
end

get_payment_dates(coups::Vector{C}) where {C <: Coupon} = Date[payment_date(coup) for coup in coups]
get_fixing_dates(coups::Vector{C}) where {C <: Coupon} = Date[fixing_date(coup) for coup in coups]

## NPV Method ##
function _npv_reduce(coup::Coupon, yts::YieldTermStructure, npv_date::Date)
    if has_occurred(coup, npv_date)
        return 0.0
    end
    return amount(coup) * discount(yts, date(coup))
end

function npv(leg::Leg, yts::YieldTermStructure, npv_date::Date)
    totalNPV = mapreduce(x -> _npv_reduce(x, yts, npv_date), +, leg, init=0.0)
    
    if leg.redemption != nothing
        totalNPV += amount(leg.redemption) * discount(yts, npv_date, date(leg.redemption))
    end
    return totalNPV 
end

# basically in npv, cash_flow in calcDate is  considered
# clean npv should also be provided
function has_occurred(cf::CashFlow, ref_date::Date, include_settlement::Bool = true)
    # will need to expand this
    if ref_date < date(cf) || (ref_date == date(cf) && include_settlement)
        return false
    else
        return true
    end
end

function accrued_amount(leg::L, settlement::Date) where {L <: Leg}
    idx = 1
    while settlement > leg.coupons[idx].couponMixin.paymentDate
        idx += 1
    end
    return accrued_amount(leg.coupons[idx], settlement)
end 

function accrued_amount(coup::Coupon, settlement_date::Date)
    if settlement_date <= calc_start_date(coup) || settlement_date > coup.paymentDate
        return 0.0
    end
  
    return coup.nominal *
        (compound_factor(coup.rate, 
                        calc_start_date(coup), 
                        min(settlement_date, calc_end_date(coup))) 
                            - 1.0)
end

function duration(coup::Coupon, yts::YieldTermStructure, npv_date::Date)
    if has_occurred(coup, npv_date)
        return 0.0
    end
    t = year_fraction(coup.couponMixin.dc, npv_date, coup.couponMixin.paymentDate)
    return amount(coup) * discount(yts, payment_date(coup)) * t
end

function duration(leg::Leg, yts::YieldTermStructure, npv_date::Date)
    _duration = mapreduce(x -> duration(x, yts, npv_date), +, leg, init=0.0)
    
    if leg.redemption != nothing
        t = year_fraction(npv_date, leg.redemption.date)
        _duration += amount(leg.redemption) * discount(yts, date(leg.redemption)) * t
    end
    return _duration
end


function Base.iterate(f::Leg, state=1)
    if length(f.coupons) == state - 1
        return nothing
    end
  
    return f.coupons[state], state + 1
  end
  
  Base.getindex(f::Leg, i::Int) = f.coupons[i]
  Base.lastindex(f::Leg) = lastindex(f.coupons)