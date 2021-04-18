struct Put <: OptionType end
struct Call <: OptionType end

value(::Put)  = -1
value(::Call) = 1

struct PlainVanillaPayoff{OT <: OptionType} <: StrikedTypePayoff
    optionType::OT
    strike::Float64
end

(payoff::PlainVanillaPayoff)(price::Float64) = _get_payoff(payoff, price)

_get_payoff(payoff::PlainVanillaPayoff, price::Float64)=max(value(payoff.optionType)*(price - payoff.strike), 0.0)

struct LongForward <: PositionType end
struct ShortForward <: PositionType end

value(::ShortForward)  = -1
value(::LongForward) = 1

struct ForwardTypePayoff{P <: PositionType} <: AbstractPayoff
    position::P
    strike::Float64
end

(payoff::ForwardTypePayoff)(price::Float64) = _get_payoff(payoff, price)
_get_payoff(payoff::ForwardTypePayoff, price::Float64)=value(payoff.optionType)*(price - payoff.strike)

struct ElsPayoff <: AbstractPayoff
    maturity::Date
    rangeDates::Vector{Date}
    lowerRanges::Vector{LowerRange}
    rangeCoupons::Vector{Float64}

    barrier::LowerBarrier
    barrierCoupon::Float64

    participation::Float64
    floorBound::Float64 # 80% mostly
    capBound::Float64 # 80% mostly

    lizardBarriers::Vector{LowerBarrier} # the length can't be longer than rangeDates
    lizardCoupons::Vector{Float64}

    paymentDays::Int

    barrierNotHit::Bool
    lizardNotHit::Bool
end

# if it is hit
function els_payoff(fixingDate::Date, maturity::Date, pastFixings::Dict{Date, Float64},
                    rangeDates::Vector{Date}, lowerRanges::Vector{LowerRange}, rangeCoupons::Float64,
                    barrier::LowerBarrier = LowerBarreir(Inf), barrierCoupon::Float64 = 0.0, 
                    participation::Float64 = 1.0, floorBound::Float64 = -Inf, capBound::Float64 = Inf,
                    lizardBarriers::Vector{LowerBarrier}=LowerBarrier[], 
                    lizardCoupons::Vector{Float64} = Float64[],
                    paymentDays::Int = 0;
                    evalDate::Date = settings.evaluation_date)
    
    past_values = filter(kv -> fixingDate <= kv.first <= evalDate, pastFixings) |> values
    barrierNotHit = barrier(past_values)
    # To check if lizard barrier is hit in past
    # first, check where rangeDate we are in 
    lizardNotHit = false
    i = interospect_index_ratio(evalDate, rangeDates)
    if length(lizardBarriers) <= i
        past_values = filter(kv -> fixingDate <= kv.first <= rangeDate[i], pastFixings) |> values
        isLizardHit = lizardBarriers[i](past_values)
    end
    return ElsPayoff(maturity, rangeDates, lowerRanges, rangeCoupons, 
                    barrier, barrierCoupon,
                    participation, floorBound, capBound,
                    lizardBarriers, lizardCoupons,
                    paymentDays,
                    barrierNotHit, lizardNotHit)
end

function (po::ElsPayoff)(path::Path)
    length(po.lizardBarrier) > length(po.rangeDates) || error("els payoff, lizard is longer than range")
    cash_flows = [SimpleCashFlow(0.0, Date(0))]
    # range and lizard redemption
    st = interospect_index_ratio(path.dtg.refDate, rangeDates)
    @inbounds @simd for i in st:length(po.rangeDates)
        d = po.rangeDates[i]
        pay_date = d + po.paymentDays
        rg= po.lowerRanges[i]
        if rg(path(d))
            cash_flows[0] = SimpleCashFlow(1.0 + po.rangeCoupons[i], pay_date)
            return cash_flows
        elseif length(po.lizardBarriers) <= i && po.lizardNotHit
            if po.lizardBarriers[i](path(path.refDate, d))
                cash_flows[0] = SimpleCashFlow(1.0 + po.lizardCoupons[i], pay_date)
                return cash_flows
            end
        end
    end 
    # barrier check
    pay_date = po.maturity + po.paymentDays
    if po.barrier.lower != Inf && po.barrier(path.values) && po.barrierNotHit
        cash_flows[0] = SimpleCashFlow(1.0 + po.barrierCoupon, pay_date)
        return cash_flows
    else
        amount = max(path(po.maturity) * po.participation, po.lowerBound)
        cash_flows[0] = SimpleCashFlow(amount, pay_date)
        return cash_flows
    end
end

