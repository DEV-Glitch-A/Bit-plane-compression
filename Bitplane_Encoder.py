import random
import math

binary_words = []
import numpy as np
for i in range(3):
    input_stream_integer=random.randint(1,256)
    print(input_stream_integer)
    binary= format(input_stream_integer,'08b')
    print(binary)
    inverted_bits = ''.join('1' if bit == '0' else '0' for bit in binary)
    twos_complement = format((int(inverted_bits, 2) + 1) & 0xFF, '08b')
    print("2's",twos_complement)
    binary_words.append(binary)

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
base_group = groups[0]
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
            code = "00011" + format(pos, f'0{int(math.ceil(math.log2(n-1)))}b')
            bitstream.append(code)
            i += 1
            continue

        # --- 2 consecutive 1s ---
        found_two = False
        for j in range(n - 1):
            if plane[j] == "1" and plane[j+1] == "1":
                code = "00010" + format(j, f'0{int(math.ceil(math.log2(n-2)))}b')
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

encoded_stream = encode_bitplanes_with_rle(xor_groups, m=8, base_group=base_group)

print("\nFinal Encoded Stream:")
for code in encoded_stream:
    print(code)

final_bitstream = ''.join(encoded_stream)
print("\nFinal Bitstream:")
print(final_bitstream)
# Count total bits in the final bitstream
total_bits = len(final_bitstream)

print("Total bits in Final Bitstream:", total_bits)
