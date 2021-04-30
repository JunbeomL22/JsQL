using Dates

date(s::String) = Date(s, "yyyymmdd")

usd3m_dates_s = ["20210104", "20210105", "20210106", "20210107", "20210108", "20210111", "20210112", "20210113",
                "20210114", "20210115", "20210118", "20210119", "20210120", "20210121", "20210122", "20210125",
                "20210126", "20210127", "20210128", "20210129", "20210201", "20210202", "20210203", "20210204",
                "20210205", "20210208", "20210209", "20210210", "20210215", "20210216", "20210217", "20210218",
                "20210219", "20210222", "20210223", "20210224", "20210225", "20210226", "20210302", "20210303",
                "20210304", "20210305", "20210308", "20210309", "20210310", "20210311", "20210312", "20210315",
                "20210316", "20210317", "20210318", "20210319", "20210322", "20210323", "20210324", "20210325",
                "20210326", "20210329", "20210330", "20210331", "20210401", "20210402", "20210405", "20210406",
                "20210407", "20210408", "20210409", "20210412", "20210413", "20210414", "20210415", "20210416",
                "20210419", "20210420"]
usd3m_dates = date.(usd3m_dates_s)
usd3m_values = [0.0023838, 0.0023725, 0.0023688, 0.00234, 0.0022475, 0.0022438, 0.002245, 0.0023375, 0.0024125,
                0.0022563, 0.0022338, 0.00224, 0.0022363, 0.0022238, 0.0021775, 0.0021525, 0.0021288, 0.002185,
                0.002115, 0.00205, 0.0020188, 0.001955, 0.0019225, 0.0019513, 0.0019263, 0.0019088, 0.0019538,
                0.002025, 0.0020088, 0.001915, 0.0018863, 0.0018138, 0.0018238, 0.0017525, 0.001755, 0.001875,
                0.0018975, 0.001905, 0.0018838, 0.0018338, 0.0019375, 0.001755, 0.0018538, 0.001825, 0.0017725,
                0.0018413, 0.0018388, 0.001895, 0.00182, 0.0019, 0.0018963, 0.0018663, 0.0019688, 0.001905,
                0.0020063, 0.0019513, 0.00193, 0.00199, 0.002025, 0.0020163, 0.0019425, 0.0019975, 0.0019975,
                0.0019975, 0.0019738, 0.0019363, 0.0018775, 0.001875, 0.0018575, 0.0018375, 0.0018363, 0.0018975,
                0.0018825, 0.00186]

usd3m_past_fixing = Dict(usd3m_dates .=> usd3m_values)

sofr_dates=["2021-04-28", "2021-04-27", "2021-04-26", "2021-04-23", "2021-04-22", "2021-04-21", "2021-04-20", "2021-04-19",
"2021-04-16", "2021-04-15", "2021-04-14", "2021-04-13", "2021-04-12", "2021-04-09", "2021-04-08", "2021-04-07", "2021-04-06",
"2021-04-05", "2021-04-01", "2021-03-31", "2021-03-30", "2021-03-29", "2021-03-26", "2021-03-25", "2021-03-24", "2021-03-23",
"2021-03-22", "2021-03-19", "2021-03-18", "2021-03-17", "2021-03-16", "2021-03-15", "2021-03-12", "2021-03-11", "2021-03-10",
"2021-03-09", "2021-03-08", "2021-03-05", "2021-03-04", "2021-03-03", "2021-03-02", "2021-03-01", "2021-02-26", "2021-02-25",
"2021-02-24", "2021-02-23", "2021-02-22", "2021-02-19", "2021-02-18", "2021-02-17", "2021-02-16", "2021-02-12", "2021-02-11",
"2021-02-10", "2021-02-09", "2021-02-08", "2021-02-05", "2021-02-04", "2021-02-03", "2021-02-02", "2021-02-01", "2021-01-29",
"2021-01-28", "2021-01-27", "2021-01-26", "2021-01-25", "2021-01-22", "2021-01-21", "2021-01-20", "2021-01-19", "2021-01-15",
"2021-01-14", "2021-01-13", "2021-01-12", "2021-01-11", "2021-01-08", "2021-01-07", "2021-01-06", "2021-01-05", "2021-01-04",
"2020-12-31", "2020-12-30", "2020-12-29", "2020-12-28", "2020-12-24", "2020-12-23", "2020-12-22", "2020-12-21", "2020-12-18",
"2020-12-17", "2020-12-16", "2020-12-15", "2020-12-14", "2020-12-11", "2020-12-10", "2020-12-09", "2020-12-08", "2020-12-07",
"2020-12-04", "2020-12-03", "2020-12-02", "2020-12-01", "2020-11-30", "2020-11-27", "2020-11-25", "2020-11-24", "2020-11-23",
"2020-11-20", "2020-11-19", "2020-11-18", "2020-11-17", "2020-11-16", "2020-11-13", "2020-11-12", "2020-11-10", "2020-11-09",
"2020-11-06", "2020-11-05", "2020-11-04", "2020-11-03", "2020-11-02", "2020-10-30", "2020-10-29", "2020-10-28", "2020-10-27",
"2020-10-26", "2020-10-23", "2020-10-22", "2020-10-21", "2020-10-20", "2020-10-19", "2020-10-16", "2020-10-15", "2020-10-14",
"2020-10-13", "2020-10-09", "2020-10-08", "2020-10-07", "2020-10-06", "2020-10-05", "2020-10-02", "2020-10-01", "2020-09-30",
"2020-09-28", "2020-09-25", "2020-09-24", "2020-09-23", "2020-09-22", "2020-09-21", "2020-09-18", "2020-09-17", "2020-09-16",
"2020-09-15", "2020-09-14", "2020-09-11", "2020-09-10", "2020-09-09", "2020-09-08", "2020-09-04", "2020-09-03", "2020-09-02",
"2020-09-01", "2020-08-31", "2020-08-28", "2020-08-27", "2020-08-26", "2020-08-25", "2020-08-24", "2020-08-21", "2020-08-20"]

sofr_values = [0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 0.0001, 
0.0001, 0.0001, 0.0001]

sofr_dict = Date.(sofr_dates[1:100]) .=> sofr_values[1:100]
ois_periods = [Day(1), Week(1), Week(2), Month(2), Month(3), Month(4), Month(5), 
                Month(6), Month(7), Month(8), Month(9), Month(10), Month(11), 
                Year(1), Year(2), Year(3), Year(4), Year(5), Year(6), Year(7), Year(8), Year(9), Year(10)]
ois_zeros = [0.00103131, 0.00093816, 0.00093039, 0.00091618, 0.00085450, 0.00082342, 0.00078263, 0.00075199,
            0.00071133, 0.00068082, 0.00065032, 0.00060974, 0.00058937, 0.00055891, 0.00053857, 0.00029395,
            0.00032502, 0.00059853, 0.00111610, 0.00179768, 0.00248133, 0.00317771, 0.00383575, 0.00439290]

kospi_div_date = [Date("2021-06-29")]