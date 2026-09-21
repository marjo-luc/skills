# Validating and test-running

Two gates, both run by the Action. Reproduce them locally before pushing.

```bash
~/.claude/skills/ogc-app-pack/scripts/validate_cwl.sh my_algo/cwl_workflows/process_<name>_<branch>.cwl
```

Or directly, inside the generator venv:

```bash
cwltool --validate --strict --verbose <cwl>    # CWL syntax + schema
ap-validator --detail all <cwl>                 # OGC best-practice conformance
ap-validator --format json <cwl>                # machine-readable, for parsing issues
```

Clean OGC result:

```json
{ "valid": true, "issues": [], "requirements": {} }
```

Failing result — `req` points at the OGC best-practice requirement, and `requirements` spells it out:

```json
{
  "valid": false,
  "issues": [{ "type": "error", "message": "Missing element for Workflow 'x': doc", "req": "req-9" }],
  "requirements": { "req-9": "The Application Package CWL Workflow class SHALL contain the following elements: Identifier ('id'); Title ('label'); Abstract ('doc')." }
}
```

**Always fix validator failures in `algorithm_config.yml` and regenerate.** Editing the CWL directly
works until the next push, when the Action regenerates and commits over it.

## Decoding failures

| Message | Cause | Fix in config |
|---|---|---|
| `Missing element for Workflow: doc` (req-9) | `algorithm_description` absent → `doc: null` | Add `algorithm_description` |
| `Missing element for Workflow: label` / `id` (req-9) | `algorithm_name` absent | Add `algorithm_name` |
| Missing `s:` metadata | The matching config key is absent; the generator warns and leaves `null` | Add the key — see the mapping table in `algorithm-config.md` |
| `Field 'dockerPull' contains undefined reference` / `null` | `DOCKER_TAG` wasn't set when generating | Use `scripts/generate_cwl.py`, which derives it, or set `algorithm_container_url` |
| `Duplicate input parameter name 'x'` (ValueError, generation aborts) | Two inputs share a `name` | Rename one |
| `invalid field 'type', expected one of ...` | Unsupported CWL type string | Use a type from the table in `algorithm-config.md` |

Check the generator's stderr too: it logs `Expected key 'x' not found in algorithm config.` for
every missing top-level key, which usually explains a validator failure before the validator runs.

## Test-running locally

Needs `cwltool` (the generator venv has it) and a container engine that is **already installed** —
check with `command -v docker || command -v podman`. If neither is present, stop after the two
validators and report the CWL as validated but untested; never install an engine.

```bash
cwltool my_algo/cwl_workflows/process_<name>_<branch>.cwl my_algo/input.yml
cwltool --podman <cwl> <input.yml>    # podman instead of docker
```

`cwltool` pulls `dockerPull`, binds the inputs as `--flag value`, runs `baseCommand`, and stages the
globbed `output*` directory into the current working directory.

The image referenced by `dockerPull` must exist. Before the first CI run it does not, so either
build and tag it locally to match, or temporarily point `algorithm_container_url` at an image that
exists. For a local build matching the derived tag:

```bash
docker build -f my_algo/Containerfile -t "$(scripts/generate_cwl.py --config-file my_algo/algorithm_config.yml --print-docker-tag)" .
```

Note the trailing `.` — the build context is the repo root, matching CI.

A local build takes the host architecture, which is right for a local test-run and wrong for MAAP if
the host is an Apple Silicon Mac. Keep the native build for testing; add `--platform linux/amd64`
when building an image to push (see `deploy.md`).

### Job files (`input.yml`)

Primitives are plain scalars; `File` and `Directory` need a `class` plus a `path` (local, relative
to the job file) or `location` (URI):

```yaml
text: hello
intervals: 1000000
input_image:
  class: File
  path: nasa_maap_logo.png
input_catalog:
  class: Directory
  location: https://cmr.earthdata.nasa.gov/stac/.../items/...
output_file: result.tif
```

Inputs can also be passed as flags: `cwltool <cwl> --text hello --output_file out.txt`.

### Emulating stage-in

On MAAP, `File` and `Directory` inputs are localized onto the worker before the container starts.
`cwltool` does the same for a local `path`, but a STAC `Directory` input usually expects a catalog
layout that MAAP builds. To reproduce it, create the directory yourself and populate it with the
STAC item (and `catalog.json`) the algorithm expects, then point `path` at it.

### Reading results

Results land in the working directory as the globbed `output*` directory. If it is empty or absent,
the algorithm wrote outside `./output/` — fix the algorithm, not the CWL.

`--outdir <dir>` sends results elsewhere; `--debug` prints the full container invocation, which is
the fastest way to confirm the flags being passed match what the algorithm parses.
