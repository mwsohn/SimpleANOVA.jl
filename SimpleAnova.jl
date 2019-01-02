module SimpleAnova

using Statistics
using Distributions
include("InvertedIndices.jl")

import Main.InvertedIndices.Not

"""
    anova

    measurements = N-element vector of each measurement
    factors = M-element vector of CategoricalArrays assigning each measurement to a level of each of M factors
    factortype = M-element vector of FactorType

    Requires equal replication, assumes no missing data
"""

@enum FactorType fixed random nested replicate

#=
function anova(measurements::Vector{T}, factors::Vector{CategoricalArray{Int}}, factortype::Vector{FactorType})
    N = length(measurements)
    factors = length(factors)

    all(length.(factors) .== N) || throw(ErrorException("Factor arrays must each have $N entries."))
    factortype == nfactors || throw(ErrorException("Factortype must have an entry for each factor."))

    nfactorlevels = length.(levels.(factors))

        squared = measurements .^ 2

end
=#

abstract type AnovaEffect
end

struct AnovaValue <: AnovaEffect
    ss::Float64
    df::Float64
end

struct AnovaFactor <: AnovaEffect
    ss::Float64
    df::Float64
    ms::Float64
end

Broadcast.broadcastable(a::AnovaFactor) = (a,)


AnovaFactor(ss, df) = AnovaFactor(ss, df, ss / df)

"""
    anova(observations)

observations - multidimensional array containing observations. Each dimension of
the array is a crossed factor. The elements of the array may be:
    - numbers or `missing` (only 1 observation per combination)
    - vectors (of vectors) of numbers or `missing` (nested random factors)

Attempts to fill missing values
"""

function ftest(x, y)
    f = x.ms / y.ms
    fdist = FDist(x.df, y.df)
    p = ccdf(fdist, f)
    (f,p)
end


#=
Index indicates the value of that factor level. E.g. [3,4] specifies Factor A level 3 and Factor B level 4

Examples

1-way ANOVA:
observations = Array{Vector{Float64}, 1}(undef, 4)
observations[1] = [60.8, 57.0, 65.0, 58.6, 61.7]
observations[2] = [68.7, 67.7, 74.9, 66.3, 69.8]
observations[3] = [102.6, 102.1, 100.2, 96.5, 100.4]
observations[4] = [87.9, 84.2, 83.1, 85.7, 90.3]

-or-

observations = [60.8 68.7 102.6 87.9;
                57.0 67.7 102.1 84.2;
                65.0 74.9 100.2 83.1;
                58.6 66.3 96.5 85.7;
                61.7 69.8 100.4 90.3]

Factor
    1      2      3      4
 60.8   68.7  102.6   87.9
 57.0   67.7  102.1   84.2
 65.0   74.9  100.2   83.1
 58.6   66.3   96.5   85.7
 61.7   69.8  100.4   90.3

            SS  DF      MS      F       p
Total   4823.0  19
Factor  4685.0   3  1561.7  181.8   1e-12
Error    137.5  16     8.6

2-way ANOVA without replication:
observations = [123 138 110 151; 145 165 140 167; 156 176 185 175]

                Factor B
                  1   2   3   4
Factor A    1   123 138 110 151
            2   145 165 140 167
            3   156 176 185 175

                SS  DF      MS     F        p
Total       5594.9  11
Factor A    3629.2   2  1814.6  12.8    0.007
Factor B    1116.9   3   372.3   2.6    0.145
Remainder    848.8   6   141.5

2-way ANOVA with replication

Specified in Array with cells nested as vectors
observations = Array{Vector{Float64}, 2}(undef, 2, 2)
observations[1,1] = [16.5, 18.4, 12.7, 14.0, 12.8]
observations[1,2] = [14.5, 11.0, 10.8, 14.3, 10.0]
observations[2,1] = [39.1, 26.2, 21.3, 35.8, 40.2]
observations[2,2] = [32.0, 23.8, 28.8, 25.0, 29.3]

-or-

Specified in multidimensional array with 1st dimension as replicate
observations = cat(hcat([16.5, 18.4, 12.7, 14.0, 12.8], [39.1, 26.2, 21.3, 35.8, 40.2]),
                   hcat([14.5, 11.0, 10.8, 14.3, 10.0], [32.0, 23.8, 28.8, 25.0, 29.3]), dims = 3)
    Note: must specify that first dimension is a replicate

                Factor B
                   1       2
Factor A    1   16.5    14.5
                18.4    11.0
                12.7    10.8
                14.0    14.3
                12.8    10.0

            2   39.1    32.0
                26.2    23.8
                21.3    28.8
                35.8    25.0
                40.2    29.3

                SS  DF      MS     F        p
Total       1827.7  11
Cells       1461.3   3
Factor A    1386.1   2  1386.1  60.5     8e-7
Factor B      70.3   3    70.3   3.1    0.099
Error        366.4   6   366.4


1-way ANOVA with 1 nested factor, replicates

Specified in Array with cells nested as vectors
observations = Array{Vector{Float64}, 2}(undef, 2, 3)
observations[1,1] = [102, 104]
observations[1,2] = [108, 110]
observations[1,3] = [104, 106]
observations[2,1] = [103, 104]
observations[2,2] = [109, 108]
observations[2,3] = [105, 107]

-or-

Specified in multidimensional array with 1st dimension as replicate
observations = cat(hcat([102, 104], [103, 104]),
                   hcat([108, 110], [109, 108]),
                   hcat([104, 106], [105, 107]), dims = 3)
    Note: must specify that first dimension is a replicate

                        Factor B
                          1   2   3
Nested Factor A     1   102 108 104
                        104 110 106

                    2   103 109 105
                        104 108 107

                      SS    DF    MS
Total               71.7    11
Across Factor A     62.7     5
Factor B            61.2     2  30.6
Factor A             1.5     3   0.5
Error                9.0     6   1.5

3-way ANOVA
Specified in Array with cells nested as vectors
observations = Array{Vector{Float64}, 3}(undef, 2, 3, 3)
observations[1,1,1] = [1.9, 1.8, 1.6, 1.4]
observations[1,1,2] = [2.1, 2.0, 1.8, 2.2]
observations[1,1,3] = [1.1, 1.2, 1.0, 1.4]
observations[1,2,1] = [2.3, 2.1, 2.0, 2.6]
observations[1,2,2] = [2.4, 2.6, 2.7, 2.3]
observations[1,2,3] = [2.0, 2.1, 1.9, 2.2]
observations[1,3,1] = [2.9, 2.8, 3.4, 3.2]
observations[1,3,2] = [3.6, 3.1, 3.4, 3.2]
observations[1,3,3] = [2.9, 2.8, 3.0, 3.1]
observations[2,1,1] = [1.8, 1.7, 1.4, 1.5]
observations[2,1,2] = [2.3, 2.0, 1.9, 1.7]
observations[2,1,3] = [1.4, 1.0, 1.3, 1.2]
observations[2,2,1] = [2.4, 2.7, 2.4, 2.6]
observations[2,2,2] = [2.0, 2.3, 2.1, 2.4]
observations[2,2,3] = [2.4, 2.6, 2.3, 2.2]
observations[2,3,1] = [3.0, 3.1, 3.0, 2.7]
observations[2,3,2] = [3.1, 3.0, 2.8, 3.2]
observations[2,3,3] = [3.2, 2.9, 2.8, 2.9]

-or-

Specified in multidimensional array with 1st dimension as replicate
observations = cat(cat(hcat([1.9, 1.8, 1.6, 1.4], [1.8, 1.7, 1.4, 1.5]),
                       hcat([2.3, 2.1, 2.0, 2.6], [2.4, 2.7, 2.4, 2.6]),
                       hcat([2.9, 2.8, 3.4, 3.2], [3.0, 3.1, 3.0, 2.7]), dims = 3),
                   cat(hcat([2.1, 2.0, 1.8, 2.2], [2.3, 2.0, 1.9, 1.7]),
                       hcat([2.4, 2.6, 2.7, 2.3], [2.0, 2.3, 2.1, 2.4]),
                       hcat([3.6, 3.1, 3.4, 3.2], [3.1, 3.0, 2.8, 3.2]), dims = 3),
                   cat(hcat([1.1, 1.2, 1.0, 1.4], [1.4, 1.0, 1.3, 1.2]),
                       hcat([2.0, 2.1, 1.9, 2.2], [2.4, 2.6, 2.3, 2.2]),
                       hcat([2.9, 2.8, 3.0, 3.1], [3.2, 2.9, 2.8, 2.9]), dims = 3), dims = 4)

Factor A      1                             2                             3
Factor B      1         2         3         1         2         3         1         2         3
Factor C      1    2    1    2    1    2    1    2    1    2    1    2    1    2    1    2    1    2
            1.9  1.8  2.3  2.4  2.9  3.0  2.1  2.3  2.4  2.0  3.6  3.1  1.1  1.4  2.0  2.4  2.9  3.2
            1.8  1.7  2.1  2.7  2.8  3.1  2.0  2.0  2.6  2.3  3.1  3.0  1.2  1.0  2.1  2.6  2.8  2.9
            1.6  1.4  2.0  2.4  3.4  3.0  1.8  1.9  2.7  2.1  3.4  2.8  1.0  1.3  1.9  2.3  3.0  2.8
            1.4  1.5  2.6  2.6  3.2  2.7  2.2  1.7  2.3  2.4  3.2  3.2  1.4  1.2  2.2  2.2  3.1  2.9

Factor Types                                 FFF   FFR   FRF   RFF   FRR   RFR   RRF   RRR
                            SS    DF    MS     F     F     F     F     F     F     F     F
Total                     30.4    71
Cells                     28.4    17
    Factors
        Factor A           1.8     2   0.9  24.5   4.9   3.3  24.5   3.3   4.9   2.2   2.2
        Factor B          24.7     2  12.3   332   141   332  44.8  44.8  40.0   141  40.0
        Factor C          9e-3     1  9e-3   0.2   0.2   0.1  5e-2  4e-2  5e-2   0.1  5e-2
    All Interactions
        Pair Interactions
            Factor AxB     1.1     4   0.3   7.4   5.0   7.4   7.4   7.4   5.0   5.0   5.0
            Factor AxC     0.4     2   0.2   5.0   5.0   3.4   5.0   3.4   5.0   3.4   3.4
            Factor BxC     0.2     2  9e-2   2.4   2.4   2.4   1.6   1.6   1.6   2.4   1.6
        Factor AxBxC       0.2     4  6e-2   1.5   1.5   1.5   1.5   1.5   1.5   1.5   1.5
Error                      2.0    54  4e-2

Currently only works for 1-way, 2-way, and 3-way ANOVAs
Next: expand to fully nested 2-way ANOVAs
=#

function validate(factortypes::Vector{FactorType}, ndims; noreplicates = false)
    length(factortypes) == ndims || throw(ErrorException("factortypes must have an entry for each factor."))
    if noreplicates
        replicate ∉ factortypes || throw(ErrorException("replicates are not valid for this structure."))
    else
        replicate ∉ factortypes || first(factortypes) == replicate || throw(ErrorException("replicate must be the first entry if present"))
    end
    factortypes = filter(t -> t ≠ replicate, factortypes)
    nested ∉ factortypes || length(unique(factortypes[1:count(t -> t == nested, factortypes)])) == 1 || throw(ErrorException("nested entries must come before crossed factors"))
end

function anova(observations::T, factortypes::Vector{FactorType} = [fixed]) where {T <: AbstractArray{<:Number}}
    length(observations) > 0 || return
    validate(factortypes, ndims(observations))
    firstlevelreplicates = first(factortypes) == replicate

    nfactors = ndims(observations) - (firstlevelreplicates ? 1 : 0)
    nreplicates = firstlevelreplicates ? size(observations, 1) : length(observations[1])
    ncells = Int.(length(observations) / (firstlevelreplicates ? nreplicates : 1))
    nfactorlevels = firstlevelreplicates ? [size(observations)...][Not(1)] : [size(observations)...]

    anovakernel(observations, nreplicates, ncells, nfactors, nfactorlevels, factortypes)
end

function anova(observations::T, factortypes::Vector{FactorType} = [fixed]) where {T <: AbstractArray{<:AbstractVector{<:Number}}}
    length(observations) > 0 || return
    validate(factortypes, ndims(observations), noreplicates = true)

    nfactors = ndims(observations)
    nreplicates = length(observations[1])
    nreplicates > 0 || return
    all(c -> length(c) == nreplicates, observations) || throw(ErrorException("All cells must have the same number of replicates."))
    ncells = length(observations)
    nfactorlevels = [size(observations)...]

    anovakernel(observations, nreplicates, ncells, nfactors, nfactorlevels, factortypes)
end

function factorscalc(cellsums, nfactors, nfactorlevels, N, C)
    factorindices = 1:nfactors
    ss = map(i -> sum(sum(cellsums, dims = factorindices[Not(i)]) .^ 2) / (N / nfactorlevels[i]), factorindices) .- C
    df = nfactorlevels .- 1
    AnovaFactor.(ss, df)
end

function cellscalc(cellsums, nreplicates, ncells, C)
    ss = sum(cellsums .^ 2) / nreplicates - C
    df = ncells - 1
    AnovaValue(ss, df)
end

function totalcalc(observations, N, C)
    ss = sum(c -> sum(c.^2), observations) - C
    df = N - 1
    AnovaValue(ss, df)
end

function errorcalc(total, cells, nfactorlevels, nreplicates)
    ss = total.ss - cells.ss
    df = prod(nfactorlevels) * (nreplicates - 1)
    AnovaFactor(ss, df)
end

function remaindercalc(total, factors)
    ss = total.ss - sum(f -> f.ss, factors)
    df = prod(f -> f.df, factors)
    AnovaFactor(ss,df)
end

#=
function pairwiseinteractionscalc(cells, factors)
    factors_ss = map(f -> f.ss, factors)
    factors_df = map(f -> f.df, factors)

    ss = cells.ss .- (factors_ss .+ factors_ss')  # symmetric matrix of interaction terms, diagonal is meaningless
    df = factors_df .* factors_df'
    AnovaFactor.(ss, df)
end

function threewiseinteractionscalc(cells, factors)
    factors_ss = map(f -> f.ss, factors)
    factors_df = map(f -> f.df, factors)

    ss = cells.ss .- (factors_ss .+ factors_ss' .+ reshape(factors_ss, (1,1,3)))  # symmetric matrix of interaction terms, diagonal is meaningless
    df = factors_df .* factors_df' .* reshape(factors_df, (1,1,3))
    AnovaFactor.(ss, df)
end
=#

function calccellsums(observations::T, nfactors, nfactorlevels) where {T <: AbstractArray{<:AbstractVector{<:Number}}}
    map(c -> sum(c), observations)
end

function calccellsums(observations::T, nfactors, nfactorlevels) where {T <: AbstractArray{<:Number}}
    ndims(observations) > nfactors || return observations
    reshape(sum(observations, dims = 1), (nfactorlevels...))
end

function nestedfactorscalc(cellsums, nfactorlevels, C)
    nestedsums = cellsums
    nlowerfactorlevels = 1
    nupperfactorlevels = nfactorlevels
    amongallnested = Vector{AnovaValue}(undef, nnestedfactors)
    for i ∈ 1:nnestedfactors
        # collapse each nested factor

        amongallnestedSS = sum(nestedsums .^ 2 ./ (nreplicates * prod(nlowerfactorlevels))) - C
        amongallnestedDF = prod(nupperfactorlevels) - 1

        amongallnested[i] = AnovaValue(amongallnestedSS, amongallnestedDF)

        nlowerfactorlevels = nfactorlevels[1:i]
        nupperfactorlevels = nfactorlevels[(i+1):end]
        nestedsums = reshape(sum(nestedsums, dims = 1), (nupperfactorlevels...))
    end

    amongallnested, nestedsums, nupperfactorlevels
end

#=
function anovanestedkernel(observations, nreplicates, ncells, nnestedfactors, ncrossedfactors, nfactorlevels, factortypes)
    N = ncells * nreplicates

    # collapse replicate dimension
    cellsums = calccellsums(observations, nfactors, nfactorlevels)

    C = sum(cellsums) ^ 2 / N

    total = totalcalc(observations, N, C)

    amongallnested, nestedsums, nupperfactorlevels = nestedfactorscalc(cellsums, nfactorlevels, C)

    #errorSS = total.ss - amongallnested[1].ss
    #errorDF = total.df - amongallnested[1].df
    error = errorcalc(total, amongallnested[1], nfactorlevels, nreplicates)

    crossedfactors = factorscalc(nestedsums, ncrossedfactors, nupperfactorlevels, N, C)

    #for one factor and one nested only
    nestedss = amongallnested[1].ss - crossedfactors[1].ss
    nesteddf = amongallnested[1].df - crossedfactors[1].df
    nested = AnovaFactor(nestedss, nesteddf)

    if ncrossedfactors > 1
        cells = cellscalc(cellsums, nreplicates, ncells, C)
        #error = errorcalc(total, cells, nfactorlevels, nreplicates)
        pairwiseinteractions = pairwiseinteractionscalc(cells, factors)
        if ncrossedfactors > 2
            threewiseinteractions = threewiseinteractionscalc(cells, factors)
        end

        # not yet considering the interaction term denominators
        if ncrossedfactors == 2
            if all(f -> f == fixed, factortypes)
                denominators = repeat([nested[end]], nfactors)
            else if all(f -> f == random, factortypes)
                denominators = repeat([pairwiseinteractions[1,2]], nfactors)
            else
                denominators = map(f -> f == fixed ? nested[end] : pairwiseinteractions[1,2], factortypes)
            end

            interactions = [pairwiseinteractions[1,2]]
            interactionsdenominators = nested[end]
        else if ncrossedfactors == 3
            interactions = [pairwiseinteractions[1,2], pairwiseinteractions[1,3], pairwiseinteractions[2,3], threewiseinteractions[1,2]]

            if all(f -> f == fixed, factortypes)
                denominators = repeat([nested[end]], nfactors)
                pairwiseinteractiondenominators = repeat([nested[end]], nfactors)
                threewiseinteractiondenominators = nested[end]
            else if all(f -> f == random, factortypes)
                denominators = Vector{AnovaFactor}(undef, nfactors)
                for i ∈ 1:nfactors
                    otherfactors = (1:nfactors)[Not(i)]
                    j = otherfactors[1]
                    k = otherfactors[2]
                    denominators[i] = threewayinteraction(pairwiseinteractions[i,j], pairwiseinteractions[i,k], threewiseinteractions[i,j,k])
                end
                pairwiseinteractiondenominators = repeat([threewiseinteractions[i,j,k]], nfactors)
            else if count(f -> f == random, factortypes) == 1
                i = findfirst(f -> f == random, factortypes)

                denominators[i] = nested[end]

                fixedindexes = (1:nfactors)[Not(i)]
                for j ∈ fixedindexes
                    denominators[j] = pairwiseinteractions[i,j]
                end

                fixedinteractionindex = sum(fixedindexes) - 2
                pairwiseinteractiondenominators = Vector{AnovaFactor}(undef, nfactors)
                pairwiseinteractiondenominators[fixedinteractionindex] = threewiseinteractions[i,j,k]
                pairwiseinteractiondenominators[Not(fixedinteractionindex)] .= nested[end]
            else if count(f -> f == random, factortypes) == 2
                i = findfirst(f -> f == fixed, factortypes)
                otherfactors = (1:nfactors)[Not(i)]
                j = otherfactors[1]
                k = otherfactors[2]

                denominators[i] = threewayinteraction(pairwiseinteractions[i,j], pairwiseinteractions[i,k], threewiseinteractions[i,j,k])
                denominators[otherfactors] .= pairwiseinteractions[j,k]

                ranodminteractionindex = sum(otherfactors) - 2
                pairwiseinteractiondenominators = Vector{AnovaFactor}(undef, nfactors)
                pairwiseinteractiondenominators[randominteractionindex] = nested[end]
                pairwiseinteractiondenominators[Not(randominteractionindex)] .= threewiseinteractions[i,j,k]
            end

            threewiseinteractiondenominators = nested[end]
            interactionsdenominators = [pairwiseinteractiondenominators, threewiseinteractiondenominators]
        else if ncrossedfactors >= 4
            throw(ErrorException("ANOVA with 4 or more crossed factors is not supported.")
        end

        nesteddenominators = Vector{AnovaFactor}(undef, nnestedfactors)
        nesteddenominators[1] = error
        for i ∈ 2:nnestedfactors
            nesteddenominators[i] = nested[i - 1]
        end

        f, p = ftest.([crossedfactors, interactions, nested], [crosseddenominators, interactionsdenominators, nesteddenominators])
    else if nnestedfactors > 1
        crossedfactor = crossedfactors[1]
        nesteddenominators = Vector{AnovaFactor}(undef, nnestedfactors)
        nesteddenominators[1] = error
        for i ∈ 2:nnestedfactors
            nesteddenominators[i] = nested[i - 1]
        end

        f, p = ftest.([crossedfactor, nested], [nested[end], nesteddenominators])
    else
        crossedfactor = crossedfactors[1]
        f, p = ftest.([crossedfactor, nested[1]], [nested[end], error])
    end
end
=#

#Nested varies from crossed in that the highest-level nested factor takes the place of the error term as a denominator for the crossed values


function threewayinteraction(interaction_ab, interaction_bc, interaction_abc)
    reducedmeansquare(factor::AnovaFactor) = factor.ms ^ 2 / factor.df

    ms = interaction_ab.ms + interaction_bc.ms - interaction_abc.ms
    df = ms ^ 2 / (reducedmeansquare(interaction_ab) + reducedmeansquare(interaction_bc) + reducedmeansquare(interaction_abc))
    AnovaFactor(ms * df, df, ms)
end

function anovakernel(observations, nreplicates, ncells, nfactors, nfactorlevels, factortypes)
    N = ncells * nreplicates

    factortypes = filter(f -> f ≠ replicate, factortypes)

    # collapse replicate dimension
    cellsums = calccellsums(observations, nfactors, nfactorlevels)

    C = sum(cellsums) ^ 2 / N

    total = totalcalc(observations, N, C)
    factors = factorscalc(cellsums, nfactors, nfactorlevels, N, C)

    if nreplicates > 1
        if nfactors == 1
            factor = factors[1]
            error = errorcalc(total, factor, nfactorlevels, nreplicates)
            f, p = ftest(factor, error)
        elseif nfactors > 1
            cells = cellscalc(cellsums, nreplicates, ncells, C)
            error = errorcalc(total, cells, nfactorlevels, nreplicates)

            # not yet considering the interaction term denominators
            if nfactors == 2
                pairwisess = Array{Float64,2}(undef, nfactors, nfactors)
                pairwisess[1,2] = pairwisess[2,1] = cells.ss - factors[1].ss - factors[2].ss
                pairwisedf[1,2] = pairwisedf[2,1] = factors[2].df * factors[2].df

                pairwiseinteractions = [AnovaFactor(pairwisess[1,2], pairwisedf[1,2])]

                if all(f -> f == fixed, factortypes)
                    denominators = repeat([error], nfactors)
                elseif all(f -> f == random, factortypes)
                    denominators = repeat([pairwiseinteractions], nfactors)
                else
                    denominators = map(f -> f == fixed ? error : pairwiseinteractions, factortypes)
                end

                interactions = pairwiseinteractions
                interactionsdenominators = error

            elseif nfactors == 3
                pairwisess = Array{Float64,2}(undef, nfactors, nfactors)
                pairwisess[1,2] = pairwisess[2,1] = sum(sum(cellsums, dims = 3) .^ 2 ./ (nfactorlevels[3] * nreplicates)) - C - factors[1].ss - factors[2].ss
                pairwisess[1,3] = pairwisess[3,1] = sum(sum(cellsums, dims = 2) .^ 2 ./ (nfactorlevels[2] * nreplicates)) - C - factors[1].ss - factors[3].ss
                pairwisess[2,3] = pairwisess[3,2] = sum(sum(cellsums, dims = 1) .^ 2 ./ (nfactorlevels[1] * nreplicates)) - C - factors[2].ss - factors[3].ss
                pairwisedf = Array{Float64,2}(undef, nfactors, nfactors)
                pairwisedf[1,2] = pairwisedf[2,1] = factors[1].df * factors[2].df
                pairwisedf[1,3] = pairwisedf[3,1] = factors[1].df * factors[3].df
                pairwisedf[2,3] = pairwisedf[3,2] = factors[2].df * factors[3].df

                pairwiseinteractions = [undef AnovaFactor(pairwisess[1,2], pairwisedf[1,2]) AnovaFactor(pairwisess[1,3], pairwisedf[1,3]);
                                        AnovaFactor(pairwisess[1,2], pairwisedf[1,2]) undef AnovaFactor(pairwisess[2,3], pairwisedf[2,3]);
                                        AnovaFactor(pairwisess[1,3], pairwisedf[1,3]) AnovaFactor(pairwisess[2,3], pairwisedf[2,3]) undef]

                threewisess = cells.ss - sum(f -> f.ss, factors) - pairwisess[1,2] - pairwisess[1,3] - pairwisess[2,3]
                threewisedf = prod(f -> f.df, factors)

                threewiseinteractions = AnovaFactor(threewisess, threewisedf)

                interactions = [AnovaFactor(pairwisess[1,2], pairwisedf[1,2]), AnovaFactor(pairwisess[1,3], pairwisedf[1,3]), AnovaFactor(pairwisess[2,3], pairwisedf[2,3]), AnovaFactor(threewisess, threewisedf)]

                if all(f -> f == fixed, factortypes)
                    denominators = repeat([error], nfactors)
                    pairwiseinteractiondenominators = repeat([error], nfactors)
                elseif all(f -> f == random, factortypes)
                    denominators = Vector{AnovaFactor}(undef, nfactors)
                    for i ∈ 1:nfactors
                        otherfactors = (1:nfactors)[Not(i)]
                        j = otherfactors[1]
                        k = otherfactors[2]
                        denominators[i] = threewayinteraction(pairwiseinteractions[i,j], pairwiseinteractions[i,k], threewiseinteractions)
                    end
                    pairwiseinteractiondenominators = repeat([threewiseinteractions], nfactors)
                elseif count(f -> f == random, factortypes) == 1
                    i = findfirst(f -> f == random, factortypes)

                    denominators = Vector{AnovaFactor}(undef, nfactors)
                    denominators[i] = error

                    fixedindexes = (1:nfactors)[Not(i)]
                    for j ∈ fixedindexes
                        denominators[j] = pairwiseinteractions[i,j]
                    end

                    fixedinteractionindex = sum(fixedindexes) - 2
                    pairwiseinteractiondenominators = Vector{AnovaFactor}(undef, nfactors)
                    pairwiseinteractiondenominators[fixedinteractionindex] = threewiseinteractions
                    pairwiseinteractiondenominators[Not(fixedinteractionindex)] .= error
                elseif count(f -> f == random, factortypes) == 2
                    i = findfirst(f -> f == fixed, factortypes)
                    otherfactors = (1:nfactors)[Not(i)]
                    j = otherfactors[1]
                    k = otherfactors[2]

                    denominators = Vector{AnovaFactor}(undef, nfactors)
                    denominators[i] = threewayinteraction(pairwiseinteractions[i,j], pairwiseinteractions[i,k], threewiseinteractions)
                    denominators[otherfactors] .= pairwiseinteractions[j,k]

                    randominteractionindex = sum(otherfactors) - 2
                    pairwiseinteractiondenominators = Vector{AnovaFactor}(undef, nfactors)
                    pairwiseinteractiondenominators[randominteractionindex] = error
                    pairwiseinteractiondenominators[Not(randominteractionindex)] .= threewiseinteractions
                end

                threewiseinteractiondenominators = error
                interactionsdenominators = [pairwiseinteractiondenominators; threewiseinteractiondenominators]
            elseif nfactors >= 4
                throw(ErrorException("ANOVA with 4 or more crossed factors is not supported."))
            end

            f, p = ftest.([factors; interactions], [denominators; interactionsdenominators])
        end
    else
        remainder = remaindercalc(total, factors)

        f, p = ftest.(factors, Ref(remainder))
    end
end

export anova, FactorType

end
