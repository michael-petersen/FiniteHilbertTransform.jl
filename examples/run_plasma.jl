#=
An example call:

julia --threads 4 run_plasma.jl --Cmode chebyshev --linear damped --parallel 1 --K_u 200 --nOmega 801 --nEta 300 --xmax 20

julia --threads 4 run_plasma.jl --Cmode legendre --parallel 1 --K_u 205 --nOmega 801 --nEta 300 --xmax 20 --Omegamin -4.0 --Omegamax 4.0 --Etamin -3.0 --Etamax 0.0

julia --threads 4 run_plasma.jl --Cmode chebyshev --parallel 1 --K_u 205 --nOmega 801 --nEta 300 --xmax 20 --Omegamin -4.0 --Omegamax 4.0 --Etamin -3.0 --Etamax 0.0

julia --threads 4 run_plasma.jl --Cmode legendre --parallel 1 --K_u 205 --nOmega 801 --nEta 300 --xmax 20 --Omegamin -4.0 --Omegamax 4.0 --Etamin 0.0 --Etamax 3.0

=#

using FiniteHilbertTransform

include("PlasmaModel.jl")

using ArgParse

function parse_commandline()
    #=parse_commandline

    parse command line arguments.
    use --help to see the defaults
    =#
    tabargs = ArgParseSettings()

    @add_arg_table tabargs begin
        "--parallel"
            help     = "Parallel computation: true/false"
            arg_type = Bool
            default  = true
        "--K_u"
            help     = "Number of nodes in the Gauss-Legendre quadrature"
            arg_type = Int64
            default  = 200
        "--qSELF"
            help     = "Self-gravity strength: q < 1 for stable"
            arg_type = Float64
            default  = 0.5
        "--xmax"
            help     = "Truncation range of the velocity range"
            arg_type = Float64
            default  = 5.0
        "--verbose"
            help     = "Set the report flag (larger gives more report)"
            arg_type = Int64
            default  = 1
        "--nOmega"
            help     = "Number of real points to compute"
            arg_type = Int64
            default  = 801
        "--Omegamin"
            help     = "Minimum real frequency"
            arg_type = Float64
            default  = -4.0
        "--Omegamax"
            help     = "Maximum real frequency"
            arg_type = Float64
            default  = 4.0
        "--nEta"
            help     = "Number of imaginary points to compute"
            arg_type = Int64
            default  = 300
        "--Etamin"
            help     = "Minimum imaginary frequency"
            arg_type = Float64
            default  = -3.0
        "--Etamax"
            help     = "Maximum imaginary frequency"
            arg_type = Float64
            default  = -0.01
        "--Cmode"
            help     = "Continuation mode for damped calculation (legendre/chebyshev,rational)"
            arg_type = String
            default  = "legendre"
    end

    return parse_args(tabargs)
end

function print_arguments(parsed_args)
    println("Parsed args:")
    for (arg,val) in parsed_args
        println("  $arg  =>  $val")
    end
end




function get_tabomega(tabOmega::Vector{Float64},tabEta::Vector{Float64})
    #=get_tabomega

    construct the table of omega values (complex frequency) from the specified real and imaginary components.

    =#

    nOmega = size(tabOmega,1)
    nEta   = size(tabEta,1)
    nomega = nOmega*nEta

    tabomega = zeros(Complex{Float64},nomega)
    icount = 1 # Initialising the counter
    #####
    for iOmega=1:nOmega # Loop over the real part of the frequency
        for iEta=1:nEta # Loop over the complex part of the frequency
            tabomega[icount] = tabOmega[iOmega] + im*tabEta[iEta] # Fill the current value of the complex frequency
            icount += 1 # Update the counter
        end
    end

    return tabomega
end



function main()

    # get the parsed arguments
    parsed_args = parse_commandline()

    if parsed_args["verbose"] > 0
        print_arguments(parsed_args)
    end

    PARALLEL = parsed_args["parallel"]
    qself    = parsed_args["qSELF"]
    xmax     = parsed_args["xmax"]
    K_u      = parsed_args["K_u"]


    if (PARALLEL)
        nb_threads = Threads.nthreads() # Total number of threads for parallel runs
        println("Using $nb_threads threads.")
    end

    # set up the array of frequencies
    tabOmega = collect(range(parsed_args["Omegamin"],parsed_args["Omegamax"],length=parsed_args["nOmega"]))
    tabEta = collect(range(parsed_args["Etamin"],parsed_args["Etamax"],length=parsed_args["nEta"]))
    nomega = parsed_args["nOmega"]*parsed_args["nEta"] # Total number of complex frequencies for which the dispersion function is computed.

    # (flat) array of omega values to check
    tabomega = get_tabomega(tabOmega,tabEta)

    if parsed_args["Cmode"] == "chebyshev"
        taba = setup_chebyshev_integration(K_u,qself,xmax,PARALLEL)
        #test_ninepoints(taba)
        #println(taba)
        @time tabIminusXi = ComputeIminusXi(tabomega,taba,xmax)
    end

    if parsed_args["Cmode"] == "legendre"
        taba,struct_tabLeg = setup_legendre_integration(K_u,qself,xmax,PARALLEL)
        #test_ninepoints()
        #println(taba)
        @time tabIminusXi = ComputeIminusXi(tabomega,taba,xmax,struct_tabLeg)
    end


    # Prefix of the directory where the files are dumped
    prefixnamefile = "examples/data/"

    # Name of the file where the data is dumped
    namefile = prefixnamefile*"data_"*parsed_args["Cmode"]*"_Plasma_Ku_"*string(K_u)*
               "_qSELF_"*string(qself)*"_xmax_"*string(xmax)*".hf5"

    print("Dumping the data | ")
    @time FiniteHilbertTransform.dump_tabIminusXi(namefile,tabomega,tabIminusXi) # Dumping the values of det[I-Xi]

end

main()
