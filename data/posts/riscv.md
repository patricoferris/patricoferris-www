---
title: A Short Introduction to RISC-V 
description: Keep it simple unless for good reason.
date: 2021-01-14
authors: 
  - Patrick Ferris
topics:
  - hardware
  - risc-v
reading: 
  - name: "The RISC-V Reader: An Open Architecture Atlas"
    description: A very thorough and well-explained ISA manual by David Patterson and Andrew Waterman from which a lot of the technical details of this post were derived. 
    url: http://www.riscvbook.com/ 
---

"Keep it simple unless for good reason" is how Turing Award winning and vice chair of the board of directors of the RISC-V Foundation, [David Patterson](https://en.wikipedia.org/wiki/David_Patterson_%28computer_scientist%29), explained the underlying principles of the reduced instruction set computer (RISC) in [1985](https://www.youtube.com/watch?v=5NjGLyBx0wg). This short post explores the fundamental characteristics of RISC-V, how it differs from more conventional instruction set architectures (ISAs) and peppered throughout are interesting technical tibits about the design of RISC-V. This is in no way complete, if that's what you are after then [the latest specification](https://riscv.org/technical/specifications/) is probably what you want.

## Abstraction

A timeless quote attributed to the great [David Wheeler](https://en.wikipedia.org/wiki/David_Wheeler_(computer_scientist)) is often used again and again within the field of computer science.

> All problems in computer science can be solved by another level of indirection

The extent to which this idea permeates all areas of problem-solving particularly in computer science is hard to express. The fundamental principle is abstraction. Whether that be in the [various layers of the OSI network model](https://en.wikipedia.org/wiki/OSI_model), [declarative languages for performing database queries](https://www.infoworld.com/article/3219795/what-is-sql-the-lingua-franca-of-data-analysis.html) or in this case telling a computer what to do.

An ISA is bridge between hardware and software -- the hardware-software interface. It provides a framework and philosophy for designing hardware and compiling languages. ISAs are divided into two fairly over-simplified but useful camps: reduced (RISC) and complex (CISC) instruction set computers. [x86](https://en.wikipedia.org/wiki/X86) would be the classic CISC architecture known for its [enormous number of instructions](https://fgiesen.wordpress.com/2016/08/25/how-many-x86-instructions-are-there/#:~:text=To%20not%20leave%20you%20hanging,too%2C%20by%20the%20way) and [licensing](https://jolt.law.harvard.edu/digest/intel-and-the-x86-architecture-a-legal-perspective). 
RISC-V in contrast, is a free and open-source ISA specification. You are free to take it and do what you will with it.

## A Broad Overview

Before diving into interesting characteristics and design decisions, it's useful to have a broad understanding of what RISC-V is. 

It is a free and open-source ISA that follows the reduced instruction set philosophy of favouring simplicity over complexity. The ISA grew out of the [Parallel Computing Laboratory](https://riscv.org/about/history/) at UC Berkeley starting in 2010. 

An ISA is the hardware-software interface. Compiler writers adhere to the specification by outputting semantically correct assembly instructions and hardware designers follow the same specification for interpreting these instructions. Some of the defining characteristics of RISC-V are: 

 - Simplicity
 - Modularity
 - Extensibility

These work hand-in-hand to make RISC-V not only a great platform for developing modern technological solutions, but also perfect for academic research and education, as we'll see.

## Simplicity

A RISC architecture does not imply simplicity. It is quite possible to bake-in complex behaviour into a seemingly reduced or simple specification. RISC-V opts to follow the principle "keep it simple unless for good reason". This manifests itself in a number of ways. 

### Fixed-width and specifier location-sharing formats

An instruction encoding format is how different types of instructions (branches, register-register operations etc.) are represented at the lowest possible level -- bits. RISC-V's instruction encoding format uses just six types and all are 32-bits wide, this can vastly reduce the complexity of the decoding logic in a CPU. Moreover, the register locations (i.e. the bit ranges where the register values are kept within the instruction) are the same across the formats. For performance, this allows registers to be accessed before decoding even begins which can help reduce the critical time path. 

<div class="diagram-container">
  <a href="/posts/riscv/diagrams/instr.svg">
    <img class="diagram" style="width: 100%" alt="An example of location-sharing between formats" src="/posts/riscv/diagrams/instr.svg" />
    <p><em>Figure: A diagram indicating the location-sharing between R-type and I-type instruction formats.</em></p>
  </a>
</div>

This is also seen in the immediate fields, the most significant bit of any of them is always the 32nd bit of the instruction making sign-extension logic simpler and potentially faster. All RISC-V immediates are sign-extended using the most significant bit and this can
provide simpler instruction patterns. 

Consider a small example: 

```
int drop_byte (int n) {
  return n & 0xFFFFFF00;
}
```

Which when compiled with [RISC-V 64-bit compiler with `-O3`](https://godbolt.org/z/res4dG) gives:

```
andi    a0,a0,-256
ret
```

No extra logic is needed with the immediate (`0xFFFFFF00`) because it is automatically sign-extended to `0xFFFFFFFFFFFFFF00`. On MIPS architectures this is not the case as logical operations are zero-extended (p.45 of [MIPS IV Instruction Set](https://www.cs.cmu.edu/afs/cs/academic/class/15740-f97/public/doc/mips-isa.pdf)).

The B-type instruction exemplifies the careful decision-making that has taken place for the different formats: 

<div class="diagram-container">
  <a href="/posts/riscv/diagrams/btype.svg">
    <img class="diagram" style="width: 100%" alt="The B-type instruction format" src="/posts/riscv/diagrams/btype.svg" />
    <p><em>Figure: Location-sharing, MSB-bit in place 31 and dropped lower bit of the B-type instruction.</em></p>
  </a>
</div>

Here we can see: 

 - The most-significant bit of the immediate is located at the 32nd bit of the instruction. 
 - The registers are in the same place as the other instructions.
 - The lower bit (`imm[0]`) is left out, this is because the relative branching offset is performed in multiples of 2 bytes. The RISC-V architecture is word-aligned — on a 32-bit architecture this amounts to instructions being stored at multiples of 4 bytes but because of 16-bit compressed format they can be on 2 byte boundaries.


### A good reason for complexity

Although not part of the general-purpose extension ( G ), the compressed instruction format ( C ) specification is often implemented. With this extension we lose the property of fixed-width instructions introducing complexity at the front-end of CPUs during instruction fetch and decode. [Ariane's increased complexity](https://cva6.readthedocs.io/en/latest/id_stage.html) illustrates this perfectly indicating the four scenarios: two compressed instructions in the 4 bytes of a regular instruction, a regular instruction misaligned by two sandwiching compressed instructions, a series of unaligned regular instructions or just a regular instruction. So what's the good reason for this? Andrew Waterman has the answer in his master's thesis ["Improving Energy Efficiency and Reducing Code Size with RISC-V Compressed"](https://people.eecs.berkeley.edu/~krste/papers/waterman-ms.pdf). The major improvements are: 

 1. Fewer instruction bits are fetched in general by encoding common instructions in only half the size of a regular instruction. 
 2. Code size is greatly reduced when using the compressed extension. 
 3. Cache misses are more rare because the instruction working set is reduced (less pressure on the instruction cache).

Whilst all good reasons for RVC existing, the modularity of the ISA allows for very small implementations (say in a micro-controller or FPGA) to forgo the additional logic. This is another key principle of RISC-V.

## Modularity

The RISC-V ISA is designed to be modular. Instructions are broken into distinct extensions which are named (and often referred to by the first letter of that name). For example there is the set of instructions that allow multiplication operations (including division and remainders) aptly named `M`.

### Combinations

RISC-V extensions can be combined in order to give more powerful ISAs. Take, for example, RV32G (RV32IMAFD) which combines many of the necessary extensions for writing general-purpose CPUs that can afford complex ALUs and floating-point units (FPUs). Another example is the ability to work backwards like the, yet unratified, RV32E base integer extension. Here, only after finding a desire for an even smaller base ISA than RV32I did the RISC-V specification writers decide to include a draft for RV32E with only 16 integer registers for smaller applications. This could still be combined with others.

### Optional features

The base integer extension ( I ) is the cornerstone of all the other ones. This tends to be the bare minimum you need to implement in order to have a useful CPU encompassing instructions like `add`, `xor`, `lw` (load word) and `beq` (branch equal). With this comes 32 integer registers (`x0-x31`) with `x0` hardwired to 0. But note even here the simplicity in design is apparent, there are no multiplication instructions. This would require additional circuitry for the ALU which should be optional rather than mandatory in RISC-V implementations. Not all problems require blazing fast performance; cost (small IoT devices), complexity (teaching) and size (fitting on a small FPGA) are all equally valid requirements that RISC-V can accommodate thanks to its modularity.

The [Ibex core](https://ibex-core.readthedocs.io/en/latest/01_overview/compliance.html) is a perfect example of how modularity with compile-time configurations can enable a very flexible core to fit many "...embedded control applications". Multiplication can be enabled, compressed instructions can be enabled and even the (at the time of writing) unratified bit manipulation extension can be enabled depending on the intended use of the core. As if by magic, we have stumbled upon yet another key principle of RISC-V, extensibility.

## Extensibility

Purposefully leaving plenty of opcode space combined with being open-source and modular enables RISC-V's extensibility. This is by far the most interesting and powerful area of active research (and fun-filled tinkering) that RISC-V has to offer. 

Modern ISAs (such as *x86*) try to do everything. This can make them extremely powerful, but also bloated due to backwards compatibility guarantees, not to mention confusing for many at the start. The classic example of this is *x86* [AAA](https://www.felixcloutier.com/x86/aaa) instruction for [binary-coded decimal](https://en.wikipedia.org/wiki/Intel_BCD_opcode) which is rarely used anymore but the method of deprecation is more confusing than that of the modular, extensible RISC-V. 

### Examples

There are quite a few examples of extending the RISC-V ISA in order to benefit hardware-accelerators. In "[A near-threshold RISC-V core
with DSP extensions for scalable IoT Endpoint Devices](https://arxiv.org/pdf/1608.08376v1.pdf)" as part of the parallel ultra-low power (PULP) platform, they introduced DSP instructions. One example instruction they add is `p.add` which perform register addition with round and normalization by a specific number of bits (see Table I of the paper).

As a shameless plug, the curious reader might be interested in [my dissertation](https://github.com/patricoferris/riscv-o-spec) which looked at creating OCaml-specific instructions.

## Education 

RISC-V's simplicity, open-source ideology and modularity all combine in such a way to make it extremely useful in an academic setting. Not only for research (new CPU designs, custom extensions, tools etc.) but for undergraduates (like myself) where the smaller size and ability to look at many examples of RISC-V compatible hardware designed in Verilog makes it more accessible. 

### Learn by doing

[FemtoRV](https://github.com/BrunoLevy/learn-fpga/tree/master/FemtoRV) is a simple RISC-V CPU and teaching the basics of CPU design and FPGA synthesis by [Bruno Levy](https://twitter.com/BrunoLevy01). The repository takes you through the process of implementing this little CPU on a $40 FPGA, whilst learning practical skills because RISC-V is a industrial-strength ISA.

You can also have a look at some [OCaml RISC-V Dockerfiles](https://github.com/patricoferris/ocaml-on-riscv) I wrote so you can cross-compile OCaml code to RISC-V and run it on the RISC-V ISA Simulator, [Spike](https://github.com/riscv/riscv-isa-sim).

## Conclusion

The future is increasingly looking like one where RISC-V plays a major role. Perhaps not directly in large, consumer markets like laptops but certainly in the embedded space and within academia. RISC-V's extensibility and open license make it ideal for application specific hardware likes ASICs or FPGAs as it forms a solid based from which to customise and freely use. 

If you're interested in seeing some interesting use cases of RISC-V be sure to have a look at: 

 - [Shakti](https://shakti.org.in/) -- an open-source processor development ecosystem from the Indian Institute of Technology Madras (IITM). In particular their [Shakti-T](https://dl.acm.org/doi/10.1145/3092627.3092629) for protecting against temporal and spatial memory and [Shakti-MS](https://dl.acm.org/doi/10.1145/3316482.3326356) where device foot-print and power consumption are not compromised when adding additional security mechanisms to the CPU.
 - [PULP](https://www.pulp-platform.org/) -- the parallel, ultra-low power platform building open-source largely RISC-V based hardware. One example is [PULPino](https://github.com/pulp-platform/pulpino) a single-core micro-controller with many different configurations like `RV32IC`, `RV32IMC` or `RV32ICE`.
 - [SERV](https://serv.readthedocs.io/en/latest/#) -- an award-winning, bit-serial RISC-V CPU. The [video](https://diode.zone/videos/watch/0230a518-e207-4cf6-b5e2-69cc09411013) is amazing!