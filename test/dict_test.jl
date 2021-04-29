using Dates

td = today()

dates = [td + Day(i) for i=1:30]
vals = rand(30)

dict = dates .=> vals

_dict = filter(x-> Date(2021, 5, 15) <x.first <Date(2021, 5, 20) , dict)

map(x-> x.first => x.second * 100.0, _dict)