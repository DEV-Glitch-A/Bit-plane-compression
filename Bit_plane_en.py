import math
import numpy as np
from collections import Counter

with open("D:\Projekt\sample compressed data\weights_flattened_unsigned.txt", "r") as f:
    content = f.read().strip()

# Convert text to list of integers
data = [int(x) for x in content.replace(',', ' ').split()]
data = np.array(data, dtype=int)

print(f"Loaded {len(data)} samples from file.")
print("First 10 samples:", data[:10])

# === Select subset or use all ===
# You can use all 942 samples or first 53 for testing
input_integers = data[:10]   # or data for all
print("\nUsing these integers for encoding (first 10 shown):")
print(input_integers[:10])

# === Encoder Logic ===
binary_words = [format(val & 0xFF, '08b') for val in input_integers]
#print("inputs in 8-bit binary",binary_words)

base_word = binary_words[0]
print("Baseword:", base_word)

#for verification
def word_diff(words):
    ints = [int(w, 2) for w in words]  # convert binary strings to integers
    diffs =[ints[i] - ints[i-1] for i in range(1, len(words))]
    return diffs
diffs = word_diff(binary_words)
print("Differences:", diffs)
# ----------bit by bit subraction------------#
def subtract_bit(a, b):
    a_bits = list(map(int, a))
    b_bits = list(map(int, b))

    result = [0] * (len(a_bits) + 1)  # m+1 bits
    borrow = 0

    for i in range(len(a_bits)-1, -1, -1): #right to left subtraction
        sub = a_bits[i] - b_bits[i] - borrow
        if sub >= 0: # if no borrow is nedded
            result[i+1] = sub
            borrow = 0
        else:
            result[i+1] = sub + 2
            borrow = 1

    result[0] = borrow
    return ''.join(map(str, result)) # gluing all together

def word_diff(words):
    """Compute differences between consecutive words using manual subtraction."""
    diffs = []
    for i in range(1, len(words)):
        diff = subtract_bit(words[i], words[i-1])
        diffs.append(diff)
    return diffs

# Compute differences on binary_words
diffs = word_diff(binary_words)
print("\nDifferences (9-bit each, from binary_words):")
print("baseword",base_word)
for d in diffs:
    print(d)

"""Build delta bit-planes (m+1 bitplanes of n bits)."""
num_bits = len(diffs[0])
groups = [''.join(diff[i] for diff in diffs) for i in range(num_bits)]
print("viewing in bitplane",groups)
print("\nGrouped bits (MSB to LSB):")
for slno, g in enumerate(groups):
    print(f"Bit[{slno}] -> {g}")

'''XORing the neighbouring Delta planes'''
def xor_strings(s1, s2):
    """XOR two equal-length bit strings."""
    return ''.join(str(int(a) ^ int(b)) for a, b in zip(s1, s2))

# XOR groups, leaving MSB (groups[0])
base_dbp = groups[0]
print("\nBase DBP (MSB plane):", base_dbp)
xor_groups = []
for i in range(1, len(groups)):
    xored = xor_strings(groups[i-1], groups[i])
    xor_groups.append(xored)
print("XOR = ",xor_groups)
total_xor_bits = sum(len(xg) for xg in xor_groups)

print("Total XOR bits across all groups:", total_xor_bits)
def encode_bitplanes_with_rle(bitplanes, m, base_group):
    """
    Encode base DBP + DBX planes with support for multi-all-0DBX RLE.
    bitplanes: list of DBX planes (strings)
    m: original word size (e.g., 8)
    base_group: the base DBP string
    """
    bitstream = []

    # --- Encode the base DBP ---
    if base_group.count("1") == 0:
        bitstream.append("00001")  # all-0 DBP
    else:
        bitstream.append("1" + base_group)

    n = len(bitplanes[0]) if bitplanes else 0
    i = 0
    while i < len(bitplanes):
        plane = bitplanes[i]

        # --- Detect consecutive all-0 DBX planes for multi-all-0DBX ---
        if plane.count("1") == 0:
            run_len = 1
            while i + run_len < len(bitplanes) and bitplanes[i + run_len].count("1") == 0:
                run_len += 1
            if run_len > 1:
                code = "001" + format(run_len - 2, f'0{int(math.ceil(math.log2(m)))}b')
                bitstream.append(code)
                i += run_len
                continue
            else:
                bitstream.append("01")  # single all-0 DBX
                i += 1
                continue

        # --- All-1 DBX ---
        if plane.count("0") == 0:
            bitstream.append("00000")
            i += 1
            continue

        # --- Single-1 ---

        if plane.count("1") == 1:
            pos = plane.index("1")
            pos_bits = int(math.ceil(math.log2(max(1, n))))   # <- changed n -> plane_len capacity
            code = "00011" + format(pos, f'0{pos_bits}b')
            bitstream.append(code)
            i += 1
            continue

        # --- 2 consecutive 1s ---

        found_two = False
        for j in range(n - 1):
                if (
                    plane[j] == "1"
                    and plane[j + 1] == "1"
                    and (j == 0 or plane[j - 1] == "0")
                    and (j + 2 >= n or plane[j + 2] == "0")
                ):
                    pos_bits = int(math.ceil(math.log2(max(1, n - 1))))
                    code = "00010" + format(j, f'0{pos_bits}b')
                    bitstream.append(code)
                    found_two = True
                    break
        if found_two:
            i += 1
            continue

        # --- Uncompressed ---
        bitstream.append("1" + plane)
        i += 1

    return bitstream

encoded_stream = encode_bitplanes_with_rle(xor_groups, m=8, base_group=base_dbp)

print("\nFinal Encoded Stream:")
for code in encoded_stream:
    print(code)

# After encoder
final_bitstream = ''.join(encoded_stream)
base_dbp = groups[0]
base_word = binary_words[0]
final_bitstream_full = base_word + base_dbp + final_bitstream
print("\nFinal Bitstream_full:")
print(final_bitstream_full)
# Count total bits in the final bitstream
total_bits = len(final_bitstream)

print("Total bits in Final Bitstream:", total_bits)


input_bitstream = ''.join(binary_words)
input_bitstream_list = list(input_bitstream)
#print("input_bitstream:", input_bitstream_list)
total_input_bits = len(input_bitstream_list)
def binary_entropy_cal(p):
    """Calculates the binary entropy H_b(p) given probability p."""
    if p == 0 or p == 1:
        return 0.0
    return -p * math.log2(p) - (1 - p) * math.log2(1 - p)

# --- Calculate Occurrences and Probability (p_0) ---
bit_occurrences = Counter(input_bitstream_list)

count_0 = bit_occurrences.get('0', 0)
count_1 = bit_occurrences.get('1', 0)

# Calculate the probability of '0' in the source data
p_0_source = count_0 / total_input_bits
p_1_source = count_1 / total_input_bits # (1 - p_0_source)


print("Source Data Summary (Input Bits)")
print(f"Total input bits: {total_input_bits}")
print(f"Occurrences of '0': {count_0} (p = {p_0_source:.4f})")
print(f"Occurrences of '1': {count_1} (p = {p_1_source:.4f})")

# --- 3. Calculate Source Entropy ---
source_entropy_bits = binary_entropy_cal(p_0_source)

print("\n--- Source Entropy Result ---")
print(f"Shannon Source Entropy (H_b): {source_entropy_bits:.4f} bits/bit")
