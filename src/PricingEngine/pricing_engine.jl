struct NullPricingEngine <: PricingEngine end

_calculate!(pe::NullPricingEngine, inst::Instrument) = error("A valid pricing engine must be implemented.")

