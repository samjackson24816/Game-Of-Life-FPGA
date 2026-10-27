import argparse
import os
import random

# Each cell is one byte. The top bit is alive, the next three bits are
# brightness, and the low four bits are hue. Cells start dark so they fade in.

# This file was written with help from Claude as a quick test of the system

def cell(hue):
    alive = 1
    brightness = 0
    return (alive << 7) | (brightness << 4) | (hue & 0xF)


def glider_grid():
    # A glider in the top left corner
    grid = [[0 for _ in range(8)] for _ in range(8)]
    glider_coords = [(0, 1), (1, 2), (2, 0), (2, 1), (2, 2)]
    for idx, (r, c) in enumerate(glider_coords):
        grid[r][c] = cell((idx * 3) % 16)
    return grid


def random_grid(density, seed):
    rng = random.Random(seed)
    grid = [[0 for _ in range(8)] for _ in range(8)]
    for r in range(8):
        for c in range(8):
            if rng.random() < density:
                grid[r][c] = cell(rng.randrange(16))
    return grid


def write_grid(grid, label):
    rows = ["".join(f"{grid[r][c]:02x}" for c in range(8)) for r in range(8)]
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "initial_grid.txt")
    with open(path, "w") as f:
        f.write("\n".join(rows) + "\n")
    print(f"Generated {label} grid in {path} successfully!")
    for r in range(8):
        print(" ".join("O" if grid[r][c] & 0x80 else "." for c in range(8)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Write initial_grid.txt for the Game of Life FPGA")
    parser.add_argument("--random", action="store_true", help="random seed instead of a glider")
    parser.add_argument("--density", type=float, default=0.375, help="fraction of cells alive (random mode)")
    parser.add_argument("--seed", type=int, default=None, help="random seed for a repeatable grid")
    args = parser.parse_args()

    if args.random:
        write_grid(random_grid(args.density, args.seed), "random")
    else:
        write_grid(glider_grid(), "glider")
