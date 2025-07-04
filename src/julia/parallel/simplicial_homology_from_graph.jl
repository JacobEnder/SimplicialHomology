include("homology.jl")
include("cycle_detection.jl")
include("preprocess.jl")

using JSON3

# Take our graph G, build a simplicial complex (X, A) over it, and calculate the homology of (X,A)
# over the user's choice of Q or Z/2
function homology_from_graph(vertices, adj; mod_2=false)
    reduced_vertices, reduced_adj = preprocess(adj)

    # Build a simplicial complex associated to G
    X, A = build_simplicial_complex(reduced_vertices, reduced_adj)

    # Two different fields of coefficients
    if !mod_2
        return (
            homology(0, A),
            homology(1, A),
        )
    else
        return (
            homology(0, A, mod_2=true),
            homology(1, A, mod_2=true),
        )
    end
end

# Load the JSON file containing all our graphs
function load_graphs(filename="graphs.json")
    base_dir = dirname(@__FILE__)
    path = joinpath(base_dir, "..", "..", "..", "data", filename)  # Graphs are stored in /data/graphs.json by default
    
    return JSON3.read(read(path, String))
end

function run()
    # Display threading info
    println("Running with $(Threads.nthreads()) threads")
    
    # Field selection
    println("Compute homology over Q or Z/2? (q/2): ")
    input_str = strip(lowercase(readline()))
    mod_2 = input_str == "2"
    
    graphs = load_graphs()

    # Process graphs in parallel when there are multiple graphs
    if length(graphs) > 1 && Threads.nthreads() > 1
        println("Processing $(length(graphs)) graphs in parallel...\n")
        
        # Pre-allocate results
        results = Vector{Any}(undef, length(graphs))
        
        Threads.@threads for i in 1:length(graphs)
            graph = graphs[i]
            name = get(graph, "name", "Unnamed Graph $i")
            vertices = graph["vertices"]
            
            # Fix type consistency: convert everything to strings
            vertices_str = String.(vertices)
            adj_raw = Dict(k => v for (k, v) in graph["adjacency_list"])
            adj = Dict(String(k) => String.(v) for (k, v) in adj_raw)

            start_time = time()
            H0, H1 = homology_from_graph(vertices_str, adj, mod_2=mod_2)
            elapsed = round(time() - start_time, digits=15)
            
            results[i] = (name, H0, H1, elapsed)
        end
        
        # Print results in order
        for (name, H0, H1, elapsed) in results
            println("Graph: $name")
            println("(H0, H1): $H0, $H1")
            println("Time: $elapsed sec\n")
        end
    else
        # Sequential processing for single graph or single thread
        for graph in graphs
            name = get(graph, "name", "Unnamed Graph")
            vertices = graph["vertices"]
            
            # Fix type consistency: convert everything to strings
            vertices_str = String.(vertices)
            adj_raw = Dict(k => v for (k, v) in graph["adjacency_list"])
            adj = Dict(String(k) => String.(v) for (k, v) in adj_raw)

            println("Graph: $name")
            start_time = time()
            H0, H1 = homology_from_graph(vertices_str, adj, mod_2=mod_2)
            elapsed = round(time() - start_time, digits=15)
            println("(H0, H1): $H0, $H1")
            println("Time: $elapsed sec\n")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run()
end