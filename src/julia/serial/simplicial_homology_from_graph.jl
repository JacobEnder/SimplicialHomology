include("homology.jl")
include("cycle_detection.jl")
include("preprocess.jl")

using JSON3
using .CycleDetection


# Calculate H0 
function calculate_h0(vertices, adj; mod_2=false)
    reduced_vertices, reduced_adj = preprocess(adj)
    X, A = build_simplicial_complex(reduced_vertices, reduced_adj)
    
    if !mod_2
        return homology(0, A)
    else
        return homology(0, A, mod_2=true)
    end
end

# Calculate H1 
function calculate_h1(vertices, adj; mod_2=false)
    reduced_vertices, reduced_adj = preprocess(adj)
    X, A = build_simplicial_complex(reduced_vertices, reduced_adj)
    
    if !mod_2
        return homology(1, A)
    else
        return homology(1, A, mod_2=true)
    end
end

# Load the JSON file containing all our graphs
function load_graphs(filename="graphs.json")
    base_dir = dirname(@__FILE__)
    path = joinpath(base_dir, "..", "..", "..", "data", filename)  # Graphs are stored in /data/graphs.json by default
    
    return JSON3.read(read(path, String))
end

function run()
    # Field selection
    println("Compute homology over Q or Z/2? (q/2): ")
    input_str = strip(lowercase(readline()))
    mod_2 = input_str == "2"
    
    #"erdos_renyi_graphs.json"
    graphs = load_graphs("erdos_renyi_graphs.json")

    # Pull all the graphs from /data/graphs.json, calculate their homology and benchmark the times
    for graph in graphs
        name = get(graph, "name", "Unnamed Graph")
        vertices = graph["vertices"]
        
        # Fix type consistency: convert everything to strings
        vertices_str = String.(vertices)
        adj_raw = Dict(k => v for (k, v) in graph["adjacency_list"])
        adj = Dict(String(k) => String.(v) for (k, v) in adj_raw)

        println("Graph: $name")
        
        # Calculate H0 with timing
        start_time_h0 = time()
        H0 = calculate_h0(vertices_str, adj, mod_2=mod_2)
        elapsed_h0 = round(time() - start_time_h0, digits=15)
        
        # Calculate H1 with timing
        start_time_h1 = time()
        H1 = calculate_h1(vertices_str, adj, mod_2=mod_2)
        elapsed_h1 = round(time() - start_time_h1, digits=15)
        
        println("H0: $H0")
        println("H0 Time: $elapsed_h0 sec")
        println("H1: $H1")
        println("H1 Time: $elapsed_h1 sec")
        println("Total Time: $(round(elapsed_h0 + elapsed_h1, digits=15)) sec\n")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run()
end