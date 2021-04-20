using JsQL.Time, JsQL.Math

mutable struct FloatingCoupon{DC <: DayCount, X <: InterestRateIndex, IR <: InterestRate} <: Coupon
    couponMixin::CouponMixin{DC}
    nominal::Float64
    index::X # this has YTS, and then the YTS is passed to pricer
    spread::Float64
    pastFixings::Float64 # historical if it is necessary
    forcastedRate::IR
end

function FloatingCoupon(fixingDate::Date, calcStartDate::Date, 
                        calcEndDate::Date, paymentDate::Date, 
                        faceAmount::Float64, index::X) where {DC <: DayCount, X <: InterestRateIndex} 
    # BoB
    accrual = year_fraction(index.dc, calcStartDate, calcEndDate)

    return IborCoupon{DC, X}(CouponMixin{DC}(startDate, endDate, refPeriodStart, refPeriodEnd, dc, -1.0), paymentDate, nominal, _fixing_date, fixing_val_date,
                    fixing_end_date, fixingDays, iborIndex, gearing, spread, isInArrears, spanning_time, pricer)
end

amount(coup::IborCoupon) = calc_rate(coup) * accrual_period(coup) * coup.nominal

get_pay_dates(coups::Vector{IC}) where {IC <: IborCoupon} = Date[date(coup) for coup in coups]
get_reset_dates(coups::Vector{IC}) where {IC <: IborCoupon} = Date[accrual_start_date(coup) for coup in coups]
get_gearings(coups::Vector{IC}) where {IC <: IborCoupon} = Float64[coup.gearing for coup in coups]

mutable struct IborLeg{DC <: DayCount, X <: InterestRateIndex, ICP <: IborCouponPricer} <: Leg
    coupons::Vector{IborCoupon{DC, X, ICP}}
    redemption::Union{SimpleCashFlow, Nothing}
end

function IborLeg(schedule::Schedule, nominal::Float64, 
                    iborIndex::X, # this has yts
                    paymentDC::DC, paymentAdj::BusinessDayConvention,
                    fixingDays::Vector{Int} = fill(iborIndex.fixingDays, length(schedule.dates)-1),
                    gearings::Vector{Float64} = ones(length(schedule.dates) - 1),
                    spreads::Vector{Float64} = zeros(length(schedule.dates) - 1),
                    caps::Vector{Float64} = Vector{Float64}(),
                    floors::Vector{Float64} = Vector{Float64}(),
                    isInArrears::Bool = false,
                    isZero::Bool = false,
                    pricer::ICP = BlackIborCouponPricer();
                    add_redemption::Bool = true,
                    cap_vol::OptionletVolatilityStructure = NullOptionletVolatilityStructure()
                    ) where {DC <: DayCount, X <: InterestRateIndex, ICP <: IborCouponPricer}
    # BoB
    coups = Vector{IborCoupon{DC, X, typeof(pricer)}}(undef, n)
    last_payment_date = adjust(schedule.cal, paymentAdj, schedule.dates[end])
  
    _start = ref_start = schedule.dates[1]
    _end = ref_end = schedule.dates[2]
    payment_date = adjust(schedule.cal, paymentAdj, _end)

    coups[1] = IborCoupon(payment_date, nominal, _start, _end, 
                    fixingDays[1], iborIndex, gearings[1], spreads[1], 
                    ref_start, ref_end,
                    paymentDC, isInArrears, pricer)

                    count = 2
                    ref_start = _start = _end
                    ref_end = _end = count == length(schedule.dates) ? schedule.dates[end] : schedule.dates[count + 1]
                    payment_date = adjust(schedule.cal, paymentAdj, _end)
                  
    while _start < schedule.dates[end]
        @inbounds coups[count] = IborCoupon(payment_date, nominal, _start, _end, fixingDays[count], iborIndex, gearings[count], spreads[count], ref_start, ref_end,
                            paymentDC, isInArrears, pricer)
    
        count += 1
        ref_start = _start = _end
        ref_end = _end = count == length(schedule.dates) ? schedule.dates[end] : schedule.dates[count + 1]
        payment_date = adjust(schedule.cal, paymentAdj, _end)
    end
    if add_redemption
        redempt = SimpleCashFlow(nominal, _end)
    else
        redempt = nothing
    end
    
    IborLeg{DC, X, typeof(pricer)}(coups, redempt)
end

"""
calc_rate(coup::IborCoupon) \n
gives the forcasted forward rate or the rate fixed in past given in the IborCoupon fixing date
"""
function calc_rate(coup::IborCoupon)
    initialize!(coup.pricer, coup)
    
    return swaplet_rate(coup.pricer, coup) # just the forward rate. don't know how to eloquate
end

function initialize!(pricer::BlackIborCouponPricer, coup::IborCoupon)
    idx = coup.iborIndex
    yts = idx.ts
  
    payment_date = date(coup)
    if payment_date > yts.referenceDate
        pricer.discount = discount(yts, payment_date) 
            # recall    == discount(yts, payment_date - yts.referenceDate)
        pricer.discount = 1.0
    end
  
    pricer.accrual_period = accrual_period(coup)
  
    pricer.spreadLegValue = coup.spread * pricer.accrual_period * pricer.discount
  
    return pricer
end

function swaplet_price(pricer::BlackIborCouponPricer, coup::IborCoupon)
    _swaplet_price = adjusted_fixing(pricer, coup) * pricer.accrual_period * pricer.discount
    return coup.gearing * _swaplet_price + pricer.spreadLegValue
end
  
swaplet_rate(pricer::BlackIborCouponPricer, coup::IborCoupon) = swaplet_price(pricer, coup) / (pricer.accrual_period * pricer.discount)

function adjusted_fixing(pricer::BlackIborCouponPricer, coup::IborCoupon, fixing::Float64 = -1.0)
    if fixing == -1.0
        fixing = index_fixing(coup)
    end
  
    if !coup.isInArrears
        return fixing
    end
    
    # if the vol is null, convexity adjustment is not needed
    if typeof(pricer.volatility) == NullOptionVolatilityStructure 
        return fixing
    end

    if !isdefined(pricer.volatility, :referenceDate) # sanity check for the next body (*)
        return fixing
    end
    
    ref_date = pricer.volatility.referenceDate # (*)
    d1 = coup.fixingDate

    if d1 <= ref_date
        return fixing
    end
    
    idx = coup.iborIndex
    d2 = value_date(idx, d1)
    d3 = maturity_date(idx, d2)
    tau = year_fraction(idx.dc, d2, d3)
    variance = black_variance(pricer.volatility, d1, fixing)
  
    adj = fixing * fixing * variance * tau / (1.0 + fixing * tau)

    return fixing + adj
end

function index_fixing(coupon::IborCoupon)
    today = settings.evaluation_date
  
    if coupon.fixingDate >= today
        return forecast_fixing(coupon.iborIndex, coupon.iborIndex.ts, coupon.fixingValueDate, coupon.fixingEndDate, coupon.spanningTime)
    end
  
    pastFix = get(coupon.iborIndex.pastFixings, coupon.fixingDate, -100.0)
  
    if pastFix ≈ -100.0
        println("there is no past fix in IborCoupon")
        idx = coupon.iborIndex
        return forecast_fixing(idx, idx.ts, 
                            idx.ts.referenceDate, 
                            advance(idx.tenor.period, idx.fixingCalendar, idx.ts.referenceDate), 
                            coupon.spanningTime)
    else
        return pastFix
    end
end

"""
update vol to the pricer \n
update_pricer!(leg::IborLeg, opt::OptionletVolatilityStructure)
"""
function update_pricer!(leg::IborLeg, opt::OptionletVolatilityStructure)
    for coup in leg.coupons
      # if isa(coup, IborCoupon)
      coup.pricer.capletVolatility = opt
      # end
    end
  
    return leg
end
  
get_pricer_type(leg::IborLeg{DC, X, ICP}) where {DC, X, ICP} = ICP