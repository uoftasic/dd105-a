# DD105-A — Testbenches with UVM

In this course you build testbenches for a small packet router from separate parts: a driver that
sends packets into the router, a monitor that turns the handshakes on each stream into packets, and
a scoreboard that predicts what comes out and checks it. In Lab 02 the course gives you the driver,
and you write the monitor and the scoreboard as plain SystemVerilog classes. In Lab 04 you finish a
UVM version of the same testbench. Both testbenches run on Verilator.

DD105-A is part of the UofT ASIC Team education materials, published at
<https://uoftasic.com/dd105-a/>. The labs run in the workbench: the IIC-OSIC-TOOLS container you
start from the `workspace` clone you set up in [IC101](https://uoftasic.com/ic101/). You get this
course's files with the workbench's `mod` command (`mod add dd105-a`), and
[Lab 01, Part 1](labs/lab-01-one-alu-two-testbenches-overview.md#part-1-load-the-course) walks you
through it.

## Who this course is for

You have finished [DD104](https://uoftasic.com/dd104/), where you wrote flat cocotb tests in Python
that found all thirteen bugs planted in SimProc. The testbenches in this course keep the stimulus
apart from the checking and let you choose the test when you run it, so that you can reuse and
extend them. On your own runs you measure what that structure costs in lines of code and build
time, and what each testbench catches.

The router was written for the course. It is about 730 lines of SystemVerilog: one input stream,
two output streams with their own buffers, a routing table, drop counters and an interrupt behind
an APB register port, and fifteen one-line bugs planted behind a switch you set when you run.
Lab 01 starts on a design you already know, SimProc's ALU from DD104, with its three ALU bugs. By
the end of Lab 07 your UVM environment catches all fifteen of the router's bugs, and you have
written a verification plan and a verification report.

| | |
|---|---|
| Track | Digital |
| Prerequisites | [DD104](https://uoftasic.com/dd104/), and through it [IC101](https://uoftasic.com/ic101/) and DD101 to DD103 |
| Tools | Verilator 5.050, Yices 2.7.0 as its constraint solver, and Surfer for waveforms, all in the workbench image `hpretl/iic-osic-tools:2026.08`, and the UVM 2020-3.2 library, which ships in this course's repository. Lab 01 also runs cocotb 2.0.1 on Icarus Verilog 14.0. |
| Machine | The workbench you already have. Every time on these pages was measured with 2 CPUs and 3 GB: a testbench's first build takes about 2 minutes, a rebuild after an edit from about 10 s to about 2 minutes, and a run a few seconds. The longest step, Lab 07's regression, takes about 4 minutes. |
| Total time | About 21 hours, self-paced. The Course path rows below add up to 21 h 10 min: 15 h of labs and 6 h 10 min of reading. The lab times are the ones the lab writeups give. The reading times are our estimates, from the length of each page at about 130 words a minute, plus time for its figures and examples. <!-- READTIME: each Read row is the sum over its pages of (words outside code blocks / 130 + 2 min per figure + 1 min per 10 lines of code or output), rounded to 5 min; counted Nov 16, 2026. --> |

## Course path

Work down this table in order. A Read row is a set of guide pages, which are for reading only and
have no commands in them. A Do row is one lab writeup, and the lab writeups are where every
command in the course lives. Each lab's "Before you start" section repeats which pages it expects
you to have read.

| # | | What | Time |
|---|---|---|---|
| 1 | Read | [Getting started](guide/getting-started.md) · [What a framework buys you](guide/what-a-framework-buys-you.md) · [From cocotb to SystemVerilog classes](guide/from-cocotb-to-systemverilog-classes.md) | 55 min |
| 2 | Do | [Lab 01: One ALU, two testbenches](labs/lab-01-one-alu-two-testbenches-overview.md). Test SimProc's ALU with DD104's cocotb test and with a UVM testbench, measure what each costs, and extend the UVM scoreboard until it catches the flags bug. | 1 h 30 min |
| 3 | Read | [Classes for testbenches](guide/classes-for-testbenches.md) · [Interfaces, clocking blocks and virtual interfaces](guide/interfaces-clocking-blocks-and-virtual-interfaces.md) · [Threads, mailboxes and events](guide/threads-mailboxes-and-events.md) | 1 h 10 min |
| 4 | Do | [Lab 02: A class testbench without UVM](labs/lab-02-a-class-testbench-without-uvm-overview.md). Write the monitor and the scoreboard of a class testbench for the router, catch two planted bugs, and find out what each catch depends on. | 2 h |
| 5 | Read | [Constrained random on Verilator](guide/constrained-random-on-verilator.md) · [Functional coverage you can read](guide/functional-coverage-you-can-read.md) | 40 min |
| 6 | Do | [Lab 03: Constraints and coverage](labs/lab-03-constraints-and-coverage-overview.md). Add a covergroup, constrain the packet until the simulator produces the lengths you ask for, and reach the two coverage holes where this lab's bugs hide. | 1 h 30 min |
| 7 | Read | [The UVM skeleton](guide/the-uvm-skeleton.md) · [Sequences, sequencers and drivers](guide/sequences-sequencers-and-drivers.md) · [Monitors, analysis ports and scoreboards](guide/monitors-analysis-ports-and-scoreboards.md) · [The factory and config_db](guide/the-factory-and-config-db.md) | 1 h 20 min |
| 8 | Do | [Lab 04: The same testbench in UVM](labs/lab-04-the-same-testbench-in-uvm-overview.md). Finish a UVM port of your Lab 03 testbench, inject errors with a factory override, and count what the structure cost in lines. | 2 h 30 min |
| 9 | Read | [Assertions for interface rules](guide/assertions-for-interface-rules.md) · [Reactive agents and backpressure](guide/reactive-agents-and-backpressure.md) · [Virtual sequences](guide/virtual-sequences.md) | 1 h |
| 10 | Do | [Lab 05: Protocol rules and backpressure](labs/lab-05-protocol-rules-and-backpressure-overview.md). Bind assertions for the output rules into the router, finish a sink that answers each beat in its own time, and write a virtual sequence that catches the third bug. | 2 h |
| 11 | Read | [Register models](guide/register-models.md) · [Regressions and seeds](guide/regressions-and-seeds.md) | 35 min |
| 12 | Do | [Lab 06: The register block](labs/lab-06-the-register-block-overview.md). Give the testbench a register model with an adapter and a predictor, run UVM's reset and bit-bash sequences, and check the interrupt, until all five register bugs are caught. | 2 h |
| 13 | Read | [Verification plans and sign-off](guide/verification-plans-and-sign-off.md) · [Writing the verification report](guide/writing-the-verification-report.md) | 30 min |
| 14 | Do | [Lab 07: Capstone](labs/lab-07-capstone-overview.md). Write a verification plan, run a seed regression, hunt mystery builds, and close the holes until all fifteen bugs are caught, then write the verification report. | 3 h 30 min |

Keep these reference pages open in a tab while you work. They're for looking things up rather
than for reading start to finish:

- [The router in one page](reference/the-router-in-one-page.md)
- [The packet router](reference/router-spec.md), the router's full specification
- [The UVM register layer](reference/register-layer.md)
- [Getting the tools outside the course image](reference/getting-the-tools-outside-the-course-image.md)

## pyuvm and DD105-B

This course uses UVM in SystemVerilog only. Its sibling course, DD105-B, covers pyuvm, the Python
version of UVM, which is in the workbench image (version 4.0.1). In the research for these courses,
a UVM environment for the ALU written in pyuvm built in 17 s, because Verilator then compiles only
the design. The SystemVerilog version compiles the whole UVM library with it, which takes about
100 s from cold with this course's build settings.

## Getting help

Ask in the [team Discord](https://discord.gg/hrJnP5UsGz); nobody expects you to work all of this
out alone. Say which lab and step you're on, paste the command you ran and what it printed, and
attach the `run.log` from the run folder if the question is about a simulation.
