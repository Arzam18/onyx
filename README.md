# Onyx 2.0

A UCI chess engine, ~3390 blitz strength (CCRL-equivalent estimate), written entirely by AI
agents (Anthropic's Claude and OpenAI's Codex) working under human
direction. Every line of engine code is original to this project - nothing
was copied from Stockfish or any other engine. The NNUE network is trained
exclusively on Onyx's own self-play data, generated and trained on free
cloud compute.

Formerly named "Sable" (v1.0-1.7); renamed Onyx from v1.8.

## Files

- `onyx-2.0-win-avx2.exe`    - Windows x64, AVX2 (2013+ CPUs; recommended)
- `onyx-2.0-win-generic.exe` - Windows x64, any CPU (slower)
- `onyx.nnue`                - the gen8 neural network - KEEP NEXT TO THE EXE
- `book.bin`                 - small Polyglot opening book (optional;
                               engine plays without it, UCI OwnBook toggles)
- `onyx.cpp`                 - complete source, one file

## Install

Point any UCI GUI (Arena, Cute Chess, En Croissant, Banksia) at the exe.
Keep `onyx.nnue` in the same folder. Options: Hash (MB), Threads, OwnBook,
EvalFile, plus exposed search-tuning spins (leave at defaults).

## Build from source

Desktop x86-64:

    g++ -std=c++17 -O3 -march=native -pthread onyx.cpp -o onyx

Android ARM64 (Android NDK r27c, API 24):

    bash scripts/build_android_arm64.sh

The Android build targets baseline ARMv8-A + NEON. The NNUE uses NEON for
16-bit accumulator updates and exact 32-bit evaluation products. On Linux/
Android AArch64, an SDOT output-layer kernel is selected at runtime only when
the CPU advertises Dotprod and every loaded output weight fits signed int8.
The SDOT kernel splits clipped activations into an exact signed-byte value
plus a correction term; it does not quantize or modify the network. Other
AArch64 CPUs and networks use the exact NEON path. x86-64 retains its AVX2
backend and scalar fallback.

The build workflow publishes the engine executable only. Keep `onyx.nnue`
(and optionally `book.bin`) next to the executable, as described above.

## Strength

- 1,000 games vs Stash 34.0 (CCRL Blitz 3328) at 10s+0.1s:
  **+62.9 +/- 17.1 Elo** (58.95%).
- Onyx 2.0 vs Onyx 1.8 at fixed 20k nodes/move: ~+280 Elo across the
  campaign's SPRT-gated changes (12 accepted search/eval changes plus the
  gen8 network; every change validated by sequential probability ratio
  tests on disjoint fresh opening suites).

## Architecture (v2.0)

- Bitboards with magic move generation; single-file C++17.
- NNUE 768->768x2->1 (CReLU, int16 SIMD), fused AVX2 or AArch64 NEON
  accumulator updates, per-ply accumulator stack. Runtime SDOT is available
  for networks whose output weights fit signed int8. Net trained with
  lambda-blended WDL/score
  targets on 97.5M self-play positions (~200M-position successor training
  in progress).
- PVS/alpha-beta: aspiration windows, TT with depth/bound-aware same-key
  replacement, quiescence TT, singular extensions + multicut, null-move
  pruning, razoring, reverse futility, futility + history + late-move
  pruning with quiet-check guards, SEE pruning of quiets and captures
  (threshold SEE fast path), killer/counter/continuation/capture history,
  and four static-eval correction histories (pawn-structure, previous-move,
  non-pawn placement per color, pawn-king).
- All search constants machine-tuned via SPSA match-play (no hand-copied
  values).

## License

MIT. (c) 2026 Dylan Hogarth and contributors (AI-generated code
directed and validated by the project owner).
