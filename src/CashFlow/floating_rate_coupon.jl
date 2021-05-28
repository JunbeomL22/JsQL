using JsQL.Time, JsQL.Math

mutable struct FloatingCoupon{DC <: DayCount, X <: InterestRateIndex} <: Coupon
    couponMixin::CouponMixin{DC}
    nominal::Float64
    index::X # this has YTS, and then the YTS is passed to pricer
    gearing::Float64
    spread::Float64
    isInArrears::Bool
    spanningTime::Float64 # difference between fixing_start and fixing_end
    forecastedRate::Float64
end

function FloatingCoupon(fixingDate::Date, calcStartDate::Date, 
                        calcEndDate::Date, paymentDate::Date, 
                        faceAmount::Float64, index::X,
                        isInArrears::Bool=true,
                        forecastedRate::Float64 =0.0,
                        gearing::Float64 = 1.0, 
                        spread::Float64 = 0.0) where {X <: InterestRateIndex} 
    # BoB
    accrual = year_fraction(index.dc, calcStartDate, calcEndDate)
    coupon_mixin = CouponMixin{typeof(index.dc)}(fixingDate, calcStartDate, calcEndDate, paymentDate, index.dc, accrual)
    
    _fixing_date = isInArrears ? fixing_date(index, calcEndDate) : fixing_date(index, calcStartDate)
    fixing_cal = index.fixingCalendar
    idx_fixing_days = index.fixingDays
    fixing_val_date = advance(Day(-idx_fixing_days), fixing_cal, _fixing_date, index.convention)

    if isInArrears
        fixing_end_date = maturity_date(index, fixing_val_date)
    else
        next_fixing = advance(Day(-idx_fixing_days), fixing_cal, calcEndDate, index.convention)
        fixing_end_date = advance(Day(idx_fixing_days), fixing_cal, next_fixing, index.convention)
    end

    spanning_time = year_fraction(index.dc, fixing_val_date, fixing_end_date)
    return FloatingCoupon{typeof(index.dc), X}(coupon_mixin, faceAmount, index, gearing, 
                                                spread, isInArrears, spanning_time, forecastedRate)
end

amount(coup::FloatingCoupon) = calc_rate(coup) * accrual_period(coup) * coup.nominal
accrual_period(coup::FloatingCoupon) = coup.couponMixin.accrual

get_pay_dates(coups::Vector{FC}) where {FC <: FloatingCoupon} = Date[date(coup) for coup in coups]
get_reset_dates(coups::Vector{FC}) where {FC <: FloatingCoupon} = Date[calc_start_date(coup) for coup in coups]
get_gearings(coups::Vector{FC}) where {FC <: FloatingCoupon} = Float64[coup.gearing for coup in coups]

mutable struct FloatingLeg{DC <: DayCount, X <: InterestRateIndex} <: Leg
    coupons::Vector{FloatingCoupon{DC, X}}
    redemption::Union{SimpleCashFlow, Nothing}
end

function FloatingLeg(schedule::Schedule, nominal::Float64, 
                    index::X, # this has yts
                    paymentAdj::BusinessDayConvention,
                    fixingDays::Int = index.fixingDays,
                    paymentDays::Int = 0,
                    gearings::Vector{Float64} = ones(length(schedule.dates) - 1),
                    spreads::Vector{Float64} = zeros(length(schedule.dates) - 1),
                    isInArrears::Bool = false,
                    add_redemption::Bool = true
                    ) where {X <: InterestRateIndex}
    # BoB
    n = length(schedule.dates)-1
    coups = Vector{FloatingCoupon{typeof(index.dc), X}}(undef, n)
    last_payment_date = adjust(schedule.cal, paymentAdj, schedule.dates[end])
  
    _start = ref_start = schedule.dates[1]
    _end = ref_end = schedule.dates[2]
    payment_date = adjust(schedule.cal, paymentAdj, _end+Day(paymentDays))
    fixing_date = adjust(index.fixingCalendar, index.convention, _start + Day(fixingDays))

    coups[1] = FloatingCoupon(fixing_date, _start, _end, payment_date, nominal, index, isInArrears, gearings[1], spreads[1])
    #set_calc_rate!(coups[1])              

    count = 2
    ref_start = _start = _end
    ref_end = _end = count == length(schedule.dates) ? schedule.dates[end] : schedule.dates[count + 1]
    payment_date = adjust(schedule.cal, paymentAdj, _end + Day(paymentDays))
    fixing_date  = adjust(index.fixingCalendar, index.convention, _start + Day(fixingDays))

    while _start < schedule.dates[end]
        @inbounds coups[count] = FloatingCoupon(fixing_date, _start, _end, payment_date, 
                                                nominal, index, isInArrears, gearings[count], spreads[count])
        #@inbounds set_calc_rate!(coups[count])    
        count += 1
        ref_start = _start = _end
        ref_end = _end = count == length(schedule.dates) ? schedule.dates[end] : schedule.dates[count + 1]
        payment_date = adjust(schedule.cal, paymentAdj, _end + Day(paymentDays))
        fixing_date  = adjust(index.fixingCalendar, index.convention, _start + Day(fixingDays))
    end

    if add_redemption
        redempt = SimpleCashFlow(nominal, _end)
    else
        redempt = nothing
    end
    
    FloatingLeg{typeof(index.dc), X}(coups, redempt)
end

"""
calc_rate(coup::IborCoupon) \n
gives the forecasted forward rate or the rate fixed in past given in the IborCoupon fixing date
"""
function calc_rate(coup::FloatingCoupon)
    coupMixin = coup.couponMixin
    res= fixing(coup.index, coupMixin.fixingDate, idx.yts, coupMixin.calcStartDate, coupMixin.calcEndDate, true)
    
    return res
end

function set_calc_rate!(coup::FloatingCoupon)
    coupMixin = coup.couponMixin
    res= fixing(coup.index, coupMixin.fixingDate, coup.index.yts, coupMixin.calcStartDate, coupMixin.calcEndDate, true)
    coup.forecastedRate = res
end