using QuantLib
using Dates

#usd_libor_index(QuantLib.Time.TenorPeriod(Dates.Month(3)), yts)

function generate_floatingrate_bond(disc_yts::YieldTermStructure, 
                                    dc::QuantLib.Time.DayCount, 
                                    issue::Date,
                                    maturity::Date, 
                                    spread::Float64, 
                                    xibor_index::I,
                                    face_amt::Float64,
                                    cap_vol::OptionletVolatilityStructure) where {I <: InterestRateIndex}
    # Floating Rate bond
    settlement_days = 3
    face_amount = face_amt
    fb_issue_date = issue
    bond_engine = DiscountingBondEngine(disc_yts)
    fb_dc = dc
    conv = QuantLib.Time.ModifiedFollowing()
    fb_schedule = QuantLib.Time.Schedule(issue, maturity,
                                        QuantLib.Time.TenorPeriod(QuantLib.Time.Quarterly()),
                                        QuantLib.Time.Unadjusted(), QuantLib.Time.Unadjusted(), 
                                        QuantLib.Time.DateGenerationBackwards(), false,
                                        QuantLib.Time.USNYSECalendar())
    fixing_days = 2
    in_arrears = true
    gearings =  ones(length(fb_schedule.dates) - 1)
    spreads = fill(spread, length(fb_schedule.dates) - 1)

    libor_3m = xibor_index

    floating_bond = FloatingRateBond(settlement_days, face_amount, fb_schedule, libor_3m, 
                                    fb_dc, conv, fixing_days, fb_issue_date, bond_engine, 
                                    in_arrears, face_amt, gearings, spreads, cap_vol=cap_vol)
  
    return floating_bond
end

