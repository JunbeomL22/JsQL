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

struct ForwardTypePayoff{P <: PositionType} <: AbstractPayoff
    position::P
    strike::Float64
end

