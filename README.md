# Special Form Signal Generator (FPGA)

*[Русская версия](README_ru.md)*

## Overview
This repository contains the RTL design and verification environment for a special form signal generator based on programmable logic devices. This project was developed as a diploma thesis.

The core logic is implemented in **SystemVerilog**.

## Features
* Generation of various special form signal waveforms.
* Fully synthesized RTL design written in SystemVerilog.
* Hardware target: Artix-7 FPGA.

## Technologies & Tools
* **HDL:** SystemVerilog
* **Target Device:** Xilinx Artix-7 FPGA
* **Simulation:** Questa
* **Synthesis:** Vivado

## Project Structure
* `/src` - SystemVerilog source files (RTL).
* `/tb` - Testbenches for verification.

## Getting Started
1. Clone the repository: `git clone https://github.com/437d5/fpga-waveform-generator.git`
2. Run simulation: `make sim`