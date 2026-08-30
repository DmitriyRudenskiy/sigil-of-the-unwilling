# ComfyUI image generator (`comfy_generate.py`)

A small Python client that connects to a ComfyUI instance, builds a txt2img
workflow, executes it over the HTTP + websocket API, and downloads the PNG.

```bash
pip install websocket-client

# simplest (defaults to a FLUX model wired via CLIPTextEncodeFlux)
python3 comfy_generate.py --prompt "a cozy medieval tavern at dusk" --output ./tavern.png

# pick a model explicitly
python3 comfy_generate.py --prompt "a castle" \
    --ckpt "FLUX.1\crux_V1.safetensors" --steps 8 --cfg 3.0 --sampler euler \
    --scheduler normal --output ./castle.png

python3 comfy_generate.py --list-checkpoints
```

## Why the workflow is "modular"

The target server keeps every model as split pieces — there are **no combined
checkpoints** (`/api/models/checkpoints` is empty). So instead of a single
`CheckpointLoaderSimple`, the client wires the loaders directly:

* **FLUX models** (`FLUX.1\...`) → `UNETLoader` + `VAELoader` +
  `CLIPTextEncodeFlux` (dual `clip_l` + `t5xxl` conditioning) + `KSampler` +
  `VAEDecode` + `SaveImage`.
* **Other diffusion models** → `UNETLoader` + `CLIPLoader` + `VAELoader` +
  `KSampler` + `VAEDecode` + `SaveImage`.

## Server-specific notes

* `CLIPTextEncodeFlux` loads its two encoders internally, so the clip names are
  passed **without** the `.safetensors` suffix (e.g. `clip_l`,
  `googleFLANT5xxlPrunedFor_fp32`). Passing the full filename makes the node
  fail with `'str' object has no attribute 'tokenize'`.
* The `guidance` input of `CLIPTextEncodeFlux` plays the role of the sampler
  CFG, so it is set to the same value as `--cfg`.
* FLUX model names in `UNETLoader` keep the `FLUX.1\` subfolder prefix.
* Working pairing on this server: `FLUX.1\crux_V1` + `clip_l` +
  `googleFLANT5xxlPrunedFor_fp32` + `flux2-vae`.

## Notes

* The server's `FluxGuidance` node has a non-standard signature, so the client
  uses `CLIPTextEncodeFlux` for FLUX dual-CLIP combination instead.
* `build_prompt(..., mode="ckpt"|"modular"|"auto")` is available for callers
  that want an explicit workflow; the CLI defaults to `auto`.
