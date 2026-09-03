# /opsx:propose — Project Audit & Refactor Proposal  ✅

## Goal
Senior-architect audit across 5 dimensions + OpenSpec proposal capturing highest-impact findings.

## Done
- [x] Explore: ARCHITECTURE.md / CORE_TURN_PIPELINE.md (clean layered intent), code structure
  (175 scripts, 1010 test methods, 13 autoloads). Confirmed NO legacy dup dirs (game/core stale in read-list).
- [x] Audit findings gathered (facts):
  - WorldController 602 lines violates "coordinators hold no heavy logic" (~200 lines of
    succession/death/resurrection/chronicle absorbed).
  - SocketController 899 lines autoload = logic monolith + global state; EADDRINUSE listen error.
  - 7 untyped Variant fields in WorldController; ServiceContainer.current global vs DI drift.
  - Pathfinding (BFS/A*/Dijkstra + MinHeap) is STRONG.
  - 1010 tests = strong coverage.

## Deliverable: change `world-controller-decoupling` (VALID)
- proposal.md — why/what/capabilities/impact
- design.md — full 5-dimension audit with before/after + refactoring table (R1–R8)
- specs/world-controller-decoupling/spec.md — 8 requirements (SHALL + scenarios), valid
- tasks.md — 6 phases, R1–R7 + verification

## Validation
- `openspec validate world-controller-decoupling --type change` → **is valid**
- (spec --type is N/A: main spec created on apply/sync, not for active change)

## Next (user decides)
- `/opsx-apply` to implement R1/R2 (High) + verification.
- Or refine open questions (0.1) first.
