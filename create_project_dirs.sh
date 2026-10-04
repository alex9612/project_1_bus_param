#!/bin/bash

# RTL source
mkdir -p rtl

# Verification environment: source files live directly in tb.
mkdir -p tb

# Simulation infrastructure
mkdir -p sim/scripts

# Documentation
mkdir -p docs/specification
mkdir -p docs/verification_plan

# Auxiliary scripts
mkdir -p scripts/gnuplot

# Generated results
mkdir -p results/logs
mkdir -p results/waves
mkdir -p results/coverage
mkdir -p results/csv
mkdir -p results/plots

echo "Project directory structure created successfully."
