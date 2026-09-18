\# Digital Logic Design — Priority Task List Manager



Coursework project for the "Reti Logiche" course at Politecnico di Milano (grade: 30/30).



\## What it does

Implements a hardware task-list manager as a finite-state machine (FSM) in VHDL, synthesizable for FPGA. The component manages an ordered list of tasks stored in external 8-bit RAM, keeping the list sorted by priority at all times. Each task packs a 6-bit ID and a 2-bit priority into a single byte; address 0 of the RAM holds the task count. Four operations are selected via a 2-bit opcode: age every task by lowering its priority by one (saturating), extract and remove the highest-priority task, insert a new task while preserving sort order, and clear the list. Communication follows a synchronous START/DONE handshake, with an asynchronous reset.



Designed as a 16-state Mealy machine split into two processes (sequential state/register updates and combinational next-state logic) to keep the design readable and reduce the risk of unintended latches.



\## Built with

\- VHDL

\- Xilinx Vivado



\## Project structure

\- `project\_reti\_logiche\_definitivo.srcs/sources\_1/new/FSM.vhd` — main FSM module

\- `project\_reti\_logiche\_definitivo.srcs/sim\_1/new/` — RAM model and testbenches (behavioral + post-synthesis simulation)

\- `project\_reti\_logiche\_definitivo.srcs/constrs\_1/new/clock.xdc` — clock constraint



\## Run it

Open `project\_reti\_logiche\_definitivo.xpr` in Xilinx Vivado, then run behavioral simulation on any of the testbenches under Simulation Sources.

## Documentation
See [`report.pdf`](./report.pdf) for the full architecture, state-by-state description, and simulation results.

