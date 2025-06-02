# Naive calculation of H0, H1 and H2 for simplicial complexes

import sympy as sp
import json
import itertools
import time

def z_mod_2(x):
    return x % 2 == 0

# Check if a pair (X, A) is indeed a simplicial complex
def is_simp_cplx(vertices, faces):

    # For all x in X, {x} in A
    singletons = [sigma for sigma in faces if len(sigma) == 1]

    if (len(singletons) != len(vertices)) : return False

    # For all sigma in A, if tau <= sigma, then tau in A
    faces_set = set(tuple(sorted(face)) for face in faces)

    for sigma in faces_set:
        
        # Generate all strict subsets 
        for k in range(1, len(sigma)):
            for tau in itertools.combinations(sigma, k):
                if tuple(sorted(tau)) not in faces_set:
                    return False
    return True

# Return all n-simplices
def A_n(n, faces):
    
    return [tuple(sorted(sigma)) for sigma in faces if len(sigma) == n+1]

# Compute the matrix corresponding to the boundary map delta_n
def boundary(n, faces):

    # We need a map C_n -> C_{n-1}
    n_simplices = A_n(n, faces)
    n_minus_one_simplices = A_n(n-1, faces)

    # Initialize the matrix
    boundary_matrix = sp.Matrix.zeros(len(n_minus_one_simplices), len(n_simplices))

    # Iterate over the columns
    for col, sigma in enumerate(n_simplices):
        
        for i in range(len(sigma)):

            # From the definition of the boundary map, delete entry i and take the sign as (-1)^i
            sign = (-1) ** i
            face = tuple(sorted(sigma[:i] + sigma[i+1:]))

            # If the face we just computed is indeed in C_{n-1}, we've found the action of delta_n on this basis vector
            if face in n_minus_one_simplices:

                # Figure out which row of the matrix this is in and plug in 1 or -1 according to (-1)^i
                row = n_minus_one_simplices.index(face)
                boundary_matrix[row, col] = sign

    return boundary_matrix

# Compute the nth discrete homology group of (X, A)
def homology(n, faces, mod_2=False):

    # Get our boundary maps
    delta_n = boundary(n, faces)
    delta_n_plus_one = boundary(n+1, faces)

    if (mod_2==False):
        # Built-in kernel and rank
        ker_del_n = delta_n.nullspace()
        rank_del_n_plus_one = delta_n_plus_one.rank()
    else:
        ker_del_n = delta_n.nullspace()
        rank_del_n_plus_one = delta_n_plus_one.rank(iszerofunc=z_mod_2)

    # By rank-nullity, dim(H_n) = nullity(delta_n) - rank(delta_{n+1})
    homology_dimension = len(ker_del_n) - rank_del_n_plus_one

    return homology_dimension

def print_simp_cplx(X, A):
    print("\nThis complex is given by:\n")
    print("Underlying space\n")
    print(X)
    print("\nFaces\n")
    print(A)

def complete_simp_cplx(faces):
    seen = set(tuple(sorted(face)) for face in faces)
    original_length = len(faces)
    
    for i in range(original_length):
        face = faces[i]
        n = len(face)
        
        for r in range(1, n):
            for subset in itertools.combinations(face, r):
                subset_sorted = tuple(sorted(subset))
                if subset_sorted not in seen:
                    faces.append(list(subset_sorted))
                    seen.add(subset_sorted)
    
    return faces

if __name__ == "__main__":

    file_path = "simplicial_complexes.json"

    with open(file_path, "r") as f:
        loaded_complexes = json.load(f)

    overall_start = time.time()

    for idx, complex in enumerate(loaded_complexes):
        X = complex["X"]
        A = complex["A"]

        print_simp_cplx(X,A)
        
        print("\nIs this a valid simplicial complex? " + str(is_simp_cplx(X, A)))

        if (is_simp_cplx == True):
            start = time.time()

            print("\nH0 has dimension " + str(homology(0, A)))
            print("H1 has dimension " + str(homology(1, A)))
            print("H2 has dimension " + str(homology(2, A)))

            print("\nElapsed time (sec): " + str(time.time() - start))
            print("\n-----------------------------------------")
        else:
            print("\nCompleting complex. Completion:")

            completed_complex_X = complex["X"]
            completed_complex_A = complete_simp_cplx(complex["A"])

            print_simp_cplx(completed_complex_X,completed_complex_A)
        
            start = time.time()

            print("\nH0 has dimension " + str(homology(0, completed_complex_A)))
            print("H1 has dimension " + str(homology(1, completed_complex_A)))
            print("H2 has dimension " + str(homology(2, completed_complex_A)))

            print("\nElapsed time (sec): " + str(time.time() - start))
            print("\n-----------------------------------------")

    print("\nTotal elapsed time (sec): " + str(time.time() - overall_start))
