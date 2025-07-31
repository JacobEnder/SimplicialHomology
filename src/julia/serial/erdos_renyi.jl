using Random
using SparseArrays
using JSON

"""
    erdos_renyi_graph(n::Int, p::Float64; seed::Union{Int, Nothing} = nothing)

Generate an Erdős-Rényi random graph G(n,p) with n vertices where each edge 
is included independently with probability p.

# Arguments
- n::Int: Number of vertices
- p::Float64: Edge probability (0 ≤ p ≤ 1)
- seed::Union{Int, Nothing}: Random seed for reproducibility (optional)

# Returns
- SparseMatrixCSC{Bool, Int}: Adjacency matrix as sparse boolean matrix

"""
function erdos_renyi_graph(n::Int, p::Float64; seed::Union{Int, Nothing} = nothing)
    # Input validation
    n < 1 && throw(ArgumentError("Number of vertices must be positive"))
    !(0 ≤ p ≤ 1) && throw(ArgumentError("Edge probability must be between 0 and 1"))
    
    # Set random seed if provided
    if seed !== nothing
        Random.seed!(seed)
    end
    
    # Pre-allocate vectors for sparse matrix construction
    # Maximum possible edges for undirected graph: n*(n-1)/2
    max_edges = n * (n - 1) ÷ 2
    
    # Use different strategies based on edge probability for optimal performance
    if p < 0.5
        # For sparse graphs, iterate through potential edges
        I = Int[]
        J = Int[]
        
        sizehint!(I, Int(ceil(max_edges * p * 1.2)))  # Pre-allocate with some buffer
        sizehint!(J, Int(ceil(max_edges * p * 1.2)))
        
        for i in 1:n
            for j in (i+1):n
                if rand() < p
                    push!(I, i)
                    push!(J, j)
                end
            end
        end
        
        # Create symmetric sparse matrix
        all_I = vcat(I, J)
        all_J = vcat(J, I)
        
    else
        # For dense graphs, generate complement and subtract
        # This is more efficient when p > 0.5
        I = Int[]
        J = Int[]
        
        sizehint!(I, Int(ceil(max_edges * (1-p) * 1.2)))
        sizehint!(J, Int(ceil(max_edges * (1-p) * 1.2)))
        
        # Generate edges to exclude (complement)
        for i in 1:n
            for j in (i+1):n
                if rand() >= p  # NOT included
                    push!(I, i)
                    push!(J, j)
                end
            end
        end
        
        # Generate all possible edges
        all_I = Int[]
        all_J = Int[]
        
        for i in 1:n
            for j in (i+1):n
                push!(all_I, i)
                push!(all_J, j)
            end
        end
        
        # Remove excluded edges
        excluded_edges = Set(zip(I, J))
        filter_mask = [!((i, j) in excluded_edges) for (i, j) in zip(all_I, all_J)]
        
        included_I = all_I[filter_mask]
        included_J = all_J[filter_mask]
        
        # Create symmetric representation
        all_I = vcat(included_I, included_J)
        all_J = vcat(included_J, included_I)
    end
    
    # Create sparse adjacency matrix
    return sparse(all_I, all_J, true, n, n)
end

"""
    adjacency_matrix_to_dict(G::SparseMatrixCSC{Bool, Int})

Convert sparse adjacency matrix to adjacency list representation.

# Arguments
- G::SparseMatrixCSC{Bool, Int}: Sparse adjacency matrix

# Returns
- Vector{Vector{String}}: Adjacency list where each entry is a vector of neighbor strings
"""
function adjacency_matrix_to_dict(G::SparseMatrixCSC{Bool, Int})
    n = size(G, 1)
    adj_dict = Dict{String, Vector{String}}()
    
    for i in 1:n
        # Get neighbors of vertex i
        neighbors = Int[]
        for j in 1:n
            if G[i, j]
                push!(neighbors, j)
            end
        end
        # Convert to strings and add to dictionary
        adj_dict[string(i)] = string.(neighbors)
    end
    
    return adj_dict
end

"""
    append_graph_to_json(G::SparseMatrixCSC{Bool, Int}, n::Int, p::Float64, filename::String)

Append Erdős-Rényi graph to JSON file as part of a list.

# Arguments
- G::SparseMatrixCSC{Bool, Int}: Adjacency matrix
- n::Int: Number of vertices
- p::Float64: Edge probability
- filename::String: Output filename (without extension)

# File Format
The JSON file will contain an array of graph objects:
[
  {
    "name": "erdos_renyi_<n>_<p>",
    "vertices": ["1", "2", ..., "n"],
    "adjacency_list": {...}
  },
  ...
]
"""
function append_graph_to_json(G::SparseMatrixCSC{Bool, Int}, n::Int, p::Float64, filename::String)
    # Create directory path
    data_dir = joinpath("..", "..", "..", "data")
    mkpath(data_dir)  # Create directory if it doesn't exist
    
    # Create full file path
    full_path = joinpath(data_dir, filename * ".json")
    
    # Convert adjacency matrix to list
    adj_list = adjacency_matrix_to_dict(G)
    
    # Create graph name
    graph_name = "erdos_renyi_$(n)_$(p)"
    
    # Create vertex list (as strings)
    vertices = string.(1:n)
    
    # Create new graph object
    new_graph = Dict(
        "name" => graph_name,
        "vertices" => vertices,
        "adjacency_list" => adj_list
    )
    
    # Read existing data or create empty array
    existing_data = []
    if isfile(full_path)
        try
            existing_data = JSON.parsefile(full_path)
        catch e
            println("Warning: Could not parse existing JSON file, starting fresh: $e")
            existing_data = []
        end
    end
    
    # Append new graph
    push!(existing_data, new_graph)
    
    # Write back to file
    open(full_path, "w") do file
        JSON.print(file, existing_data, 2)  # Pretty print with 2-space indentation
    end
    
    println("Graph appended to: $full_path")
    return full_path
end

"""
    save_graph_to_json(G::SparseMatrixCSC{Bool, Int}, n::Int, p::Float64, filename::String)

Save Erdős-Rényi graph to JSON file with specified format.

# Arguments
- G::SparseMatrixCSC{Bool, Int}: Adjacency matrix
- n::Int: Number of vertices
- p::Float64: Edge probability
- filename::String: Output filename (without extension)

# File Format
The JSON file will contain:
- name: String in format "erdos_renyi_<n>_<p>"
- vertices: Array of vertex strings ["1", "2", ..., "n"]
- adjacency_list: Array of arrays, where each sub-array contains neighbor strings
"""
function save_graph_to_json(G::SparseMatrixCSC{Bool, Int}, n::Int, p::Float64, filename::String)
    # Create directory path
    data_dir = joinpath("..", "..", "..", "data")
    mkpath(data_dir)  # Create directory if it doesn't exist
    
    # Create full file path
    full_path = joinpath(data_dir, filename * ".json")
    
    # Convert adjacency matrix to list
    adj_list = adjacency_matrix_to_dict(G)
    
    # Create graph name
    graph_name = "erdos_renyi_$(n)_$(p)"
    
    # Create vertex list (as strings)
    vertices = string.(1:n)
    
    # Create JSON structure
    graph_data = Dict(
        "name" => graph_name,
        "vertices" => vertices,
        "adjacency_list" => adj_list
    )
    
    # Write to file
    open(full_path, "w") do file
        JSON.print(file, graph_data, 2)  # Pretty print with 2-space indentation
    end
    
    println("Graph saved to: $full_path")
    return full_path
end

"""
    generate_and_save_erdos_renyi(n::Int, p::Float64, filename::String; seed::Union{Int, Nothing} = nothing)

Generate an Erdős-Rényi graph and save it to JSON file.

# Arguments
- n::Int: Number of vertices
- p::Float64: Edge probability (0 ≤ p ≤ 1)
- filename::String: Output filename (without extension)
- seed::Union{Int, Nothing}: Random seed for reproducibility (optional)

# Returns
- Tuple{SparseMatrixCSC{Bool, Int}, String}: Generated graph and file path
"""
function generate_and_save(n::Int, p::Float64, filename::String; seed::Union{Int, Nothing} = nothing)
    # Generate graph
    G = erdos_renyi_graph(n, p, seed=seed)
    
    # Save to JSON (now appends to array)
    file_path = append_graph_to_json(G, n, p, filename)
    
    return G, file_path
end

function generate_multiple(num_graphs::Int, fewest_vertices::Int, most_vertices::Int, 
                                            lowest_prob::Float64, highest_prob::Float64, filename::String; 
                                            seed::Union{Int, Nothing} = nothing)
    
    # Set random seed if provided
    if seed !== nothing
        Random.seed!(seed)
    end
    
    # Initialize results array
    results = []
    
    println("Generating $num_graphs Erdős-Rényi graphs...")
    
    for i in 1:num_graphs
        # Generate random parameters
        n = rand(fewest_vertices:most_vertices)
        p = lowest_prob + rand() * (highest_prob - lowest_prob)
        
        println("  Graph $i: n=$n, p=$(round(p, digits=4))")
        
        # Generate and save graph
        G, _ = generate_and_save(n, p, filename)
        
        # Store results
        push!(results, (G, n, p))
    end
    
    println("All $num_graphs graphs generated and saved!")
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_multiple(45, 100, 300, 0.01, 0.2, "erdos_renyi_graphs")
end