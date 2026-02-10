# NoGPU Mini-LLM in VHDL

A fully synthesizable **VHDL implementation of a tiny language-model–style neural network**, capable of **on-chip training and inference using fixed-point arithmetic**, with **no GPU and no floating-point units**.

This project demonstrates how core machine-learning ideas can be implemented directly in **digital hardware**, emphasizing RTL design, datapath/control separation, and verification through simulation.

---

## Project Overview

This design performs a **simple language-response prediction task**:

- Input: a short text phrase encoded as an **8-bit feature vector**
- Output: a **one-hot encoded reply class**
- Training and validation occur **on chip**, using a perceptron-style learning rule

The system converges quickly and halts training early once all samples are classified correctly.

---

## Key Features

- **Pure VHDL implementation** (no software ML libraries)
- **Fixed-point arithmetic** (Q-format) throughout
- **On-chip weight and bias updates**
- Modular RTL design:
  - Forward network
  - Update units
  - Control FSM
  - ROM-based dataset
- Fully verified using **testbenches and waveforms**
- Designed and simulated in **EDA Playground (Aldec Riviera-PRO)**

---

## Architecture

High-level pipeline:

1. Input sentence → 8-bit Q4.4 feature vector  
2. Hidden layer: `ReLU(W1 · x + B1)`  
3. Output layer: `W2 · h + B2`  
4. Argmax selects predicted reply  
5. Error computed and weights updated if prediction is incorrect  

The control FSM manages:
- Training vs validation phase
- Epoch and sample indexing
- Weight update enable signals

Architecture diagrams and waveforms are available in the `documentation/` folder.

---

## Fixed-Point Formats

| Signal | Format |
|------|--------|
| Input features `x` | Q4.4 |
| Weights `W1`, `W2` | Q8.8 |
| Biases `B1`, `B2` | Q8.8 |
| Hidden MAC accumulator | Q12.12 |
| Output MAC accumulator | Q16.16 |

All arithmetic is synthesizable and FPGA-friendly.

---

## Dataset & Task

The model predicts one of four replies:

| Encoding | Reply |
|--------|------|
| `0001` | “Hey there!” |
| `0010` | “Take a short break.” |
| `0100` | “Get some rest.” |
| `1000` | “Good night!” |

- 4 training phrases  
- 2 validation phrases  
- Encoded and stored directly in ROM  

Training stops early once all samples are classified correctly (converges at **epoch 2**).

---

## Repository Structure

documentation/
├─ Architecture poster/
├─ images/
├─ presentation/

src/
├─ core/ # forward network, FSM, argmax
├─ math/ # fixed-point + activation units
├─ memory/ # ROM and weight registers
├─ update/ # hidden + output weight updates
├─ top/ # testbench


---

## How to Run (EDA Playground)

1. Go to **https://edaplayground.com**
2. Language: **VHDL**
3. Simulator: **Aldec Riviera-PRO**
4. Enable **“Open EPWave after run”**
5. Upload all VHDL files from `src/`
6. Set top entity to `testbench`
7. Run simulation and inspect waveforms

Waveforms demonstrate:
- Correct forward inference
- Error detection
- Weight updates
- Training convergence
- Validation correctness

---

## Demo & Documentation

- 📄 Architecture poster and design explanation: `documentation/`
- 📊 Simulation waveforms: `documentation/images/`
- 🎥 Demo video: see YouTube link in the repository

---

## Skills Demonstrated

- VHDL / RTL design
- FPGA-oriented fixed-point arithmetic
- Digital datapath & control FSM design
- Hardware-based machine learning
- Verification using testbenches and waveforms
- System-level hardware architecture

---

### Authors
Ahmed Elag  
Marc Niven  

*This project was originally completed as part of a university course and is shared for educational and portfolio purposes.*
