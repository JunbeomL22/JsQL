struct Payer <: SwapType end
struct Receiver <: SwapType end

mutable struct SwapResults <: Results
    legNPV::vector{Float64}
    value::Float64
    discountCurveDelta::Float64
    forwardCurveDelta::Float64
    fxDelta::Float64
end

SwapResults() = SwapResults([0.0, 0.0], 0.0, 0.0, 0.0, 0.0)

function reset!(sr::SwapResults)
    n = length(sr.legNPV)
    sr.legNPV = zeros(n)
    sr.value = 0.0
    sr.discountCurveDelta=0.0
    sr.forwardCurveDelta=0.0
    sr.fxDelta=0.0
  
    return sr
end
mutable struct VanillaSwapArgs
    fixedResetDates::Vector{Date}
    fixedPayDates::Vector{Date}
    floatingResetDates::Vector{Date}
    floatingPayDates::Vector{Date}
    floatingAccrualTimes::Vector{Float64}
    floatingSpreads::Vector{Float64}
    fixedCoupons::Vector{Float64}
    floatingCoupons::Vector{Float64}
end

function VanillaSwapArgs(legs::Vector{L}) where {L <: Leg}
    fixedCoups = legs[1].coupons
    floatingCoups = legs[2].coupons
    fixedCoupons = [amount(coup) for coup in fixedCoups]
    # floatingCoupons = [amount(coup) for coup in floatingCoups]
    floatingCoupons = zeros(length(floatingCoups))
    floatingAccrualTimes = [accrual_period(coup) for coup in floatingCoups]
    floatingSpreads = [coup.spread for coup in floatingCoups]
    return VanillaSwapArgs(get_reset_dates(fixedCoups), get_pay_dates(fixedCoups), get_reset_dates(floatingCoups), get_pay_dates(floatingCoups), floatingAccrualTimes, floatingSpreads, fixedCoupons, floatingCoupons)
end

mutable struct VanillaSwap{ST <: SwapType, DC_fix <: DayCount, DC_float <: DayCount, B <: BusinessDayConvention, L <: Leg, P <: PricingEngine, X <: InterestRateIndex} <: Swap
    lazyMixin::LazyMixin
    swapT::ST
    nominal::Float64
    fixedSchedule::Schedule
    fixedRate::Float64
    fixedDayCount::DC_fix
    index::X
    spread::Float64
    floatSchedule::Schedule
    floatDayCount::DC_float
    paymentConvention::B
    legs::Vector{L}
    payer::Vector{Float64}
    pricingEngine::P
    results::SwapResults
    args::VanillaSwapArgs
end

# Constructors
function VanillaSwap(swapT::ST,
                    nominal::Float64,
                    fixedSchedule::Schedule,
                    fixedRate::Float64,
                    fixedDayCount::DC_fix,
                    index::X,
                    spread::Float64,
                    floatSchedule::Schedule,
                    floatDayCount::DC_float,
                    pricingEngine::P = NullPricingEngine(),
                    paymentConvention::B = floatSchedule.convention,
                    fixedPaymentDays::Int=0,
                    floatingPaymentDays::Int=0,) where {ST <: SwapType, DC_fix <: DayCount, DC_float <: DayCount, B <: BusinessDayConvention, P <: PricingEngine, X <: IborIndex}
    # build swap cashflows
    legs = Vector{Leg}(undef, 2)
    # first leg is fixed
    legs[1] = FixedRateLeg(fixedSchedule, nominal, fixedRate, fixedSchedule.cal, 
                            fixedPaymentDays, floatingPaymentDays, Unadjusted(), 
                            paymentConvention, fixedDayCount; add_redemption=false)
    # second leg is floating
    legs[2] = FloatingLeg(floatSchedule, nominal, index, 
                            paymentConvention, index.fixingDays, floatingPaymentDays,
                            fill(1.0, length(schedule.dates)-1),
                            fill(spread, length(schedule.dates)-1); 
                            add_redemption=false)

    payer = _build_payer(swapT)

    results = SwapResults()

    return VanillaSwap{ST, DC_fix, DC_float, B, Leg, P, X}(LazyMixin(), swapT, nominal, 
                                                            fixedSchedule, fixedRate, fixedDayCount, 
                                                            index, spread, floatSchedule, floatDayCount, 
                                                            paymentConvention, legs, payer, 
                                                            pricingEngine, results, VanillaSwapArgs(legs))
end

get_fixed_reset_dates(swap::VanillaSwap) = swap.args.fixedResetDates
get_fixed_pay_dates(swap::VanillaSwap) = swap.args.fixedPayDates
get_floating_reset_dates(swap::VanillaSwap) = swap.args.floatingResetDates
get_floating_pay_dates(swap::VanillaSwap) = swap.args.floatingPayDates
get_floating_accrual_times(swap::VanillaSwap) = swap.args.floatingAccrualTimes
get_floating_spreads(swap::VanillaSwap) = swap.args.floatingSpreads
get_fixed_coupons(swap::VanillaSwap) = swap.args.fixedCoupons
get_floating_coupons(swap::VanillaSwap) = swap.args.floatingCoupons

_build_payer(::Receiver) = [1.0, -1.0]
_build_payer(::Payer)    = [-1.0, 1.0]    

get_pricing_engine_type(::VanillaSwap{ST, DC_fix, DC_float, B, L, P, II}) where {ST, DC_fix, DC_float, B, L, P, II} = P


#=
function update_ts_idx!(swap::VanillaSwap, ts::TermStructure)
    typeof(ts) == typeof(swap.iborIndex.ts) || error("Term Structure mismatch for swap between ts and index ts")
    newIborIdx = clone(swap.iborIndex, ts)
    swap.iborIndex = newIborIdx

    # update legs
    for coup in swap.legs[2].coupons
        coup.iborIndex = newIborIdx
    end

    swap.lazyMixin.calculated = false

    return swap
end

function update_ts_pe!(swap::VanillaSwap, ts::TermStructure)
    typeof(ts) == typeof(swap.pricingEngine.yts) || error("Term Structure mismatch for swap between ts and pric engine ts")
    newpe = clone(swap.pricingEngine, ts)
    swap.pricingEngine = newpe

    swap.lazyMixin.calculated = false

    return swap
end

function update_all_ts!(swap::VanillaSwap, ts::TermStructure)
    # this will update the ts of the pricing engine and ibor index
    update_ts_idx!(swap, ts)
    update_ts_pe!(swap, ts)

    return swap
end
=#