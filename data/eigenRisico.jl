using CSV
using DataFrames
using Plots
using Statistics


###Data Set

# Raw data from http://www.vektis.nl/index.php/vektis-open-data

# minimum deductible 2011 for people aged above 18: 170 Euro
df11orig = CSV.read("Vektis Open Databestand Zorgverzekeringswet 2011 - postcode3.csv",delim=";")

# minimum deductible 2014 for people aged above 18: 360 Euro
df14orig = CSV.read("Vektis Open Databestand Zorgverzekeringswet 2014 - postcode3.csv",delim=";")



function get_data_into_shape(df)
    cost_categories_under_deductible = [:KOSTEN_MEDISCH_SPECIALISTISCHE_ZORG, :KOSTEN_MONDZORG, :KOSTEN_FARMACIE, :KOSTEN_HULPMIDDELEN, :KOSTEN_PARAMEDISCHE_ZORG_FYSIOTHERAPIE, :KOSTEN_PARAMEDISCHE_ZORG_OVERIG, :KOSTEN_ZIEKENVERVOER_ZITTEND, :KOSTEN_ZIEKENVERVOER_LIGGEND, :KOSTEN_GRENSOVERSCHRIJDENDE_ZORG, :KOSTEN_OVERIG]
    df.costsUnderDeductible = sum([df[:,cost] for cost in cost_categories_under_deductible])
    dfOut = df[:,[:GESLACHT,:LEEFTIJDSKLASSE,:POSTCODE_3,:AANTAL_BSN,:AANTAL_VERZEKERDEJAREN,:costsUnderDeductible]]
    dfOut = dfOut[2:end,:] #drop first line which contains aggregated information
    rename!(dfOut,Dict(:GESLACHT=>:sex,:LEEFTIJDSKLASSE=>:age,:AANTAL_BSN=>:number_citizens,:AANTAL_VERZEKERDEJAREN=>:citizenYears))
    dfOut.costsPerHeadUnderDeductible=dfOut[:,:costsUnderDeductible]./dfOut[:,:citizenYears]
    dfOut.logCostsPerHeadUnderDeductible = log.(dfOut[:,:costsPerHeadUnderDeductible])
    return dfOut
end


df11 = get_data_into_shape(df11orig)
df14 = get_data_into_shape(df14orig)

CSV.write("data2011.csv",df11)
CSV.write("data2014.csv",df14)


###Analysis

#Number of insured in the Netherlands
println(sum(df11.number_citizens))
sum(df11.citizenYears)

#Age vs cost plot
plot(0:89,[mean(df11[(df11[:,:age].==string(age))  .& isfinite.(df11[:,:costsPerHeadUnderDeductible]),:costsPerHeadUnderDeductible]) for age in 0:89],label="Costs per contribution year, 2011",xlabel="age")
savefig("ageCosts11.png")
#plot!(0:89,[mean(df14[(df14[:,:age].==string(age)).& isfinite.(df14[:,:costsPerHeadUnderDeductible]),:costsPerHeadUnderDeductible]) for age in 0:89],label=" Log(costs per contribution year), 2014",xlabel="age")

#Histograms
histogram(df11[(df11[:,:age].=="17").& isfinite.(df11[:,:logCostsPerHeadUnderDeductible]),:logCostsPerHeadUnderDeductible],label="2011, age 17",alpha=0.5,normed=true,title="Distribution Log(costs per contribution year)  2011")
histogram!(df11[(df11[:,:age].=="19").& isfinite.(df11[:,:logCostsPerHeadUnderDeductible]),:logCostsPerHeadUnderDeductible],label="2011, age 19",alpha=0.5,normed=true)
#savefig("histogram11.png")

#histogram(df14[(df14[:,:age].=="17").& isfinite.(df14[:,:logCostsPerHeadUnderDeductible]),:logCostsPerHeadUnderDeductible],label="2014, age 17",alpha=0.5,normed=true,title="Distribution Log(costs per contribution year) 2014")
#histogram!(df14[(df14[:,:age].=="19") .& isfinite.(df14[:,:logCostsPerHeadUnderDeductible]),:logCostsPerHeadUnderDeductible],label="2014, age 19",alpha=0.5,normed=true)


# Average costs
println("Mean costs for 2011, age 17: ",mean(df11[df11[:,:age].=="17",:costsPerHeadUnderDeductible]))
println("Mean costs for 2011, age 19: ",mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))
println("Mean costs for 2014, age 17: ",mean(df14[df14[:,:age].=="17",:costsPerHeadUnderDeductible]))
println("Mean costs for 2014, age 19: ",mean(df14[df14[:,:age].=="19",:costsPerHeadUnderDeductible]))
println("Percentage increase in mean cost between age 19 and 17, 2011: ",100*(mean(df11[df11[:,:age].=="17",:costsPerHeadUnderDeductible])-mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))/mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]),"%" )
println("Percentage increase in mean cost between age 19 and 17, 2014: ",100*(mean(df14[df14[:,:age].=="17",:costsPerHeadUnderDeductible])-mean(df14[df14[:,:age].=="19",:costsPerHeadUnderDeductible]))/mean(df14[df14[:,:age].=="19",:costsPerHeadUnderDeductible]),"%" )

#Estimate of elasticity
relIncreaseDeductible=(360-170)/170
relIncreaseCosts = (mean(df14[df14[:,:age].=="19",:costsPerHeadUnderDeductible])-mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))/(mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))
relIncreaseCosts = (mean(df14[df14[:,:age].=="19",:costsPerHeadUnderDeductible])-mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))/(mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))
println("(Bad!) estimate for cost reduction if deductible is increased by 100% is ",round(-100*relIncreaseCosts/relIncreaseDeductible,digits=2),"% or ",) #estimate suggests the opposite of moral hazard but the reason is that we did not take into account that health care costs have risen over time, we need a "deflator" to adjust 2014 costs to 2011 levels! I will use the cost increase of kids aged between 1 and 17 as deflator as they were not affected by the deductible

deflator = 1+(-mean([mean(df11[(df11[:,:age].==string(age)) ,:costsPerHeadUnderDeductible]) for age in 1:17])+mean([mean(df14[(df14[:,:age].==string(age)) ,:costsPerHeadUnderDeductible]) for age in 1:17]))/mean([mean(df11[(df11[:,:age].==string(age)) ,:costsPerHeadUnderDeductible]) for age in 1:17])

println("deflator = ",deflator)

relIncreaseCostsDeflated = (mean(df14[df14[:,:age].=="19",:costsPerHeadUnderDeductible])/deflator-mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))/(mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))
println("Rough estimate for cost reduction if deductible is increased by 100% is ",round(-100*relIncreaseCostsDeflated/relIncreaseDeductible,digits=2),"%")

#Comaprison to RAND
println("average cost for 19 year old, 2011 is ", mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]))
println("190 is ",round(100*190/mean(df11[df11[:,:age].=="19",:costsPerHeadUnderDeductible]),digits=2) ,"% of this average cost")
println("relative deflated decrease in the cost of 19 year olds is ",-100*relIncreaseCostsDeflated,"%")
