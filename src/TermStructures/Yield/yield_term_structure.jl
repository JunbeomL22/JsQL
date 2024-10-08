using Dates

struct NullYieldTermStructure <: YieldTermStructure end

struct JumpDate
  ts_quote::Quote
  ts_date::Date
end

struct JumpTime
  ts_quote::Quote
  ts_time::Float
end

discount(yts::NullYieldTermStructure, ::Date) = 1.0
discount(yts::NullYieldTermStructure, ::Float) = 1.0

discount(yts::YieldTermStructure, date::Date) = discount(yts, time_from_reference(yts, date))

discount(yts::YieldTermStructure, d1::Date, d2::Date) = discount(yts, time_from_reference(yts, d2)) / discount(yts, time_from_reference(yts, d1))

function discount(yts::YieldTermStructure, time_frac::Float)
  disc = discount_impl(yts, time_frac)
  if isdefined(yts, :jumpTimes)
    if length(yts.jumpTimes) == 0
      return disc
    end

    jump_effect = 1.0
    for jump in yts.jumpTimes
      if jump.ts_time > 0.0 && jump.ts_time < time
        if jump.ts_quote.value > 0.0 && jump.ts_quote.value <= 1.0
          jump_effect *= jump.ts_quote.value
        end
      end
    end

    return jump_effect * disc
  else
    return disc
  end
end

function zero_rate(yts::YieldTermStructure, date::Date, dc::DayCount, comp::CompoundingType=ContinuousCompounding(), freq::Frequency = Annual())
  if date == yts.referenceDate
      return implied_rate(1.0 / discount(yts, 0.0001), dc, comp, 0.0001, freq)
  else
      return implied_rate(1.0 / discount(yts, date), dc, comp, reference_date(yts), date, freq)
  end
end

function zero_rate(yts::YieldTermStructure, time_frac::Float, comp::CompoundingType = ContinuousCompounding(), freq::Frequency = Annual())
  t = time_frac == 0.0 ? 0.0001 : time_frac
  return implied_rate(1.0 / discount(yts, t), yts.dc, comp, t, freq)
end

function forward_rate(yts::YieldTermStructure, date1::Date, date2::Date, dc::DayCount, comp::CompoundingType = SimpleCompounding(), freq::Frequency = Annual())
  if date1 == date2
    t1 = max(time_from_reference(yts, date1) - 0.0001 / 2.0, 0.0)
    t2 = t1 + 0.0001
    return implied_rate(discount(yts, t1) / discount(yts, d2), dc, comp, 0.0001, freq)
  elseif date1 < date2
    return implied_rate(discount(yts, date1) / discount(yts, date2), dc, comp, date1, date2, freq)
  else
    error("Forward start date must be before forward end date")
  end
end

forward_rate(yts::YieldTermStructure, date::Date, period::Integer, dc::DayCount, comp::CompoundingType = SimpleCompounding(), freq::Frequency = Annual()) = forward_rate(yts, date, date + Dates.Day(period), dc, comp, freq)

function forward_rate(yts::YieldTermStructure, time1::Float, time2::Float, comp::CompoundingType = SimpleCompounding(), freq::Frequency = Annual())
  if time1 == time2
    t1 = max(time1 - 0.0001 / 2.0, 0.0)
    t2 = t1 + 0.0001
    interval, compound = (t2 - t1, discount(yts, t1) / discount(yts, t2))
  else
    interval, compound = (time2 - time1, discount(yts, time1) / discount(yts, time2))
  end

  return implied_rate(compound, yts.dc, comp, interval, freq)
end

forward_rate(::NullYieldTermStructure, ::Date, ::Integer, ::DayCount, ::CompoundingType, ::Frequency = Annual()) = implied_rate(1.0, Act365(), SimpleCompounding(), 1.0e-2, JsQL.Time.NoFrequency())
forward_rate(::NullYieldTermStructure, ::Float, ::Float, ::CompoundingType, ::Frequency = Annual()) = implied_rate(1.0, Act365(), SimpleCompounding(), 1.0e-2, JsQL.Time.NoFrequency())

mutable struct FlatForwardTermStructure{B <: BusinessCalendar, DC <: DayCount, C <: CompoundingType, F <: Frequency} <: YieldTermStructure
  settlementDays::Int
  referenceDate::Date
  calendar::B
  forward::Quote
  dc::DC
  comp::C
  freq::F
  rate::InterestRate{DC, C, F}
  jumpTimes::Vector{JumpTime}
  jumpDates::Vector{JumpDate}
end

# MAIN CONSTRUCTOR
function FlatForwardTermStructure(settlement_days::Int, referenceDate::Date, calendar::B, forward::Quote, dc::DC,
                                  comp::C = ContinuousCompounding(), freq::F = QuantLib.Time.Annual()) where {B <: BusinessCalendar, DC <: DayCount, C <: CompoundingType, F <: Frequency}
  rate = InterestRate(forward.value, dc, comp, freq)
  FlatForwardTermStructure{B, DC, C, F}(settlement_days, referenceDate, calendar, forward, dc, comp, freq, rate, Vector{JumpTime}(), Vector{JumpDate}())
end

# Alt Constructors
FlatForwardTermStructure(referenceDate::Date, calendar::BusinessCalendar, forward::Quote, dc::DayCount, comp::CompoundingType = ContinuousCompounding(), freq::Frequency = QuantLib.Time.Annual()) =
                        FlatForwardTermStructure(0, referenceDate, calendar, forward, dc, comp, freq)

FlatForwardTermStructure(settlementDays::Int, calendar::BusinessCalendar, forward::Quote, dc::DayCount, comp::CompoundingType = ContinuousCompounding(), freq::Frequency = QuantLib.Time.Annual()) =
                        FlatForwardTermStructure(settlementDays, Date(0), calendar, forward, dc, comp, freq)

FlatForwardTermStructure(referenceDate::Date, forward::Float, dc::DayCount) =
                        FlatForwardTermStructure(0, referenceDate, JsQL.Time.TargetCalendar(), Quote(forward), dc, ContinuousCompounding(), Annual())

FlatForwardTermStructure(referenceDate::Date, forward::Float, dc::DayCount, compounding::CompoundingType, freq::Frequency) =
                        FlatForwardTermStructure(0, referenceDate, JsQL.Time.TargetCalendar(), Quote(forward), dc, compounding, freq)

discount_impl(ffts::FlatForwardTermStructure, time_frac::Float) = discount_factor(ffts.rate, time_frac)

# discount_impl(ffts::FlatForwardTermStructure, time_frac::Float64) = discount_factor(ffts.rate, time_frac)
