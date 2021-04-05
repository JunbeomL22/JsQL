using Dates

struct EuropeanExercise <: Exercise
    dates::Vector{Date} # singleton value
end
struct BermudanExercise <: Exercise
    dates::Vector{Date}  
end
struct AmericanExercise <: Exercise 
    dates::Vector{Date} # 2 elements, indicate start and end date
end

EuropeanExercise(d::Date) = EuropeanExercise([d])
AmericanExercise(d1::Date, d2::Date) = AmericanExercise([d1, d2])


