import numpy as np

if __name__ == "__main__":
    simple = np.arange(1, 100, dtype=float)
    np.save("simple_f64.npy", simple)

    simple = np.arange(1, 100, dtype=np.single)
    np.save("simple_f32.npy", simple)

    simple = np.arange(1, 1000, dtype=np.single)
    np.save("bigger_f32.npy", simple)

    simple_2d = np.arange(0, 1000, dtype=np.single).reshape((10, 100))
    np.save("simple_2d_f32.npy", simple_2d)

