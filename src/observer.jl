# Observer pattern

mutable struct ObserverMixin
    observers::Vector
    observables::Vector

    ObserverMixin() = new([], [])
end

function add_observer!(ob::Observer, obsv::T) where {T}
    if ~in(obsv, get_observer(ob))
        push!(get_observer(ob), obsv)
    end
end

function notify_observer!(ob::Observer)
    for obsv in get_observer(ob)
        update!(obsev)
    end

    return ob
end