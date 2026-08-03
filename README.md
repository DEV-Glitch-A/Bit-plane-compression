# Extended Bit-Plane Compression (EBPC) in VHDL

A complete RTL implementation of the **Extended Bit-Plane Compression (EBPC)** decompression architecture proposed by ETH Zürich for efficient compression of neural network feature maps. This project implements the decompression pipeline entirely in **VHDL** and validates it using simulation and synthesis tools.

> This project is intended for FPGA implementation, ASIC synthesis, and educational purposes in digital design and compression hardware.

---

## Overview

Extended Bit-Plane Compression (EBPC) is a **lossless hardware-friendly compression algorithm** designed for CNN accelerators to reduce memory bandwidth and storage requirements.

The algorithm combines:

- Zero Run-Length Encoding (ZRLE)
- Delta Encoding
- Bit-Plane Compression (BPC)
- DBP/DBX Transform
- Variable-length Symbol Encoding

This repository focuses on the **hardware decompression architecture**, reconstructing the original data stream from the compressed EBPC bitstream.


---

# Features

- Complete RTL implementation in VHDL
- Fully parameterized design
- Modular architecture
- Ready/Valid streaming interfaces
- Variable-length symbol decoding
- Delta reconstruction
- Bit-plane reconstruction
- Zero Run-Length decoding
- Compatible with FPGA and ASIC synthesis flows

---

# Project Structure

```
Bit-plane-Compression/
│ ├── rtl/
│ ├── bpc_decoder.vhd
│ ├── unpacker.vhd
│ ├── expander.vhd
│ ├── symbol_decoder.vhd
│ ├── dbp_buffer.vhd
│ ├── delta_reverse.vhd
│ ├── fifo_slice.vhd
│ ├── ebpc_pkg.vhd
│ ├── my_adder.vhd
│ └── Zrle_decoder.vhd
│ ├── do_synth/
│ ├── scripts/
│ ├── reports/
│ └── results/
│
├── tetramax/
│ ├── scripts/
│ ├── reports/
│ └── patterns/
│
└── README.md
```

---

# EBPC Decompression Pipeline

The implemented decompression flow consists of the following stages:

```
Compressed Bitstream
        │
        ▼
+----------------+
|   Unpacker     |
+----------------+
        │
        ▼
+----------------+
| Symbol Decoder |
+----------------+
        │
        ▼
+----------------+
| DBP Buffer     |
+----------------+
        │
        ▼
+----------------+
| Delta Reverse  |
+----------------+
        │
        ▼
+----------------+
| ZRLE Decoder   |
+----------------+
        │
        ▼
Original Data Stream
```

---

# Implemented Modules

| Module | Description |
|----------|------------|
| `ebpc_pkg.vhd` | Common constants, types and utility functions |
| `unpacker.vhd` | Extracts variable-length symbols from compressed bitstream |
| `expander.vhd` | Expands encoded symbols into DBP/DBX patterns |
| `symbol_decoder.vhd` | Decodes variable-length compression symbols |
| `dbp_buffer.vhd` | Reconstructs Delta Bit Planes |
| `delta_reverse.vhd` | Performs reverse delta reconstruction |
| `zrle_decoder.vhd` | Zero Run-Length decoding |
| `fifo_slice.vhd` | Streaming FIFO |
| `ebpc_top_level.vhd` | Top-level decompression module |

---

# Design Parameters

Current implementation:

| Parameter | Value |
|-----------|------:|
| Data Width | 8 bits |
| Block Size | 8 words |
| Compression | Lossless |
| Streaming Interface | Ready/Valid |

---

# Verification

The design has been verified using:

- ModelSim FPGA Starter Edition

Verification includes:

- Functional simulation
- Multi-block decoding
- Variable-length symbol handling
- Zero Run-Length reconstruction
- Bit-plane reconstruction
- End-to-end data validation

---

# Synthesis

The RTL has been synthesized using:

- Synopsys Design Compiler


The project has been evaluated for:

- Area
- Timing
- Power
- Resource utilization

---

# Tools Used

- VHDL-2008
- ModelSim FPGA Starter Edition
- Synopsys Design Compiler
- Git

---

# Future Work

- FPGA implementation on AMD/Xilinx devices
- Hardware validation on development boards
- EBPC encoder implementation in VHDL
- AXI-Stream interface support
- Performance optimization
- ASIC implementation

---

# References

L. Cavigelli, G. Rutishauser, and L. Benini,

**"Extended Bit-Plane Compression for Convolutional Neural Network Accelerators,"**

IEEE Transactions on Circuits and Systems for Video Technology (TCSVT), 2020. :contentReference[oaicite:1]{index=1}

---

# Author

**Krishandev**

M.Sc. Microelectronics Engineer

Areas of Interest:

- RTL Design
- FPGA Design
- VHDL
- Design for Test (DFT)
- Digital IC Design
- Hardware Accelerators

---

# License

This project is released for educational and research purposes.

If you use this implementation in academic work, please cite the original EBPC paper by Cavigelli et al. as well as this repository.
