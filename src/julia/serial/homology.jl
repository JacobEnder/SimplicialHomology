# Naive calculation of H0, H1 and H2 for simplicial complexes

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

# Compute the matrix corresponding to the boundary map delta_n
function boundary(n, faces)
    # We need a map C_n -> C_{n-1}
    n_simplices = A_n(n, faces)
    n_minus_one_simplices = A_n(n-1, faces)

    # Initialize the matrix
    boundary_matrix = zeros(Int, length(n_minus_one_simplices), length(n_simplices))

    # Iterate over the columns
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

# If given a set of faces that is not a simplicial complex, we can complete the set to
# a simplicial complex by simply adding the necessary faces.
function complete_simp_cplx(faces)
    faces_array = collect(faces)
    seen = Set(tuple(sort(collect(face))...) for face in faces_array)
    original_length = length(faces_array)
    
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
    
    return faces_array
end