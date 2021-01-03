const totalname = "Total"
const cellsname = "Cells"
const errorname = "Error"
const remaindername = "Remainder"

"""
    anova(observations::Array{Union{Number, Vector{Number}}}, factortypes = FactorType[]; factornames = String[], hasreplicates = true)
    anova(observations::Vector{Number}, factorassignments::Vector{Vector{Any}}, factortypes = FactorType[]; factornames = String[], hasreplicates = true)
    anova(df::DataFrame, observationscolumn::Symbol, factorcolumns::Vector{Symbol}, factortypes = FactorType[]; factornames = String[])

Performs an Analysis of Variance (ANOVA) calculation.

Operates on up to 3 crossed factors (fixed or random) and arbitrarily many random nested factors, with or without
replicates, on balanced data.

# Arguments
- `observations`: Array containing the values to test. For the array, each dimension is a factor level, such that observations[2,5,3] indicates the 2nd level of the first factor, the 5th level of the second factor, and the 3rd level of the third factor. May contain values or vectors of values, where the vector contains replicates. Factors should be ordered with least significant first. For the vector, must provide `factorassignments` to specify factor levels.
- `factorassignments`: Vector of vectors of integers specifying how each observation is assigned to a factor level. Provide this when `observations` is given as a vector. Factor levels do not have to be consecutive or ordered. Nested factors must reuse factor levels currently.
- `factortypes`: Vector indicating the `FactorType` for each factor. If present, `replicates` must appear first, any `nested` after, and then `random` or `fixed` in any order. Specify `replicates` if the first dimension of the `observations` matrix contains replicate values (vs. contained in vectors). If too few values are provided, remaining are assumed to be `fixed`.
- `factornames`: Vector of names for each factor, excluding the replicate factor. If empty, will be automatically populated alphabetically.

Notes: The last index will be the top factor in the table.

Output: `AnovaData` structure containing the test results for each factor.

# Examples
```julia
anova(observations)                        # N-way fixed-effects ANOVA with replicates (vectors or first dimension)
anova(observations, hasreplicates = false) # N-way fixed-effects ANOVA without replicates (first dimension)
anova(observations, [random])              # N-way ANOVA with lower random factor and 1 or 2 upper fixed factors
anova(observations, [random])              # N-way ANOVA with lower random factor and 1 or 2 upper fixed factors
anova(observations, [fixed, random])       # N-way ANOVA with 1 lower fixed factor, 1 random factor, and 0 or 1 upper fixed factor
anova(observations, [nested, random])      # N-way fixed-effects ANOVA with 1 random nested factor, 1 random factor, and 1-2 fixed factors
anova(observations, [fixed, subject])      # N-way repeated measures ANOVA with 1 within-subjects fixed factor
anova(observations, [fixed, block])        # N-way repeated measures ANOVA with 1 within-block fixed factor
```

# Glossary
- observation: The dependent variable.
- factor: An independent variable.
- factor level: A value of a factor.
- balanced: All combinations of factor levels have the same number of observations.
- crossed factor: A factor with levels that combine with the levels of all other crossed factors.
- fixed factor: A factor with fixed effects (e.g. treatment, concentration, exposure time).
- random factor: A factor with random effects (e.g. location, individual).
- nested factor: A random factor where the levels are unique to a combination of crossed factor levels (e.g. replicate).
- subject/block factor: A nested factor that is subjected to multiple levels of another factor.
- sum of squares (SS): A measure of variance that is dependent on sample size. Also called "sum of squared deviations."
- degrees of freedom (DF, ν): The number of bins in which the values could have been moved, if random.
- mean square (MS): SS / DF. Corrects for the larger variance expected if random values can be assigned to more bins. Also called "mean squared error" or "mean squared deviation."
- F-statistic: The division of MS values produce a result belonging to the "F distribution", the shape of which depends on the DF of the numerator and error. The location of this value on the distribution provides the p-value.
- p-value: The probability that, if all measurements had been drawn from the same population, you would obtain data at least as extreme as contained in your observations.
- effect size: The standardized difference in the measurement caused by the factor.
"""
function anova(observations::AbstractVector{T}, factorassignments::AbstractVector{<:AbstractVector}, factortypes::Vector{FactorType} = FactorType[]; factornames::Vector{<:AbstractString} = String[]) where {T <: Number}
    # convert vector arguments into a multidimensional matrix

    length(observations) > 0 || return
    nfactors = length(factorassignments)
    N = length(observations)
    N % nfactors == 0 || error("Design is unbalanced.")
    all(length.(factorassignments) .== N) || error("Each observation must have an assignment for each factor.")

    factorlevels = factorassignments .|> unique .|> sort
    nfactorlevels = length.(factorlevels)
    all(N .& nfactorlevels .== 0) || error("Design is unbalanced.")
    factorlevelcounts = [[count(l -> l == factorlevels[i][j], factorassignments[i]) for j ∈ 1:nfactorlevels[i]] for i ∈ 1:nfactors]
    nperfactorlevel = factorlevelcounts .|> unique
    all(nperfactorlevel .|> length .== 1) || error("Design is unbalanced.")
    nperfactorlevel = nperfactorlevel .|> first

    if !(isa(factorassignments, Number)) || any(maximum.(factorlevels) .> nfactorlevels)
        compressedfactorlevels = [1:i for i ∈ nfactorlevels]
        factorlevelremapping = [factorlevels[i] .=> compressedfactorlevels[i] for i ∈ 1:nfactors]
        factorassignments = [replace(factorassignments[i], factorlevelremapping[i]...) for i ∈ 1:nfactors]
    end

    nreplicates = Int(N / prod(nfactorlevels))

    nlevels = [nreplicates; nfactorlevels]
    sortorder = sortperm(repeat(1:nreplicates, Int(N / nreplicates)) .+
                         sum([factorassignments[i] .* prod(nlevels[1:i]) for i ∈ 1:nfactors]))
    observationsmatrix = reshape(observations[sortorder], nlevels...)
    anova(observationsmatrix, factortypes, factornames = factornames, hasreplicates = nreplicates > 1)
end

function anova(observations::AbstractArray{T}, factortypes::Vector{FactorType} = FactorType[]; factornames::Vector{<:AbstractString} = String[], hasreplicates = true) where {T <: Union{Number, AbstractVector{<:Number}}}
    length(observations) > 0 || return

    isrepeatedmeasures = subject ∈ factortypes

    observations = upcat(observations)
    nfactors = ndims(observations) - (hasreplicates ? 1 : 0)

    # defaults to assuming all unspecified factors are fixed
    if length(factortypes) < nfactors
        nremaining = nfactors - length(factortypes)
        append!(factortypes, repeat([fixed], nremaining))
    end
    replace!(factortypes, block => subject)

    validate(factortypes, factornames, nfactors)

    # automatically assigns alphabetical names if not provided.
    if isempty(factornames)
        factornames = string.('A':'Z')[1:nfactors]
        reverse!(factornames)
    end

    anovakernel(observations, factornames, factortypes, hasreplicates)
end

function validate(factortypes::Vector{FactorType}, factornames::Vector{<:AbstractString}, nfactors)
    if !isempty(factortypes)
        length(factortypes) == nfactors ||
            error("`factortypes` must have an entry for each factor.")

        nested ∉ factortypes ||
            factortypes[1:count(isnested, factortypes)] |> unique |> length == 1 ||
            error("Nested factors must come before any other factors.")

        if subject ∈ factortypes
            count(issubject, factortypes) == 1 ||
                error("Maximum of one subject/block factor.")

            notnestedfactortypes = filter(f -> !isnested(f), factortypes)
            (notnestedfactortypes[2] == subject || notnestedfactortypes[3] == subject) ||
                error("Subject/block factor must be second or third entry after any nested factors.")
            
            length(notnestedfactortypes) < 5 ||
                error("Maximum of 3 within-subjects or among-subjects factors.")

            random ∉ notnestedfactortypes ||
                error("Random factors are not supported with subject/block factor.")
        end

        crossedfactortypes = filter(f -> f ∈ [fixed, random], factortypes)
        length(crossedfactortypes) < 4 ||
            all(isfixed, crossedfactortypes) ||
            error("ANOVA with 4 or more crossed factors is not supported if any are random.")

        firstlevelreplicates ||
            all(c -> length(c) == nreplicates, observations) ||
            error("All cells must have the same number of replicates.")
    end
    if isempty(factornames)
        nfactors ≤ 26 || error("Can only automatically name up to 26 factors. Provide names explicitly.")
    else
        length(factornames) == nfactors || error("factornames must have an entry for each factor.")
    end
end

#=
function anova(data::AnovaData, crossedfactors::Vector{Int}, )
    # performs a subtest of the specified crossed factors within level of the remaing crossed factors, using the original errors
end

# possible bug: function anova(data::AnovaData, crossedfactors::Vector{Int}, ) with normal functions ==> hang when called?
=#

mutable struct AnovaData2
    effects::Vector{AnovaEffect}
end

#= TODO:
- Validation for limitations
- Reimplement effect sizes
- "remainder" condition for when there are no replicates
=#
function anovakernel(observations::AbstractArray{<:Number}, factornames, factortypes, hasreplicates)
    isrepeatedmeasures = subject ∈ factortypes

    totaldf = length(observations) - 1
    totalvar = anovavalue(totalname, var(observations), totaldf)

    if hasreplicates
        nreplicates = size(observations, 1)
        cellmeans = meanfirstdim(observations)
    else
        nreplicates = 1
        cellmeans = observations
    end
    
    cellsdf = length(cellmeans) - 1
    cellsvar = anovavalue(cellsname, var(cellmeans) * nreplicates, cellsdf)

    errorvar = AnovaFactor(errorname, totalvar - cellsvar)

    nnested = count(isnested, factortypes)
    nestedfactornames = @view factornames[1:nnested]
    factornames = @view factornames[(nnested + 1):end]
    factortypes = @view factortypes[(nnested + 1):end]

    nestedvars, nestederrorvars, cellmeans, nreplicates = nestedfactors(cellmeans, nreplicates, nestedfactornames)

    factorvars = anovafactors(cellmeans, nreplicates, factornames)
    interactionvars = factorvars[(length(factortypes) + 1):end]

    factorerrorvars = isrepeatedmeasures ? anovasubjecterrors(interactionvars, factortypes) :
                                            anovaerrors(interactionvars, factortypes, nestedvars[1])

    append!(factorvars, nestedvars)
    append!(factorerrorvars, nestederrorvars)

    factorresults = ftest.(factorvars, factorerrorvars)

    return AnovaData2([totalvar; factorresults; errorvar])
end

function anovafactors(cellmeans, nreplicates, factornames)
    # calculate all simple factors and all interactions

    N = length(cellmeans) * nreplicates

    factors = 1:ndims(cellmeans)

    allfactors = []
    allfactorvars = AnovaFactor[]
    for i ∈ factors
        ifactors = collect(combinations(reverse(factors), i))
        iotherfactors = [factors[Not(i...)] for i ∈ ifactors]
        iupperfactorvars = [allfactorvars[findall(x -> x ⊆ i, allfactors)] for i ∈ ifactors]

        ifactornames = [makefactorname(factornames[i]) for i ∈ ifactors]
        ifactorss = [var(mean(cellmeans, dims = iotherfactors[i]), corrected = false) * N - sum(iupperfactorvars[i]).ss for i ∈ eachindex(iotherfactors)]
        ifactordf = isempty(iupperfactorvars[1]) ? [size(cellmeans, i) - 1 for i ∈ factors] :
                                                   [prod(f.df for f ∈ iupperfactorvars[j][1:i]) for j ∈ eachindex(iotherfactors)]
        ifactorvars = AnovaFactor.(ifactornames, ifactorss, ifactordf)
        
        append!(allfactors, ifactors)
        append!(allfactorvars, ifactorvars)
    end

    return allfactorvars
end

function anovaerrors(interactionvars, factortypes, errorvar)
    # assign proper error terms for each factor

    length(factortypes) == 1 && return [errorvar]
    all(x -> x == fixed, factortypes) && return repeat([errorvar], length(factortypes) + length(interactionvars))

    interaction12var = interactionvars[1]

    factortypes = reverse(factortypes)

    if length(factorvars) == 2
        if factortypes[1] == factortypes[2]
            factor1error = interaction12var
            factor2error = interaction12var
        else
            if factortypes[1] == fixed
                factor1error = interaction12var
                factor2error = errorvar
            else
                factor1error = errorvar
                factor2error = interaction12var
            end
        end
        factorerrorvars = [factor1error; factor2error; errorvar]

    elseif length(factorvars) == 3
        interaction12var = interactionvars[1]
        interaction13var = interactionvars[2]
        interaction23var = interactionvars[3]
        interaction123var = interactionvars[4]

        if factortypes[1] == factortypes[2] == factortypes[3]
            factor1error = threeway_random_error(interaction12var, interaction13var, interaction123var)
            factor2error = threeway_random_error(interaction12var, interaction23var, interaction123var)
            factor3error = threeway_random_error(interaction13var, interaction23var, interaction123var)
            interaction12error = interaction13error = interaction23error = interaction123var
        elseif factortypes[1] == factortypes[2]
            if factortypes[1] == fixed
                factor1error = interaction13var
                factor2error = interaction23var
                factor3error = errorvar
                interaction12error = interaction123var
                interaction13error = interaction23error = errorvar
            else
                factor1error = factor2error = interaction12var
                factor3error = threeway_random_error(interaction13var, interaction23var, interaction123var)
                interaction12error = errorvar
                interaction13error = interaction23error = interaction123var
            end
        elseif factortypes[1] == factortypes[3]
            if factortypes[1] == fixed
                factor1error = interaction12var
                factor2error = errorvar
                factor3error = interaction23var
                interaction12error = interaction23error = errorvar
                interaction13error = interaction123var
            else
                factor1error = factor3error = interaction13var
                factor2error = threeway_random_error(interaction12var, interaction23var, interaction123var)
                interaction12error = interaction23error = interaction123var
                interaction13error = errorvar
            end
        else
            if factortypes[2] == fixed
                factor1error = errorvar
                factor2error = interaction12var
                factor3error = interaction13var
                interaction12error = interaction13error = errorvar
                interaction23error = interaction123var
            else
                factor1error = threeway_random_error(interaction12var, interaction13var, interaction123var)
                factor2error = factor3error = interaction23var
                interaction12error = interaction13error = interaction123var
                interaction23error = errorvar
            end
        end
        factorerrorvars = [factor1error; factor2error; factor3error; interaction12error; interaction13error; interaction23error; errorvar]

    else
        error("More than 3 factors with any random are not supported.")
    end

    return factorerrorvars
end

function anovasubjecterrors(interactionvars, factortypes)
    # doesn't return one for subjects factor or for subject interactions
    factortypes = reverse(factortypes)
    subjectindex = findfirst(x -> x == subject, factortypes)
    
    interaction1s = interactionvars[1]

    if length(factortypes) == 2
        # one within-subject factor    
        factorerrorvars = [interaction1s; interaction1s]

    elseif length(factortypes) == 3
        interaction12s = interactionvars[4]

        if subjectindex == 2
            # one among factor and one within-subject factor
            factorerrorvars = [interaction1s; interaction12s; interaction12s]

        else
            # two within-subject factors
            interaction2s = interactionvars[2]
            factorerrorvars = [interaction1s; interaction2s; interaction12s]

        end
                
    elseif length(factortypes) == 4
        interaction12s = interactionvars[7]
        interaction123s = interactionvars[11]

        if subjectindex == 3
            # two among factors and one within-subject factor
            factorerrorvars = [interaction12s; interaction12s; interaction12s; interaction123s; interaction123s; interaction123s; interaction123s]

        else
            interaction12s = interactionvars[7]
            interaction13s = interactionvars[8]

            if subjectindex == 2
                # one among factor and two within-subject factors
                factorerrorvars = [interaction1s; interaction12s; interaction13s; interaction12s; interaction13s; interaction123s; interaction123s]
            
            else
                # three within-subject factors
                interaction2s = interactionvars[2]
                interaction3s = interactionvars[3]
                interaction23s = interactionvars[9]
                factorerrorvars = [interaction1s; interaction2s; interaction3s; interaction12s; interaction13s; interaction123s; interaction123s]
            end
        end
    else
        error("More than 3 non-subject factors are not supported.")
    end

    return factorerrorvars
end

function nestedfactors(cellmeans, nreplicates, factornames)
    # compute nested factors and collapse nested levels

    nnested = length(factornames)

    nestedvars = AnovaFactor[]
    for i ∈ 1:nnested
        nestedmeans = mean(cellmeans, dims = 1)
        ss = sum((cellmeans .- nestedmeans) .^ 2) * nreplicates
        df = (size(cellmeans, 1) - 1) * prod(size(nestedmeans))
        push!(nestedvars, AnovaFactor(factornames[i], ss, df))
        nreplicates *= size(cellmeans, 1)
        cellmeans = dropdims(nestedmeans, dims = 1)
    end
    nestederrorvars = nnested > 0 ? [errorvar; nestedvars[1:(end - 1)]] :
                                    []
    return reverse!(nestedvars), reverse!(nestederrorvars), cellmeans, nreplicates
end

anovavalue(name, variance, df) = AnovaValue(name, variance * df, df)
meanfirstdim(observations::AbstractArray{<:Number}) = dropdims(mean(observations, dims = 1), dims = 1)
upcat(x::AbstractArray) = x
upcat(x::AbstractArray{<:AbstractVector}) = reshape(vcat(x...), (size(x[1])..., size(x)...))

makefactorname(factorname::AbstractString) = factorname

function makefactorname(factornames::AbstractVector{<:AbstractString})
    length(factornames) > 0 || return ""
    
    factorname = factornames[1]
    
    for i ∈ 2:length(factornames)
        factorname *= " × " * factornames[i]
    end

    return factorname
end

function threeway_random_error(interaction_ab, interaction_bc, interaction_abc)
    reducedmeansquare(factor::AnovaFactor) = factor.ms ^ 2 / factor.df
    ms = interaction_ab.ms + interaction_bc.ms - interaction_abc.ms
    df = ms ^ 2 / (reducedmeansquare(interaction_ab) + reducedmeansquare(interaction_bc) + reducedmeansquare(interaction_abc))
    AnovaFactor("", ms * df, df, ms)
end

function ftest(x, y)
    f = x.ms / y.ms
    fdist = FDist(x.df, y.df)
    p = ccdf(fdist, f)
    AnovaResult(x, f, p)
end

#=
function effectsizescalc(results, denominators, total, ncrossedfactors, npercrossedcell, ncrossedfactorlevels, crossedfactortypes, nnestedfactors, nnestedfactorlevels, nreplicates)
    differences = [results[i].ms - denominators[i].ms for i ∈ eachindex(results)] # 1 kb between this line and next
    crossedfactordfs = [r.df for r ∈ results[1:ncrossedfactors]]

    if nreplicates == 1 && nnestedfactors > 0
        nnestedfactors -= 1
        nnestedfactorlevels = nnestedfactorlevels[1:(end-1)]
    end

    if ncrossedfactors == 1
        if nnestedfactors == 0
            ω² = [(results[1].ss - results[1].df * denominators[1].ms) / (total.ss + denominators[1].ms)]
        else
            effectdenominators = repeat([nreplicates], nnestedfactors + 1)
            nfactorlevels = [ncrossedfactorlevels; nnestedfactorlevels]
            effectdenominators[1] *= prod(nfactorlevels)
            factors = ones(Int, nnestedfactors + 1)
            factors[1] = crossedfactordfs[1]
            for i ∈ 2:nnestedfactors
                effectdenominators[2:(end - i + 1)] .*= nfactorlevels[end - i + 2]
            end
            σ² = factors .* differences ./ effectdenominators
            σ²total = sum(σ²) + denominators[end].ms
            ω² = σ² ./ σ²total
        end
    else
        if ncrossedfactors == 2 # this whole block not quite 1 kb
            if npercrossedcell > 1
                interactionindexes = ([1,2],)
                imax = 3
            else
                interactionindexes = ()
                imax = 2
            end
        else
            if npercrossedcell > 1
                interactionindexes = ([1,2], [1,3], [2,3], [1,2,3])
                imax = 7
            else
                interactionindexes = ([1,2], [1,3], [2,3])
                imax = 6
            end
        end

        icrossed = 1:ncrossedfactors # this whole block 1 kb
        iother = ncrossedfactors < imax ? ((ncrossedfactors + 1):imax) : []
        factors = Vector{Int}(undef, imax)
        factors[icrossed] = [crossedfactortypes[i] == fixed ? crossedfactordfs[i] : 1 for i ∈ icrossed]
        factors[iother] = [prod(factors[x]) for x ∈ interactionindexes]

        effectsdenominators = repeat([npercrossedcell], imax)
        israndom = [x == random for x ∈ crossedfactortypes] # Originally used broadcasted equality (.==) but causes high allocations as of 1.3.0-rc3
        isfixed = [x == fixed for x ∈ crossedfactortypes]
        crossedeffectsdenominators = effectsdenominators[icrossed]
        crossedeffectsdenominators[isfixed] .*= prod(ncrossedfactorlevels)
        crossedeffectsdenominators[israndom] .*= [prod(ncrossedfactorlevels[Not(i)]) for i ∈ icrossed[israndom]]
        effectsdenominators[icrossed] = crossedeffectsdenominators
        effectsdenominators[iother] .*= [prod(ncrossedfactorlevels[Not(icrossed[israndom] ∩ x)]) for x ∈ interactionindexes] # 7kb - set intersection is 1kb, has to be done for each interaction

        σ² = factors .* differences[1:imax] ./ effectsdenominators

        if nnestedfactors > 0
            nestedrange = (length(results) .- nnestedfactors .+ 1):length(results)
            nestedeffectdenominators = repeat([nreplicates], nnestedfactors)
            for i ∈ 1:(nnestedfactors - 1)
                nestedeffectdenominators[1:(end - i + 1)] .*= nnestedfactorlevels[end - i + 2]
            end
            σ²nested = differences[nestedrange] ./ nestedeffectdenominators
            σ² = [σ²; σ²nested]
        end

        σ²total = sum(σ²) + denominators[end].ms
        ω² = σ² ./ σ²total
    end
    AnovaResult.(results, ω²)
end
=#
