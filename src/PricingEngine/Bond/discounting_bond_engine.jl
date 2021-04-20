using Dates

mutable struct DiscountingBondEngine{Y <: YieldTermStructure, IR <: InterestRate} <: PricingEngine
    yts::Y
    ytm::IR
    pricingCurve::Y
end

DiscountingBondEngine() = DiscountingBondEngine{NullYieldTermStructure, InterestRate}(NullYieldTermStructure(), InterestRate(-Inf), NullYieldTermStructure())

function DiscountingBondEngine(yts::Y) where {Y <: YieldTermStructure}
    return DiscountingBondEngine{Y, InterestRate}(yts, InterestRate(-Inf), yts)
end

function _calculate!(pe::DiscountingBondEngine, bond::Bond)
    eval_date = settings.evaluation_date
    update_engine!(pe, bond)
    # for now, the price is used only for p&l and greeks
    bond.results.dirtyPrice = dirty_price(pe, bond, eval_date) 
    bond.results.cleanPrice = clean_price(pe, bond, eval_date)
    bond.results.duration = duration(bond.cashflows, pe.pricingCurve, eval_date) / bond.results.dirtyPrice
    bond.results.modifiedDuration = bond.results.duration # this value will not be crucial. rather use dv01
end

function update_engine!(pe::DiscountingBondEngine, bond::Bond)
    if bond.ytm.rate == -Inf
        pe.pricingCurve = pe.yts
    else
        pe.pricingCurve = FlatForwardTermStructure(pe.yts.referenceDate, ytm_ir.rate, JsQL.Time.Act365())
    end
end

function dirty_price(pe::DiscountingBondEngine, bond::FixedCouponBond, npv_date::Date)
    return npv(bond.cashflows, pe.pricingCurve, npv_date)
end

function clean_price(pe::DiscountingBondEngine, bond::FixedCouponBond, npv_date::Date)
    _dirty_price = npv(bond.cashflows, pe.pricingCurve, npv_date)
    _value = _dirty_price - accrued_amount(bond, npv_date)
    return _value
end

function clone(pe::DiscountingBondEngine, ts::Y, ytm::IR = InterstRate(-Inf)) where {Y <: YieldTermStructure, IR <: InterestRate}
    return DiscountingBondEngine{Y, IR}(ts, ytm)
end
