using Dates

abstract type DayCount end
struct Act360 <: DayCount end
struct Act365 <: DayCount end

abstract type Thirty360  <:  DayCount end
struct BondThirty360     <: Thirty360 end
struct EuroBondThirty360 <: Thirty360 end

abstract type ActAct <: DayCount end
struct IsdaActAct <: ActAct end

"""
default case, basically actact
"""
day_count(c::DayCount, d_start::Date, d_end::Date) = Dates.value(d_end - d_start) # Int(d_end - d_start)

days_per_year(::Union{Act360, Thirty360}) = 360.0
days_per_year(::Act365) = 365.0

function day_count(::DayCount, st::Date, ed::Date)
    ed < st && error("day_count error (act): end date is before the start date {Refer to st = $(st), ed = $(ed)}")
    return Dates.value(ed-st)
end

function day_count(::BondThirty360, st::Date, ed::Date)
    ed < st && error("day_count error (bond30): end date is before the start date {Refer to st = $(st), ed = $(ed)}")
    d1 = day(st)
    d2 = day(ed)

    m1 = month(st)
    m2 = month(ed)

    y1 = year(st)
    y2 = year(ed)

    if d2 == 31 && d1 < 30
        d2 = 1
        m2 += 1
    end

    return 360.0 * (y2 - y1) + 30.0 * (m2 - m1 - 1) + max(0, 30 - d1) + min(30, d2)
end

function day_count(dc::EuroBondThirty360, st::Date, ed::Date)
    ed < st && error("day_count error (EurBond30): end date is before the start date.")
    
    d1 = day(st)
    d2 = day(ed)

    m1 = month(st)
    m2 = month(ed)

    y1 = year(st)
    y2 = year(ed)

    return 360.0 * (y2 - y1) + 30.0 * (m2 - m1 - 1) + max(0, 30 - d1) + min(30, d2)
end

year_fraction(c::DayCount, st::Date, ed::Date) = day_count(c, st, ed) / days_per_year(c)

year_fraction(st::Date, ed::Date) = year_fraction(IsdaActAct(), st, ed)

function year_fraction(dc::IsdaActAct, d1::Date, d2::Date, ::Date = Date(0), ::Date = Date(0))
    if d1 == d2
        return 0.0
    end
  
    if d1 > d2
        return -year_fraction(dc, d2, d1, Date(0), Date(0))
    end
  
    y1 = year(d1)
    y2 = year(d2)
  
    dib1 = daysinyear(d1)
    dib2 = daysinyear(d2)

    sum = y2 - y1 - 1
  
    sum += day_count(dc, d1, Date(y1+1, 1, 1)) / dib1
    sum += day_count(dc, Date(y2, 1, 1), d2) / dib2
    return sum
end   