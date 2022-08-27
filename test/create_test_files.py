import numpy as np

if __name__ == "__main__":
    simple = np.arange(1, 100, dtype=float)
    np.save("simple.npy", simple)
