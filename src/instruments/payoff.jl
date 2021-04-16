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
    rangeDates::Vector{Date}
    lowerRanges::Vector{LowerRange}
    barrier::LowerBarrier
    lizardDates::Vector{Date}
    lizardBarrier::Vector{Float64}
    lowerBound::Float64
end


