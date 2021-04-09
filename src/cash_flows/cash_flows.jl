using JsQL.Time, JsQL.Math
"""
Coupon (<: CashFlow, both are abstract) has CouponMixin \n
CashFlow >: Coupon >: FixedRateCoupon
"""
mutable struct CouponMixin{DC <: DayCount}
    accrualStartDate::Date
    accrualEndDate::Date
    refPeriodStart::Date # being used to refer to the reset dates, take your leeway otherwise
    refPeriodEnd::Date
    dc::DC
    accrualPeriod::Float64 # what is it
end

accrual_start_date(coup::Coupon) = coup.couponMixin.accrualStartDate
accrual_end_date(coup::Coupon) = coup.couponMixin.accrualEndDate
ref_period_start(coup::Coupon) = coup.couponMixin.refPeriodStart
ref_period_end(coup::Coupon) = coup.couponMixin.refPeriodEnd
get_dc(coup::Coupon) = coup.couponMixin.dc

accrual_period!(coup::Coupon, val::Float64) = coup.CouponMixin.accrualPeriod = val

function accrual_period(coup::Coupon)
    if coup.couponMixin.accrualPeriod == -1.0
        p = year_fraction(get_dc(coup), accrual_start_date(coup), accrual_end_date(coup))
        accrual_period!(coup, p)
    end

    return coup.couponMixin.accrualPeriod
end

struct SimpleCashFlow <: CashFlow
    amount::Float64
    date::Date
end
amount(cf::SimpleCashFlow) = cf.amount
date(cf::SimpleCashFlow) = cf.date
date_accrual_end(cf::SimpleCashFlow) = cf.date

date(coup::Coupon) = coup.paymentDate
date_accrual_end(coup::Coupon) = accrual_end_date(coup::Coupon)

struct Dividend <: CashFlow
    amount::Float64
    date::Date
end

amount(div::Dividend) = div.amount
date(div::Dividend) = div.date
date_accrual_end(div::Dividend) = div.date

# legs to build cash flows
"""
CashFlows >: Leg >: ZeroCouponLeg
"""
struct ZeroCouponLeg <: Leg
  redemption::SimpleCashFlow
end
""" to be implemented """
mutable struct IRRFinder 
    # to be implemented
end

get_latest_coupon(leg::Leg) = get_latest_coupon(leg, leg.coupons[end])
get_latest_coupon(leg::Leg, simp::SimpleCashFlow) = leg.coupons[end - 1]
get_latest_coupon(leg::Leg, coup::Coupon) = coup

check_coupon(x::CashFlow) = isa(x, Coupon)

get_pay_dates(coups::Vector{C}) where {C <: Coupon} = Date[date(coup) for coup in coups]

get_reset_dates(coups::Vector{C}) where {C <: Coupon} = Date[accrual_start_date(coup) for coup in coups]

## NPV Method ##
function _npv_reduce(coup::Coupon, yts::YieldTermStructure, settlement_date::Date)
    if has_occurred has_occurred(coup, settlement_date)
        return 0.0
    end
    return amount(coup) * discount(yts, date(coup))
end
function has_occurred(cf::CashFlow, ref_date::Date, include_settlement_cf::Bool = true)
    # will need to expand this
    if ref_date < date(cf) || (ref_date == date(cf) && include_settlement_cf)
        return false
    else
        return true
    end
end
