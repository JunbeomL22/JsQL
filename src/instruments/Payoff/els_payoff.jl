abstract type PerformanceType end
struct Worst <: PerformanceType end
struct Best <: PerformanceType end


(Worst::PerformanceType)(x::Vector{Float64}) = min(x...)

function (Worst::PerformanceType)(x::Matrix{Float64})
    col = size(x)[2]
    res = Vector{Float64}(undef, col)
    for i=1:col
        res[i] = min(x[:, i]...)
    end
    return res
end

(Best::PerformanceType)(x::Vector{Float64}) = max(x...)

function (Best::PerformanceType)(x::Matrix{Float64})
    col = size(x)[2]
    res = Vector{Float64}(undef, col)
    for i=1:col
        res[i] = max(x[:, i]...)
    end
    return res
end

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

    performaceType::PerformanceType
end

# if it is hit
function ElsPayoff(fixingDate::Date, maturity::Date, pastFixings::Dict{Date, Vector{Float64}},
                    rangeDates::Vector{Date}, lowerRanges::Vector{LowerRange}, rangeCoupons::Float64,
                    barrier::LowerBarrier = LowerBarreir(Inf), barrierCoupon::Float64 = 0.0, 
                    participation::Float64 = 1.0, floorBound::Float64 = -Inf, capBound::Float64 = Inf,
                    lizardBarriers::Vector{LowerBarrier}=LowerBarrier[], 
                    lizardCoupons::Vector{Float64} = Float64[],
                    paymentDays::Int = 0;
                    evalDate::Date = settings.evaluation_date,
                    performanceType::PerformanceType = Worst)
    #BoB
    perf = performanceType
    past_values = filter(kv -> fixingDate <= kv.first <= evalDate, pastFixings) |> values
    barrierNotHit = barrier(perf(past_values))
    # To check if lizard barrier is hit in past
    # first, check where rangeDate we are in 
    lizardNotHit = false
    i = interospect_index_ratio(evalDate, rangeDates)
    if length(lizardBarriers) <= i
        past_values = filter(kv -> fixingDate <= kv.first <= rangeDate[i], pastFixings) |> values
        isLizardHit = lizardBarriers[i](perf(past_values))
    end
    return ElsPayoff(maturity, rangeDates, lowerRanges, rangeCoupons, 
                    barrier, barrierCoupon,
                    participation, floorBound, capBound,
                    lizardBarriers, lizardCoupons,
                    paymentDays,
                    barrierNotHit, lizardNotHit, 
                    performanceType)
end

function (po::ElsPayoff)(path::Path)
    length(po.lizardBarrier) > length(po.rangeDates) || error("els payoff, lizard is longer than the redemption range")
    cash_flows = [SimpleCashFlow(0.0, Date(0))]
    # range and lizard redemption
    st = interospect_index_ratio(path.dtg.refDate, rangeDates)
    perf = po.performaceType
    @inbounds @simd for i in st:length(po.rangeDates)
        d = po.rangeDates[i]
        pay_date = d + po.paymentDays
        rg= po.lowerRanges[i]
        if rg(perf(path(d)))
            cash_flows[0] = SimpleCashFlow(1.0 + po.rangeCoupons[i], pay_date)
            return cash_flows
        elseif length(po.lizardBarriers) <= i && po.lizardNotHit
            if po.lizardBarriers[i](perf(path(path.refDate, d)))
                cash_flows[0] = SimpleCashFlow(1.0 + po.lizardCoupons[i], pay_date)
                return cash_flows
            end
        end
    end 
    # barrier check
    pay_date = po.maturity + po.paymentDays
    if po.barrier.lower != Inf && po.barrier(perf(path.values)) && po.barrierNotHit
        cash_flows[0] = SimpleCashFlow(1.0 + po.barrierCoupon, pay_date)
        return cash_flows
    else
        amount = max(perf(path(po.maturity)) * po.participation, po.lowerBound)
        cash_flows[0] = SimpleCashFlow(amount, pay_date)
        return cash_flows
    end
end
