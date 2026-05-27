---
name: Traian Florin Șerbănuță
email: traian.serbanuta@unibuc.ro
web: "http://cs.unibuc.ro/~tserbanuta"
github: "github.com/traiansf"
tagline: "Associate Professor · Researcher in Formal Methods · Software Engineer"
---

# Education

## PhD in Computer Science
**University of Illinois, Urbana-Champaign, 2010**

[LONG]
Dissertation: *A Rewriting Approach to Concurrent Programming Language Design and Semantics*

Advisor: Grigore Roșu

Committee: Thomas Ball, Darko Marinov, José Meseguer, Madhusudan Parthasarathy
[/LONG]

## Master in Computer Science
**University of Bucharest, 2004**

[LONG]
Dissertation: *Concepte instituționale în logica de ordinul I, teoria specificațiilor parametrizate și programarea logică*

Advisors: Răzvan Diaconescu, Virgil Emil Căzănescu
[/LONG]

## Bachelor in Computer Science
**University of Bucharest, 2002**

[LONG]
Dissertation: *Ascunderea informației în text folosind gramatici de tip LR(k)*

Advisor: Adrian Atanasiu
[/LONG]

# Experience

## Associate Professor of Computer Science
**University of Bucharest, Faculty of Mathematics and Informatics, 2013–Present**

[LONG]

Courses developed and taught, with all materials openly published:

- [Software Systems Modelling](https://traiansf.github.io/class/amss2025) — requirements analysis and modelling (UML, design patterns)
- [Declarative Programming](https://github.com/unibuc-cs/progdecl) — functional and declarative programming in Haskell
- [Concurrency in Programming Languages](https://github.com/unibuc-cs/iclp) — concurrency hands-on across Java, C++, Erlang/Elixir, JavaScript, and Python
- [Programming Languages Semantics](https://github.com/unibuc-cs/slp/tree/v2017) — operational semantics, interpreters, and type systems
- [Foundations of Programming Languages](https://github.com/unibuc-cs/flp) — lambda calculus, type systems, and logic programming (Haskell and Prolog)
- [Introduction to Machine Learning](https://github.com/unibuc-cs/dh-ml) — hands-on machine learning for non-computer-scientists (Master in Digital Humanities)

Supervise graduate students and serve on departmental committees.

[/LONG]

## Consultant and Researcher
**Pi Squared, Inc., 2024–2026**

[LONG]

Core Rust engineer on Pi Squared's verifiable-computing and universal-settlement infrastructure ("Proof of Proof"). Work spans four phases of the platform's evolution:

- **Pi² research prototype (2024)** — Metamath-based proof checkers compiled to multiple zkVM backends (RISC Zero, SP1, Nexus, Lurk, Delphinus); `mmtool` driver with checkpoint/resume; cross-backend benchmarking infrastructure; WASM build of the checker.
- **Verifiable Settlement Layer (2025)** — VSL claim model with `SubmittedClaim` quorum semantics and signed `SettledClaim`s on every state-changing endpoint; u128 asset/amount model with RLP wire format; receiver-side subscriptions and explorer endpoints; extracted the `vsl-sdk` standalone package.
- **FastSet validator + proxy (2025–2026)** — versioned-protocol releases with golden-vector wire-format tests, per-IP rate limiting with clock-race-safe refill, faucet pending-tx cleanup, structured validator-error relay with proper HTTP status codes, race-free shared test-proxy harness.
- **Fast Shop / agentic AI commerce (2026)** — Universal Commerce Protocol integration with platform profiles and cached refresh; region-aware fan-out and country inference for multi-region delivery; Shopify backend with SSRF guard and idempotent advisory-lock migrations; MCP exposure of the commerce surface.

[/LONG]

## Consultant and Researcher
**Runtime Verification, Inc., 2012–2023**

[LONG]

Long-running principal contributor across four projects:

- **K Framework — Java implementation (2014–2015)** — LTL model-checker plumbing (Promela parser, `LTLMC` API, `ProofResults`); search-graph extraction from the executor/debugger; AC matcher backed by the `assoc` attribute on function rules; builtin/binder mechanics for the Maude and Java backends.
- **RV-Predict — race & deadlock detector (2014–2017)** — maximal-causal-model predictive race detection for Java; C/C++ side via an LLVM AspectLLVM instrumentation pass with fork/lock/thread-creation event handling; scaling work pushing the variable cap to 1M.
- **K Haskell Backend — symbolic-execution prover (2018–2024)** — all-path and one-path reachability logic, SMT integration with int/bool existential translation, unification with overloaded variables and an `OverloadSimplifier`, `unboundVariables` attribute, cell-maps ceil rules. Applied to the formal semantics of the EVM, WebAssembly, and the IELE VM.
- **CBC-Casper / VLSM consensus in Coq (2022–2023)** — VLSM projections, induced validators, fixed-set and message-dependent limited equivocation, reachable-threshold non-triviality results, decidability of the constrained-state property for ELMO.

[/LONG]

[LONG]

## Postdoctoral Research Fellow
**Alexandru Ioan Cuza University, Iași (FMSE Laboratory), 2011–2013**

Formal methods research in software engineering. Coordonated the team developing the K framework.

[/LONG]

## Postdoctoral Research Associate
**University of Illinois, Urbana-Champaign (Information Trust Institute), 2011–2012**

[LONG]
Formal systems and verification research.
[/LONG]

## Research Assistant
**University of Illinois, Urbana-Champaign (FSL Laboratory), 2004–2010**

[LONG]
Assisted in research on formal semantics, rewriting logic, and programming language design. Contributed to the K framework project.
[/LONG]

[LONG]

## Teaching Assistant
**University of Bucharest, Department of Computer Science Fundamentals, 2003–2004**

Supported undergraduate courses in programming, discrete mathematics, and computer science theory.
[/LONG]

## Summer Intern
**Google, New York, 2007**

[LONG]
Co-authored a patent application on web traffic analysis methods (with Bogdan Căpriță).
[/LONG]

## Summer Intern
**Microsoft Research, Redmond (Testing, Verification, and Measurement Group), 2005**

[LONG]
Contributed an equality theory propagation core for the Zapp (currently Z3) prover
[/LONG]

[LONG]

## Programmer
**Popnet-Agentscape Romania, Natural Language Processing Team, 2000–2001**

Implemented classification algorithms for one of the first AI Agents
[/LONG]

[LONG]

# Open-source Projects

Personal research and tooling outside employer-affiliated work; full list at <https://github.com/traiansf>.

- **Formalization libraries** — [aml-in-coq](https://github.com/traiansf/aml-in-coq) (Applicative Matching Logic), [arl-in-coq](https://github.com/traiansf/arl-in-coq) (Abstract Rewrite Systems), [sets-in-coq](https://github.com/traiansf/sets-in-coq).
- **Type theory study** — [propositions-as-types](https://github.com/traiansf/propositions-as-types), Coq scribbles along *Type Theory and Formal Proofs* (Nederpelt & Geuvers); actively maintained.
- **Teaching companions** — [semantics-in-coq](https://github.com/traiansf/semantics-in-coq) and [semantics-in-lean](https://github.com/traiansf/semantics-in-lean), companions to the Foundations of Programming Languages course.
- **Schools & events** — [bucharest-lean-ac](https://github.com/traiansf/bucharest-lean-ac), Bucharest Autumn School materials in Lean 4.
- **Other** — [excel-database](https://github.com/traiansf/excel-database), a WordPress plugin (★4) that exposes an Excel spreadsheet table as queryable data.

[/LONG]

# Skills

- Formal methods and verification
- Programming language semantics

[LONG]
- Rewriting logic
- K framework
- Temporal logics
- Model checking
- Specification and verification techniques
[/LONG]

# Programming Languages

- Rust
- Haskell
- Coq / Rocq
- Java
- C / C++

[LONG]
- K / Maude
- Lean 4
- Python
- Prolog
- JavaScript / TypeScript
- PHP
[/LONG]

# Languages

- Romanian (native)
- English (fluent)
- French (basic)

# Publications

[CALLOUT]

- **36 articles** indexed in Web of Science / 41 Scopus / 55 Google Scholar
- **Hirsch index 13** (WoS) / 16 (Scopus) / 22 (Google Scholar)
- **622 citations** (WoS) / 1144 (Scopus) / 2106 (Google Scholar)

[/CALLOUT]

[LONG]
The following are the 22 most-cited publications — the works that make up the Hirsch (h) index of 22 — listed in decreasing order of citations (Google Scholar, as of May 2026). Complete and continuously updated publication and citation records are available on [Google Scholar](https://scholar.google.com/citations?user=QVLcUrcAAAAJ&hl=en) and [DBLP](https://dblp.org/pid/s/TFSerbanuta.html); the aggregate Web of Science and Scopus figures above are drawn from the corresponding author profiles in those databases.

1. Roșu, Grigore and Traian Florin Șerbănuță. "An Overview of the K Semantic Framework." *Journal of Logic and Algebraic Programming*, Vol. 79, No. 6, pp. 397-434, 2010. (cited by 639)

2. Chen, Feng, Traian Florin Șerbănuță, and Grigore Roșu. "jPredictor: a predictive runtime analysis tool for Java." *ICSE '08: Proceedings of the 30th International Conference on Software Engineering*, pp. 221-230, 2008. (cited by 154)

3. Șerbănuță, Traian Florin, Grigore Roșu, and José Meseguer. "A Rewriting Logic Approach to Operational Semantics." *Information and Computation*, Vol. 207, No. 2, pp. 305-340, 2009. (cited by 126)

4. Ștefănescu, Andrei, Ștefan Ciobâcă, Radu Mereuta, Brandon M Moore, Traian Florin Șerbănuță, and Grigore Roșu. "All-Path Reachability Logic." *Logical Methods in Computer Science*, Vol. 15, Issue 2, 2019. (cited by 114)

5. Șerbănuță, Traian Florin, Feng Chen, and Grigore Roșu. "Maximal Causal Models for Sequentially Consistent Systems." *Runtime Verification (RV'12)*, LNCS Vol. 7687, pp. 136-150, 2013. (cited by 104)

6. Luo, Qingzhou, Yi Zhang, Choonghwan Lee, Dongyun Jin, Patrick O'Neil Meredith, Traian Florin Șerbănuță, and Grigore Roșu. "RV-Monitor: Efficient Parametric Runtime Verification with Simultaneous Properties." *Runtime Verification (RV'14)*, LNCS Vol. 8734, pp. 285-300, 2014. (cited by 103)

7. Șerbănuță, Traian Florin and Grigore Roșu. "K-Maude: A Rewriting Based Tool for Semantics of Programming Languages." *Rewriting Logic and Its Applications (WRLA'10)*, LNCS Vol. 6381, pp. 104-122, 2010. (cited by 71)

8. Șerbănuță, Traian Florin. "Extending Parikh matrices." *Theoretical Computer Science*, Vol. 310, No. 1-3, pp. 233-246, 2004. (cited by 70)

9. Șerbănuță, Virgil Nicolae and Traian Florin Șerbănuță. "Injectivity of the Parikh matrix mappings revisited." *Fundamenta Informaticae*, Vol. 73, No. 1-2, pp. 265-283, 2006. (cited by 65)

10. Roșu, Grigore and Traian Florin Șerbănuță. "K Overview and SIMPLE Case Study." *Proceedings of K'11*, ENTCS Vol. 304, pp. 3-56, 2014. (cited by 64)

11. Roșu, Grigore, Wolfram Schulte, and Traian Florin Șerbănuță. "Runtime Verification of C Memory Safety." *Runtime Verification (RV'09)*, LNCS Vol. 5779, pp. 132-151, 2009. (cited by 59)

12. Șerbănuță, Traian Florin, Andrei Arusoaie, David Lazar, Chucky Ellison, Dorel Lucanu, and Grigore Roșu. "The K Primer (version 3.3)." *Proceedings of K'11*, ENTCS Vol. 304, pp. 57-80, 2014. (cited by 53)

13. Kasampalis, Theodoros, Dwight Guth, Brandon Moore, Traian Florin Șerbănuță, Yi Zhang, Daniele Filaretti, Virgil Șerbănuță, Ralph Johnson, and Grigore Roșu. "IELE: A Rigorously Designed Language and Tool Ecosystem for the Blockchain." *Formal Methods (FM'19)*, pp. 593-610, 2019. (cited by 45)

14. Șerbănuță, Traian Florin and Grigore Roșu. "Computationally Equivalent Elimination of Conditions." *Rewriting Techniques and Applications (RTA'06)*, LNCS Vol. 4098, pp. 19-34, 2006. (cited by 38)

15. Rusu, Vlad, Dorel Lucanu, Traian-Florin Șerbănuță, Andrei Arusoaie, Andrei Ștefănescu, and Grigore Roșu. "Language Definitions as Rewrite Theories." *Journal of Logical and Algebraic Methods in Programming*, Vol. 85, No. 1, pp. 98-120, 2016. (cited by 32)

16. Daian, Philip, Ylies Falcone, Patrick Meredith, Traian Florin Șerbănuță, Akihito Iwai, Shin'ichi Shiriashi, and Grigore Roșu. "RV-Android: Efficient Parametric Android Runtime Verification, a Brief Tutorial." *Runtime Verification (RV'15)*, LNCS Vol. 9333, pp. 342-357, 2015. (cited by 29)

17. Hills, Mark, Traian Florin Șerbănuță, and Grigore Roșu. "A Rewrite Framework for Language Definitions and for Generation of Efficient Interpreters." *Rewriting Logic and Its Applications (WRLA'06)*, ENTCS Vol. 176, No. 4, pp. 215-231, 2007. (cited by 29)

18. Ellison, Chucky, Traian Florin Șerbănuță, and Grigore Roșu. "A Rewriting Logic Approach to Type Inference." *Recent Trends in Algebraic Development Techniques (WADT'08)*, LNCS Vol. 5486, pp. 135-151, 2009. (cited by 28)

19. Șerbănuță, Traian Florin, Gheorghe Ștefănescu, and Grigore Roșu. "Defining and Executing P Systems with Structured Data in K." *Membrane Computing (WMC'08)*, LNCS Vol. 5391, pp. 374-393, 2009. (cited by 28)

20. Lucanu, Dorel, Traian Florin Șerbănuță, and Grigore Roșu. "K Framework Distilled." *Rewriting Logic and Its Applications (WRLA'12)*, LNCS Vol. 7571, pp. 31-53, 2012. (cited by 25)

21. Frei, Regina, Giovanna Di Marzo Serugendo, and Traian Florin Șerbănuță. "Ambient intelligence in self-organising assembly systems using the chemical reaction model." *Journal of Ambient Intelligence and Humanized Computing*, Vol. 1, No. 3, pp. 163-184, 2010. (cited by 25)

22. Șerbănuță, Traian Florin. "A Rewriting Approach to Concurrent Programming Language Design and Semantics." PhD thesis, University of Illinois at Urbana-Champaign, 2010. (cited by 24)

[/LONG]
