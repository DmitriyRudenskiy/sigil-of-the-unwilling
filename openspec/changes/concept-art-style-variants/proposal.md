# Proposal: concept-art-style-variants

## Why

The project has a written style canon (`docs/13-art-bible.md`, `docs/17-ui-style-guide.md`) and a set of
external reference images, but nothing that proves the canon is drawable end to end: every asset family
— units, buildings, signs, cursors, resources, UI screens — is still described, not drawn. The reference
directory is not one style: characters and cursors are stylized comic/cartoon, buildings, resources and
maps are hand-painted, signs are dark engraved medallions, UI is dark cinematic. The owner's rule (2026-10-15)
is that **every new image must repeat the style of one of the images in that directory** — so the style
anchor lives per category, not per project. A style chosen from a single test image is a coin flip; five
distinct, fully populated style variants, generated from one shared subject list through the remote
ComfyUI+MCP image server, give the owner a real comparison board to pick or mix from, and leave a
reproducible pipeline behind instead of a one-off prompt session.

## What Changes

- Add a machine-readable art spec (`scripts/concept_art/spec.json`): **5 style variants × 6 categories ×
  77 subjects** = 12 units, 27 buildings, 8 signs, 9 cursors, 16 resources, 5 UI screens. Subject ids come
  from game data where it exists (`buildings.json`, `ResourceType`, `docs/02c-signs.md`) and are extended
  where the brief exceeds the current roster (27 buildings vs 18 built, 16 resources vs 8 registered,
  9 cursors vs 6 live modes).
- Anchor style per category: each category names its `reference` image from the reference directory and
  carries the wording that describes that reference's manner. A variant clause may move only the rendering
  technique (line, fill, light, finish) — never subject, proportions, palette or materials, which belong to
  the reference. Prompt layering: category style → variant technique → category frame → subject.
- Add a resumable generator (`scripts/concept_art/generate.py`) that drives the ComfyUI MCP server at
  `192.168.0.230`: deterministic per-subject seed, skip-existing resume, retry with a reseeded attempt,
  WEBP q82 export, per-run manifest (prompt / seed / model / timings / server filename), and review-board
  modes that always place a category's reference next to its frames.
- Produce **385 concept images** (5 × 77) at 1024×1024 (isolated assets, near-white background) and
  1280×720 (UI screens) under `concept_art/<variant>/<category>/<id>.webp`.
- Add `docs/18-concept-art-variants.md`: the five variants as style candidates — which reference image each
  category repeats, what each variant moves in rendering technique relative to it, what it deliberately
  drops, and the pick/mix decision record.
- **Non-goals:** no game code, no `game/assets/**`, no runtime theme or StyleBox changes. Concept art stays
  outside the asset pipeline; a chosen variant becomes real assets only through a later change that runs the
  `game/tools` generation path and the provenance gate.

## Capabilities

### New Capabilities

- `concept-art-pipeline`: spec-driven concept-art production — the reference anchors per category, the
  variant catalogue, the subject catalogue, deterministic seeding, resumable generation against the MCP
  image server, export format and size contract (near-white background calibrated against the reference),
  the run manifest, and review boards that pair every frame with the reference it must repeat.

### Modified Capabilities

None. No runtime behaviour changes: `icon-system`, `cursor-system` and `ui-graphics` keep their requirements
and consume art only after a later, separate asset change.

## Impact

- **Tooling:** new `scripts/concept_art/` (`spec.json`, `generate.py`, `README.md`). Reuses the already
  installed `mcp` Python SDK and Pillow — no new dependency.
- **Docs:** new `docs/18-concept-art-variants.md` + `docs/CHANGELOG.md` entry. `docs/13-art-bible.md` gains a
  pointer only after the owner picks a variant.
- **Storage:** ~60–90 MB of WEBP under `concept_art/`, gitignored (repo weight + tight disk); `.gitignore`
  gains one entry. Scripts, spec and manifest are the committed reproducible artifact.
- **External:** remote GPU host `192.168.0.230` (ComfyUI `:8188`, MCP `:9000`). Roughly 9 h of queued,
  serial generation at measured speeds (Krea-2 1024² ≈ 80 s, Qwen 2.1 1280×720 ≈ 170 s). No server-side
  workflow changes.
- **Verification:** automated image gates inside the generator (exact pixel size, near-white background
  ratio measured against the reference, non-empty file, manifest completeness) plus `read`-based visual
  review. Style is reviewed as a board where each row starts with the category's reference image, and a
  style probe board (one subject per category × all variants) gates the full run. Rejected frames move to
  `concept_art/_reject/` instead of being deleted, so prompt iteration has evidence. Style quality is not
  headless-verifiable → owner review is the acceptance gate.
