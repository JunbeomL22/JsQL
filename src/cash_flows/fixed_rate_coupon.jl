using JsQL.Time

mutable struct FixedRateCoupon{DC<: DayCount, IR <: InterestRate} <: Coupon
    couponMixin::CouponMixin{DC}
    nominal::Float64
    rate::IR # Recall that this includes compounding type
end

FixedRateCoupon(fixingDate::Date, calcStartDate::Date, calcEndDate::Date, paymentDate::Date, 
                faceAmount::Float64, rate::IR, dc::DC) where {
                DC <: DayCount, IR <: InterestRate} = 
    #BoB 
    FixedRateCoupon{DC, IR}(CouponMixin{DC}(fixingDate, calcStartDate, calcEndDate, paymentDate,dc),
                                            faceAmount, rate)

function amount(coup::FixedRateCoupon)
    return coup.nominal * (compound_factor(coup.rate, coup.couponMixin.calcStartDate, coup.couponMixin.calcEndDate) - 1.0)
end

calc_rate(coup::FixedRateCoupon) = coup.rate.rate

mutable struct FixedRateLeg{FRC <: FixedRateCoupon} <: Leg
    coupons::Vector{FRC} ## from eval_date
    redemption::Union{SimpleCashFlow, Nothing}
end

function FixedRateLeg(schedule::Schedule, faceAmount::Float64, rate::Float64, 
                    calendar::BusinessCalendar, 
                    fixingDays::Int, paymentDays::Int,
                    fixingConvention::BusinessDayConvention, paymentConvention::BusinessDayConvention,
                    dc::DayCount; add_redemption::Bool = true)
    # BoB
    ratesLen = length(schedule.dates) - 1  # This removes the effective date
    ratesVec = fill(rate, ratesLen)
    # the following is defined below
    return FixedRateLeg(schedule, faceAmount, ratesVec, 
                        calendar, fixingDays, paymentDays, 
                        fixingConvention, paymentConvention, 
                        dc; add_redemption = add_redemption)
end

function FixedRateLeg(schedule::Schedule, faceAmount::Float64, rates::Vector{Float64}, 
                        calendar::BusinessCalendar, 
                        fixingDays::Int, paymentDays::Int,
                        fixingConvention::BusinessDayConvention, paymentConvention::BusinessDayConvention,
                        dc::DayCount; add_redemption::Bool = true) where {DC <:DayCount}
    n = length(schedule.dates) - 1
    length(rates) == length(schedule.dates) -1 || error("mismatch in coupon rates, constructor of FixedRateLeg")

    coup_type = FixedRateCoupon{DC, InterestRate{DC, SimpleCompounding, typeof(schedule.tenor.freq)}}
    coups = Vector{coup_type}(undef, n)

    start_date  = schedule.dates[1] # to be moved in generating coupons
    end_date    = schedule.dates[2]
    payment_date= adjust(calendar, paymentConvention, end_date + Day(paymentDays))
    fixing_date= adjust(calendar, fixingConvention, end_date - Day(fixingDays))

    coups[1] = FixedRateCoupon(fixing_date, start_date, end_date, payment_date,
                                faceAmount,InterestRate(rates[1], dc, SimpleCompounding(), schedule.tenor.freq),
                                dc)
    count = 2
    start_date = end_date
    end_date = count == length(schedule.dates) ? schedule.dates[end] : schedule.dates[count + 1]
    fixing_date = adjust(calendar, paymentConvention, end_date - Day(fixingDays))
    payment_date = adjust(calendar, paymentConvention, end_date + Day(paymentDays))

    while start_date < schedule.dates[end]
        @inbounds coups[count] = FixedRateCoupon(fixing_date, start_date, end_date, payment_date,
                                                faceAmount,InterestRate(rates[1], dc, SimpleCompounding(), schedule.tenor.freq),
                                                dc)
        count += 1
        start_date = end_date
        end_date = count == length(schedule.dates) ? schedule.dates[end] : schedule.dates[count + 1]
        fixing_date = adjust(calendar, paymentConvention, end_date - Day(fixingDays))
        payment_date = adjust(calendar, paymentConvention, end_date + Day(paymentDays))
    end

    if add_redemption
        redempt = SimpleCashFlow(faceAmount, end_date)
    else
        redempt = nothing
    end
    
    return FixedRateLeg{coup_type}(coups, redempt)
end

get_pay_dates(coups::Vector{F}) where {F <: FixedRateCoupon} = Date[date(coup) for coup in coups]
get_calc_start_date(coups::Vector{F}) where {F <: FixedRateCoupon} = Date[calc_start_date(coup) for coup in coups]

function accrued_amount(coup::FixedRateCoupon, settlement_date::Date)
    if settlement_date <= calc_start_date(coup) || settlement_date > coup.paymentDate
        return 0.0
    end
  
    return coup.nominal *
        (compound_factor(coup.rate, 
                        calc_start_date(coup), 
                        min(settlement_date, calc_end_date(coup))) 
                            - 1.0)
end