## This allows lazy calculation when requested

mutable struct LazyMixin
    calculated::Bool
    frozen::Bool
    observe::ObserverMixin

    LazyMixin() = new(false, false, ObserverMixin())
end

is_calculated(lazy::LazyObject) = lazy.lazyMixin.calculted
is_frozen(lazy::LazyObject) = lazy.lazyMixin.frozen

calculated!(lazy::LazyObject, setting::Bool = true) = lazy.lazyMixin.calculated = setting

# to be filled after defining the body function of performing calculation
function calculte!(lazy::LazyObject)
    if !is_calculated(lazy)
        perform_calculation!(lzay)
        calculated!(lazy)
    end
    return lazy
end

function recalculate!(lazy::LazyObject)
    calculated!(lazy, false)
    calculate!(lazy)

    return lazy
end

get_observer(lazy::LazyObject) = lazy.lazyMixin.observe.observers