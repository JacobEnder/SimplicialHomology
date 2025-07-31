include("homology.jl")
include("cycle_detection.jl")
include("preprocess.jl")

using JSON3
using .CycleDetection
using Base.Threads

# Calculate H0 with memory management
function calculate_h0(vertices, adj; mod_2=false)
    try
        reduced_vertices, reduced_adj = preprocess(adj)
        X, A = build_simplicial_complex(reduced_vertices, reduced_adj)
        
        result = if !mod_2
            homology(0, A)
        else
            homology(0, A, mod_2=true)
        end
        
        # Force garbage collection to free memory
        X = nothing
        A = nothing
        reduced_vertices = nothing
        reduced_adj = nothing
        GC.gc()
        
        return result
    catch e
        if isa(e, OutOfMemoryError)
            println("Out of memory error in H0 calculation")
            return "OOM"
        else
            rethrow(e)
        end
    end
end

# Calculate H1 with memory management
function calculate_h1(vertices, adj; mod_2=false)
    try
        reduced_vertices, reduced_adj = preprocess(adj)
        X, A = build_simplicial_complex(reduced_vertices, reduced_adj)
        
        result = if !mod_2
            homology(1, A)
        else
            homology(1, A, mod_2=true)
        end
        
        # Force garbage collection to free memory
        X = nothing
        A = nothing
        reduced_vertices = nothing
        reduced_adj = nothing
        GC.gc()
        
        return result
    catch e
        if isa(e, OutOfMemoryError)
            println("Out of memory error in H1 calculation")
            return "OOM"
        else
            rethrow(e)
        end
    end
end

# Get the number of graphs without loading all data
function get_graph_count(filename="graphs.json")
    base_dir = dirname(@__FILE__)
    path = joinpath(base_dir, "..", "..", "..", "data", filename)
    
    # Read and parse just to count graphs
    data = JSON3.read(read(path, String))
    count = length(data)
    
    # Clear the data immediately
    data = nothing
    GC.gc()
    
    return count
end

# Load a single graph by index
function load_single_graph(filename, index)
    base_dir = dirname(@__FILE__)
    path = joinpath(base_dir, "..", "..", "..", "data", filename)
    
    # Read the file content
    content = read(path, String)
    data = JSON3.read(content)
    
    # Extract the specific graph
    if index <= length(data)
        graph = data[index]
        
        # Clear everything else from memory immediately
        data = nothing
        content = nothing
        GC.gc()
        
        return graph
    else
        data = nothing
        content = nothing
        GC.gc()
        return nothing
    end
end

# Check if a graph should be processed (size filtering)
function should_process_graph(graph, max_vertices=1000)
    vertices = graph["vertices"]
    return length(vertices) <= max_vertices
end

function run()
    # Field selection
    println("Compute homology over Q or Z/2? (q/2): ")
    input_str = "2"
    mod_2 = input_str == "2"
    
    println("Number of threads available: ", nthreads())
    
    filename = "erdos_renyi_graphs.json"
    total_graphs = get_graph_count(filename)
    println("Total graphs in file: $total_graphs")
    
    
    processed_count = 0
    skipped_count = 0
    results = []
    
    # Process graphs one at a time
    for i in 1:total_graphs
        # Load only this graph
        graph = load_single_graph(filename, i)
        
        if graph === nothing
            println("Error loading graph $i")
            continue
        end
        
        # Check if we should process this graph
        if !should_process_graph(graph)
            skipped_count += 1
            graph = nothing
            GC.gc()
            continue
        end
        
        processed_count += 1
        
        name = get(graph, "name", "Graph_$i")
        vertices = graph["vertices"]
        
        # Fix type consistency: convert everything to strings
        vertices_str = String.(vertices)
        adj_raw = Dict(k => v for (k, v) in graph["adjacency_list"])
        adj = Dict(String(k) => String.(v) for (k, v) in adj_raw)
        
        println("Processing graph $processed_count (index $i): $name ($(length(vertices_str)) vertices)")
        
        # Calculate H0 with timing
        start_time_h0 = time()
        H0 = calculate_h0(vertices_str, adj, mod_2=mod_2)
        elapsed_h0 = round(time() - start_time_h0, digits=15)
        
        # Clear intermediate data and force garbage collection
        vertices_str = nothing
        adj = nothing
        adj_raw = nothing
        vertices = nothing
        GC.gc()
        
        # Reload graph for H1 calculation (since we cleared the data)
        graph = load_single_graph(filename, i)
        vertices = graph["vertices"]
        vertices_str = String.(vertices)
        adj_raw = Dict(k => v for (k, v) in graph["adjacency_list"])
        adj = Dict(String(k) => String.(v) for (k, v) in adj_raw)
        
        # Calculate H1 with timing
        start_time_h1 = time()
        H1 = calculate_h1(vertices_str, adj, mod_2=mod_2)
        elapsed_h1 = round(time() - start_time_h1, digits=15)
        
        total_elapsed = round(elapsed_h0 + elapsed_h1, digits=15)
        
        # Store results
        push!(results, (name, H0, H1, elapsed_h0, elapsed_h1, total_elapsed))
        
        # Clear all graph data from memory
        graph = nothing
        vertices = nothing
        vertices_str = nothing
        adj = nothing
        adj_raw = nothing
        GC.gc()
        
        # Print progress
        println("  H0: $H0 ($(elapsed_h0)s)")
        println("  H1: $H1 ($(elapsed_h1)s)")
        println("  Total: $(total_elapsed)s")
        println("  Memory cleaned up\n")
        
        # Optional: Add a small delay to help with memory management
        sleep(0.1)
    end
    
    println("Processed: $processed_count graphs")
    println("Skipped (too large): $skipped_count graphs")
    
    # Print final summary
    println("="^50)
    println("FINAL RESULTS:")
    println("="^50)
    for (name, H0, H1, elapsed_h0, elapsed_h1, total_elapsed) in results
        println("Graph: $name")
        println("H0: $H0")
        println("H0 Time: $elapsed_h0 sec")
        println("H1: $H1")
        println("H1 Time: $elapsed_h1 sec")
        println("Total Time: $total_elapsed sec\n")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run()
end