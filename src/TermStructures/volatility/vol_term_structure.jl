using Dates
# NullStructure is typically used for deterministic model
struct NullOptionVolatilityStructure <: OptionletVolatilityStructure end

struct ShiftedLognormalVolType <: VolatilityType end
struct NormalVolType <: VolatilityType end

mutable struct ConstantOptionVolatility{B <: BusinessCalendar, C <: BusinessDayConvention, DC <: DayCount} <: OptionletVolatilityStructure
    settlementDays::Int
    referenceDate::Date
    calendar::B
    bdc::C
    volatility::Float64
    dc::DC
end

function ConstantOptionVolatility(settlementDays::Int, calendar::B, bdc::C, volatility::Float64, dc::DC) where {B <: BusinessCalendar, C <: BusinessDayConvention, DC <: DayCount}
    today = settings.evaluation_date
    ref_date = advance(Dates.Day(settlementDays), calendar, today, bdc)
    ConstantOptionVolatility{B, C, DC}(settlementDays, ref_date, calendar, bdc, volatility, dc)
end


function black_variance(ovs::OptionletVolatilityStructure, option_date::Date, strike::Float64)
    v = calc_volatility(ovs, option_date, strike)
    t = time_from_reference(ovs, option_date)
    return v * v * t
end

function calc_volatility(ovs::OptionletVolatilityStructure, option_date::Date, strike::Float64)
    return volatility_impl(ovs, option_date, strike)
  end
  
volatility_impl(ovs::OptionletVolatilityStructure, option_date::Date, strike::Float64) =
                volatility_impl(ovs, time_from_reference(ovs, option_date), strike)
  
volatility_impl(const_opt_vol::ConstantOptionVolatility, ::Float64, ::Float64) = const_opt_vol.volatility

volatility_impl(::NullOptionVolatilityStructure, ::Float64, ::Float64) = 0.0

#### Local Vol

mutable struct LocalConstantVol{DC <:DayCount} <:LocalVolTermStructure
    referenceDate::Date
    settlementDays::Int
    volatility::Quote
    dc::DC
end

LocalConstantVol(refDate::Date, volatility::Float64, dc::DayCount)=LocalConstantVol(refDate, 0, Quote(volatility), dc)

function local_vol(volTS::LocalVolTermStructure, t::Float64, underlyingLevel::Float64)
    return local_vol_impl(volTS, t, underlyingLevel)
end

local_vol_impl(volTS::LocalConstantVol, t::Float64, x::Float64) = volTS.volatility.value

mutable struct LocalVolSurface{DC <:DayCount, IV <: ImpliedVolatility} <:LocalVolTermStructure
    referenceDate::Date
    settlementDays::Int
    volatility::IV 
    dc::DC
end

LocalVolSurface(refDate::Date, volatility::IV, dc::DayCount) where {IV <: ImpliedVolatility}=LocalVolSurface(refDate, 0, volatility, dc)

local_vol_impl(volTS::LocalVolSurface, t::Float64, x::Float64) = local_vol_impl(volTS.volatility, t, x)
