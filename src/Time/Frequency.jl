using Dates
abstract type Frequency end

struct NoFrequency <: Frequency end
struct Once <: Frequency end
struct Annual <: Frequency end
struct SemiAnnual <: Frequency end
struct EveryFourthMonth <: Frequency end
struct Quaterly <: Frequency end
struct Monthly <: Frequency end
struct Bimonthly <: Frequency end
struct Biweekly <: Frequency end
struct EveryFourthWeek <: Frequency end
struct Weekly <: Frequency end
struct Daily <: Frequency end

value(::Frequency)   = -1
value(::NoFrequency) = -1
value(::Once) = 0
value(::Annual)      = 1
value(::SemiAnnual)  = 2
value(::EveryFourthMonth) = 3
value(::Quaterly)  = 4
value(::Bimonthly) = 6
value(::Monthly)   = 12
value(::EveryFourthWeek)  = 13
value(::Biweekly)  = 26
value(::Weekly)    = 52
value(::Daily)     = 365

Period(::Annual) = Year(1)
Period(::SemiAnnual) = Month(6)