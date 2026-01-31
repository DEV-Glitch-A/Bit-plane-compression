import math
import numpy as np
from collections import Counter

# CONFIGURATION
# ============================================================================
BLOCK_SIZE = 8  # Number of samples per block
data_width = 8  # Width of each data word in bits

def subtract_bit(a, b):
    a_bits = list(map(int, a))
    b_bits = list(map(int, b))
    result = [0] * (len(a_bits) + 1)
    borrow = 0
    for i in range(len(a_bits)-1, -1, -1):
        sub = a_bits[i] - b_bits[i] - borrow
        if sub >= 0:
            result[i+1] = sub
            borrow = 0
        else:
            result[i+1] = sub + 2
            borrow = 1
    result[0] = borrow
    return ''.join(map(str, result))

def xor_strings(s1, s2):
    return ''.join(str(int(a) ^ int(b)) for a, b in zip(s1, s2))

def word_diff(words):
    diffs = []
    for i in range(1, len(words)):
        diff = subtract_bit(words[i], words[i-1])
        diffs.append(diff)
    return diffs

# ============================================================================
# ENCODER FUNCTIONS
# ============================================================================

def encode_bitplanes_with_rle(bitplanes, m, base_group):
    bitstream = []
    n = len(bitplanes[0]) if bitplanes else 0

    for plane in bitplanes:

        # --- All-0 DBX (single-plane only) ---
        if plane.count("1") == 0:
            bitstream.append("01")
            continue

        # --- All-1 DBX ---
        if plane.count("0") == 0:
            bitstream.append("00000")
            continue

        # --- Single-1 ---
        if plane.count("1") == 1:
            pos = plane.index("1")
            pos_bits = int(math.ceil(math.log2(max(1, n))))
            bitstream.append("00011" + format(pos, f'0{pos_bits}b'))
            continue

        # --- Exactly two consecutive 1s ---
        if plane.count("1") == 2:
            for j in range(n - 1):
                if plane[j] == "1" and plane[j + 1] == "1":
                    pos_bits = int(math.ceil(math.log2(max(1, n))))
                    bitstream.append("00010" + format(j, f'0{pos_bits}b'))
                    break
            else:
                bitstream.append("1" + plane)
            continue

        # --- Raw ---
        bitstream.append("1" + plane)

    return bitstream

def encode_block(block_data, data_width, verbose=False):

    # Convert to binary words
    binary_words = [format(val & ((1 << data_width) - 1), f'0{data_width}b')
                    for val in block_data]
    base_word = binary_words[0]

    # Compute differences
    diffs = word_diff(binary_words)

    # Group bits (transpose to get bit planes)
    num_bits = len(diffs[0])
    groups = [''.join(diff[i] for diff in diffs) for i in range(num_bits)]

    # Base DBP
    base_dbp = groups[0]

    # XOR groups
    xor_groups = []
    for i in range(1, len(groups)):
        xored = xor_strings(groups[i-1], groups[i])
        xor_groups.append(xored)

    # Encode
    encoded_stream = encode_bitplanes_with_rle(xor_groups, m=data_width, base_group=base_dbp)
    final_bitstream = ''.join(encoded_stream)
    final_bitstream_full = base_word+ base_dbp + final_bitstream

    # Statistics
    original_bits = len(block_data) * data_width
    compressed_bits = len(final_bitstream)
    zero_planes = sum(1 for plane in xor_groups if plane.count("1") == 0)

    stats = {
        'original_bits': original_bits,
        'compressed_bits': compressed_bits,
        'compression_ratio': original_bits / compressed_bits if compressed_bits > 0 else 0,
        'zero_planes': zero_planes,
        'total_planes': len(xor_groups)
    }

    if verbose:
        print(f"\n{'='*60}")
        print(f"BLOCK ENCODING DETAILS")
        print(f"{'='*60}")
        print(f"Data: {list(block_data)}")
        print(f"\nBinary Words:")
        for i, (val, binary) in enumerate(zip(block_data, binary_words)):
            print(f"  Word[{i}] = {val:3d} = {binary}")

        print(f"\nBase Word: {base_word}")

        print(f"\nDifferences (9-bit each):")
        for i, d in enumerate(diffs):
            print(f"  Diff[{i}]: {d}")

        print(f"\nGrouped bits (MSB to LSB):")
        for slno, g in enumerate(groups):
            print(f"  Bit[{slno}] -> {g}")

        print(f"\nBase DBP: {base_dbp}")

        print(f"\nXOR groups:")
        for i, xg in enumerate(xor_groups):
            print(f"  XOR[{i}]: {xg}")

        print(f"\nEncoding each XOR group (single-plane):")

        for i, xg in enumerate(xor_groups):
            ones = xg.count("1")
            print(f"  XOR[{i}]: {xg} (ones: {ones}) -> {encoded_stream[i]}")


        print(f"\nFinal Bitstream: {final_bitstream_full}")
        print(f"  Base Word: {base_word} ({len(base_word)} bits)")
        print(f"  Encoded:   {final_bitstream} ({len(final_bitstream)} bits)")
        print(f"  Total:     {len(final_bitstream)} bits")

        print(f"\nCompression:")
        print(f"  Original:  {original_bits} bits")
        print(f"  Compressed: {compressed_bits} bits")
        print(f"  Ratio:     {stats['compression_ratio']:.2f}x")
        print(f"  Zero planes: {zero_planes}/{len(xor_groups)}")

    return final_bitstream_full, stats, {
        'binary_words': binary_words,
        'diffs': diffs,
        'groups': groups,
        'base_dbp': base_dbp,
        'xor_groups': xor_groups,
        'encoded_stream': encoded_stream
    }


# DECODER FUNCTIONS
# ============================================================================

def decode_dbx_only(bitstream, m, n, expected_planes):
    pos = 0
    dbx_planes = []

    while pos < len(bitstream) and len(dbx_planes) < expected_planes:

        if bitstream[pos:pos+2] == "01":
            dbx_planes.append("0" * n)
            pos += 2
            continue

        if bitstream[pos:pos+5] == "00000":
            dbx_planes.append("1" * n)
            pos += 5
            continue

        if bitstream[pos:pos+3] == "001":
            pos += 3
            run_bits = int(math.ceil(math.log2(m)))
            run_len = int(bitstream[pos:pos+run_bits], 2) + 2
            pos += run_bits
            for _ in range(run_len):
                if len(dbx_planes) < expected_planes:
                    dbx_planes.append("0" * n)
            continue

        if bitstream[pos:pos+5] == "00011":
            pos += 5
            pos_bits = int(math.ceil(math.log2(n)))
            position = int(bitstream[pos:pos+pos_bits], 2)
            pos += pos_bits
            plane = ["0"] * n
            plane[position] = "1"
            dbx_planes.append("".join(plane))
            continue

        if bitstream[pos:pos+5] == "00010":
            pos += 5
            pos_bits = int(math.ceil(math.log2(n)))
            position = int(bitstream[pos:pos+pos_bits], 2)
            pos += pos_bits
            plane = ["0"] * n
            plane[position] = "1"
            plane[position + 1] = "1"
            dbx_planes.append("".join(plane))
            continue

        if bitstream[pos] == "1":
            pos += 1
            plane = bitstream[pos:pos+n]
            pos += n
            dbx_planes.append(plane)
            continue

        raise ValueError("Invalid DBX code")

    return dbx_planes


def decode_xor_groups(base_dbp, xor_groups):
    groups = [base_dbp]
    for xored in xor_groups:
        original = xor_strings(groups[-1], xored)
        groups.append(original)
    return groups

def bitplanes_to_diffs(groups):
    n = len(groups[0])
    num_bits = len(groups)
    diffs = []
    for i in range(n):
        diff = ''.join(groups[j][i] for j in range(num_bits))
        diffs.append(diff)
    return diffs

def add_bit(prev_word, diff):
    borrow = int(diff[0])
    diff_val = int(diff[1:], 2)

    if borrow == 1:
        signed_diff = diff_val - 256
    else:
        signed_diff = diff_val

    new_val = (int(prev_word, 2) + signed_diff) & 0xFF
    return format(new_val, '08b')

def reconstruct_words(base_word, diffs):
    words = [base_word]
    for diff in diffs:
        prev_word = words[-1]
        new_word = add_bit(prev_word, diff)
        words.append(new_word)
    return words
def decode_block(final_bitstream_full, data_width, block_size):
    n = block_size - 1

    # Extract base_word (8 bits)
    decoded_base_word = final_bitstream_full[:data_width]

    # Extract base_dbp (15 bits for block_size=16)
    decoded_base_dbp = final_bitstream_full[data_width:data_width + n]

    # Extract encoded DBX planes (rest of bitstream)
    encoded_bitstream = final_bitstream_full[data_width + n:]

    decoded_xor_groups = decode_dbx_only(
        encoded_bitstream,
        m=data_width,
        n=n,
        expected_planes=data_width  # Changed from data_width - 1
    )

    # Rebuild full delta bitplanes
    decoded_delta_bitplanes = decode_xor_groups(
        decoded_base_dbp,
        decoded_xor_groups
    )

    # Use ALL bitplanes to create 9-bit diffs
    decoded_diffs = bitplanes_to_diffs(decoded_delta_bitplanes)

    reconstructed_words = reconstruct_words(decoded_base_word, decoded_diffs)

    return [int(w, 2) for w in reconstructed_words]

# ============================================================================
# MAIN PROCESSING
# ============================================================================

def main():
    # Load data
    with open("D:\Projekt\sample compressed data\dense_layer_unsigned.txt", "r") as f:
        content = f.read().strip()

    data = [int(x) for x in content.replace(',', ' ').split()]
    data = [val for val in data if val != 0]
    data = np.array(data, dtype=int)

    print(f"Loaded {len(data)} samples from file.")
    print(f"First 10 samples: {data[:10]}")

    data = data[:128]

    print(f"\n{'='*60}")
    print(f"PROCESSING {len(data)} SAMPLES")

    # Trim to multiple of block size
    num_blocks = len(data) // BLOCK_SIZE
    data = data[:num_blocks * BLOCK_SIZE]
    print(f"Processing {len(data)} samples in {num_blocks} blocks")

    # Process all blocks
    encoded_blocks = []
    all_stats = []
    all_details = []

    for block_idx in range(num_blocks):
        start_idx = block_idx * BLOCK_SIZE
        end_idx = start_idx + BLOCK_SIZE
        block_data = data[start_idx:end_idx]

        # Encode with detailed output only for first block
        verbose = (block_idx == 0)
        bitstream, stats, details = encode_block(block_data, data_width, verbose=verbose)

        encoded_blocks.append(bitstream)
        all_stats.append(stats)
        all_details.append(details)

        if not verbose:
            print(f"\nBlock {block_idx}: {stats['compression_ratio']:.2f}x compression "
                  f"({stats['compressed_bits']}/{stats['original_bits']} bits, "
                  f"{stats['zero_planes']}/{stats['total_planes']} zero planes)")

    # Overall statistics
    total_original = sum(s['original_bits'] for s in all_stats)
    total_compressed = sum(s['compressed_bits'] for s in all_stats)

    print(f"\n{'='*60}")
    print(f"OVERALL ENCODING STATISTICS")
    print(f"{'='*60}")
    print(f"Total blocks: {num_blocks}")
    print(f"Total original bits: {total_original}")
    print(f"Total compressed bits: {total_compressed}")
    print(f"Overall compression ratio: {total_original/total_compressed:.2f}x")
    print(f"Average zero planes: {np.mean([s['zero_planes'] for s in all_stats]):.1f}")

    # DECODE AND VERIFY
    print(f"\n{'='*60}")
    print(f"DECODING AND VERIFICATION")
    print(f"{'='*60}")

    all_decoded = []
    for block_idx in range(num_blocks):
        reconstructed = decode_block(encoded_blocks[block_idx], data_width, BLOCK_SIZE)
        all_decoded.extend(reconstructed)

        # Verify this block
        start_idx = block_idx * BLOCK_SIZE
        end_idx = start_idx + BLOCK_SIZE
        original_block = list(data[start_idx:end_idx])

        if reconstructed == original_block:
            print(f"Block {block_idx}: ✓ SUCCESS")
        else:
            print(f"Block {block_idx}: ✗ MISMATCH")
            print(f"  Original: {original_block}")
            print(f"  Decoded:  {reconstructed}")

    # Final verification
    print(f"\n{'='*60}")
    print(f"FINAL VERIFICATION")
    print(f"{'='*60}")
    print(f"Original data: {list(data)}")
    print(f"Decoded data:  {all_decoded}")

    if all_decoded == list(data):
        print(f"\n✓ SUCCESS! All blocks decoded correctly.")
    else:
        print(f"\n✗ MISMATCH! Decoding failed.")
    print(f"Overall compression ratio: {total_original/total_compressed:.2f}x")
if __name__ == "__main__":
    main()
