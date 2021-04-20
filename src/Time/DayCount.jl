using Dates

abstract type DayCount end
struct Act360 <: DayCount end
struct Act365 <: DayCount end

abstract type Thirty360  <:  DayCount end
struct BondThirty360     <: Thirty360 end
struct EuroBondThirty360 <: Thirty360 end

days_per_year(::Union{Act360, Thirty360}) = 360.0
days_per_year(::Act365) = 365.0

function day_count(::DayCount, st::Date, ed::Date)
    ed < st && error("day_count error (act): end date is before the start date.")
    return Dates.value(ed-st)
end

function day_count(::BondThirty360, st::Date, ed::Date)
    ed < st && error("day_count error (bond30): end date is before the start date.")
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

year_fraction(st::Date, ed::Date) = year_fraction(JsQL.Time.Act365(), st, ed)