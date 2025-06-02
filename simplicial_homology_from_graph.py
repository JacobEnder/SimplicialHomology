import homology
import time
from cycle_detection import build_simplicial_complex

def homology_from_graph(vertices, adj):

    X, A = build_simplicial_complex(vertices, adj)

    return (
        homology.homology(0, A),
        homology.homology(1, A),
        homology.homology(2, A)
    )

if __name__ == "__main__":
    
    vertices = [1, 2, 3, 4]
    adj = {
       1: [2,4],
       2: [1,3],
       3: [2,4],
       4: [1,3]
    }

    start_time = time.time()

    print(f"(H0, H1, H2): {homology_from_graph(vertices, adj)}")

    print(f"Time: {round(time.time() - start_time, 4)} sec")
