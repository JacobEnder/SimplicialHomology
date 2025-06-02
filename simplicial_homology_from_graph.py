import homology
import time
from cycle_detection import build_simplicial_complex
from itertools import chain

def homology_from_graph(vertices, adj, mod_2=False):

    X, A = build_simplicial_complex(vertices, adj)

    if (mod_2 == False):
        return (
            homology.homology(0, A),
            homology.homology(1, A),
            homology.homology(2, A)
        )
    else:
        return (
            homology.homology(0, A, mod_2=True),
            homology.homology(1, A, mod_2=True),
            homology.homology(2, A, mod_2=True)
        )

if __name__ == "__main__":
    
    vertices_c5 = [1, 2, 3, 4, 5]
    adj_c5 = {
       1: [2,5],
       2: [1,3],
       3: [2,4],
       4: [5,3],
       5: [1,4]
    }

    vertices_c5_plus = [1,2,3,4,5]

    adj_c5_plus = {
       1: [2,5,4],
       2: [1,3],
       3: [2,4],
       4: [5,3,1],
       5: [1,4]
    }

    vertices = list(chain(range(5), range(11, 32)))

    adjacency_list = {
        0: [1,4,11,16],
        1: [0,2,12,17],
        2: [1,3,13,18],
        3: [2,4,14,19],
        4: [3,0,15,20],
        11: [12, 20, 21, 0],
        12: [11, 13, 22, 1],
        13: [12, 14, 23, 2],
        14: [13, 15, 24, 3],
        15: [14, 16, 25, 4],
        16: [15, 17, 26, 0],
        17: [16, 18, 27, 1],
        18: [17, 19, 28, 2],
        19: [18, 20, 29, 3],
        20: [11, 19, 4, 30],
        21: [22, 30, 11, 31],
        22: [21, 23, 12, 31],
        23: [22, 24, 13, 31],
        24: [23, 25, 14, 31],
        25: [24, 26, 15, 31],
        26: [25, 27, 16, 31],
        27: [26, 28, 17, 31],
        28: [27, 29, 18, 31],
        29: [28, 30, 19, 31],
        30: [29, 21, 20, 31],
        31: [21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
    }



    start_time = time.time()

    print(f"(H0, H1, H2): {homology_from_graph(vertices_c5, adj_c5)}")

    print(f"Time: {round(time.time() - start_time, 4)} sec\n")

    start_time = time.time()

    print(f"(H0, H1, H2): {homology_from_graph(vertices_c5_plus, adj_c5_plus)}")

    print(f"Time: {round(time.time() - start_time, 4)} sec\n")

    start_time = time.time()

    print(f"(H0, H1, H2): {homology_from_graph(vertices, adjacency_list, mod_2=False)}")

    print(f"Time: {round(time.time() - start_time, 4)} sec\n")
