#!/bin/bash

# RTL source
mkdir -p rtl

# Verification environment
mkdir -p tb/common
mkdir -p tb/interfaces
mkdir -p tb/agent
mkdir -p tb/checking
mkdir -p tb/coverage
mkdir -p tb/assertions
mkdir -p tb/environment
mkdir -p tb/tests
mkdir -p tb/top

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
