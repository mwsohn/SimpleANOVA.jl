using .DataFrames

function anova(df::DataFrame, observationscolumn::Symbol, factorcolumns::Vector{Symbol}, factortypes::Vector{FactorType} = FactorType[]; factornames::Vector{<:AbstractString} = String[])
    df2 = df[completecases(df,vcat(observationcolumn, factorcolumns),:]
    observations = df2[!, observationscolumn]
    length(observations) > 0 || return
    nonmissingtype(eltype(observations)) <: Number || error("Obervations must be numeric")
    isempty(factornames) && (factornames = [String(col) for col ∈ factorcolumns])
    anova(observations, [df2[!, x] for x ∈ factorcolumns], factortypes, factornames = factornames)
end
