# Multithreaded homology computation

using LinearAlgebra
using JSON3
using Combinatorics

function z_mod_2(x)
    return x % 2 == 0
end

# Check if a pair (X, A) is indeed a simplicial complex
function is_simp_cplx(vertices, faces)
    # For all x in X, {x} in A
    singletons = [sigma for sigma in faces if length(sigma) == 1]

    if length(singletons) != length(vertices)
        return false
    end

    # For all sigma in A, if tau <= sigma, then tau in A
    faces_set = Set(tuple(sort(collect(face))...) for face in faces)

    for sigma in faces_set
        # Generate all strict subsets 
        for k in 1:(length(sigma)-1)
            for tau in combinations(sigma, k)
                if tuple(sort(collect(tau))...) ∉ faces_set
                    return false
                end
            end
        end
    end
    return true
end

# Return all n-simplices
function A_n(n, faces)
    return [tuple(sort(collect(sigma))...) for sigma in faces if length(sigma) == n+1]
end

# Compute the matrix corresponding to the boundary map delta_n with multithreading
function boundary(n, faces)
    # We need a map C_n -> C_{n-1}
    n_simplices = A_n(n, faces)
    n_minus_one_simplices = A_n(n-1, faces)

    # Initialize the matrix
    boundary_matrix = zeros(Int, length(n_minus_one_simplices), length(n_simplices))

    # Use multithreading for larger matrices
    if length(n_simplices) > 50 && Threads.nthreads() > 1
        # Create a lookup dictionary for faster face finding
        face_lookup = Dict(face => idx for (idx, face) in enumerate(n_minus_one_simplices))
        
        # Parallel computation over columns
        Threads.@threads for col in 1:length(n_simplices)
            sigma = n_simplices[col]
            
            for i in 1:length(sigma)
                # From the definition of the boundary map, delete entry i and take the sign as (-1)^i
                sign = (-1)^(i-1)  # Julia uses 1-based indexing
                face_array = [sigma[j] for j in 1:length(sigma) if j != i]
                face = tuple(sort(face_array)...)

                # If the face we just computed is indeed in C_{n-1}, we've found the action of delta_n on this basis vector
                face_idx = get(face_lookup, face, nothing)
                if face_idx !== nothing
                    boundary_matrix[face_idx, col] = sign
                end
            end
        end
    else
        # Sequential version for smaller matrices
        for (col, sigma) in enumerate(n_simplices)
            for i in 1:length(sigma)
                # From the definition of the boundary map, delete entry i and take the sign as (-1)^i
                sign = (-1)^(i-1)  # Julia uses 1-based indexing
                face_array = [sigma[j] for j in 1:length(sigma) if j != i]
                face = tuple(sort(face_array)...)

                # If the face we just computed is indeed in C_{n-1}, we've found the action of delta_n on this basis vector
                face_idx = findfirst(==(face), n_minus_one_simplices)
                if face_idx !== nothing
                    boundary_matrix[face_idx, col] = sign
                end
            end
        end
    end

    return boundary_matrix
end

# Compute the nth discrete homology group of (X, A)
function homology(n, faces; mod_2=false)
    # Get our boundary maps
    delta_n = boundary(n, faces)
    delta_n_plus_one = boundary(n+1, faces)

    if !mod_2
        # Built-in nullspace and rank
        ker_del_n = nullspace(delta_n)
        rank_del_n_plus_one = rank(delta_n_plus_one)
    else
        # For mod 2, we need to work over GF(2)
        # Convert matrices to mod 2
        delta_n_mod2 = delta_n .% 2
        delta_n_plus_one_mod2 = delta_n_plus_one .% 2
        
        ker_del_n = nullspace(delta_n_mod2)
        rank_del_n_plus_one = rank(delta_n_plus_one_mod2)
    end

    # By rank-nullity, dim(H_n) = nullity(delta_n) - rank(delta_{n+1})
    homology_dimension = size(ker_del_n, 2) - rank_del_n_plus_one

    return homology_dimension
end

# Pretty-print a complex
function print_simp_cplx(X, A)
    println("\nThis complex is given by:\n")
    println("Underlying space\n")
    println(X)
    println("\nFaces\n")
    println(A)
end

# Multithreaded version of complete_simp_cplx
function complete_simp_cplx(faces)
    faces_array = collect(faces)
    seen = Set(tuple(sort(collect(face))...) for face in faces_array)
    original_length = length(faces_array)
    
    # Use multithreading for larger face sets
    if original_length > 100 && Threads.nthreads() > 1
        # Thread-safe operations using locks
        lock = ReentrantLock()
        new_faces_per_thread = [Vector{Vector{Any}}() for _ in 1:Threads.nthreads()]
        
        Threads.@threads for i in 1:original_length
            tid = Threads.threadid()
            face = faces_array[i]
            n = length(face)
            
            thread_new_faces = Vector{Any}()
            
            for r in 1:(n-1)
                for subset in combinations(face, r)
                    subset_sorted = tuple(sort(collect(subset))...)
                    
                    # Check if we've seen this subset (thread-safe read)
                    should_add = false
                    lock() do
                        if subset_sorted ∉ seen
                            push!(seen, subset_sorted)
                            should_add = true
                        end
                    end
                    
                    if should_add
                        push!(thread_new_faces, collect(subset_sorted))
                    end
                end
            end
            
            new_faces_per_thread[tid] = thread_new_faces
        end
        
        # Combine results from all threads
        for thread_faces in new_faces_per_thread
            append!(faces_array, thread_faces)
        end
    else
        # Sequential version for smaller face sets
        for i in 1:original_length
            face = faces_array[i]
            n = length(face)
            
            for r in 1:(n-1)
                for subset in combinations(face, r)
                    subset_sorted = tuple(sort(collect(subset))...)
                    if subset_sorted ∉ seen
                        push!(faces_array, collect(subset_sorted))
                        push!(seen, subset_sorted)
                    end
                end
            end
        end
    end
    
    return faces_array
end