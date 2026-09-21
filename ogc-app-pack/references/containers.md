# Containerfile and entrypoint patterns

Two rules govern every pattern here:

1. **`COPY` paths are relative to the repository root**, because the Action builds with
   `context: .` and `file: <algo-dir>/Containerfile`. Always write `COPY ./my_algo/x /dest`.
   A `COPY ./x /dest` works when you build from inside the directory and breaks in CI.
2. **`run_command` must resolve inside the image.** The reliable move is copying the entrypoint to
   `/usr/local/bin/` and `chmod +x`, so `run_command: run.py` resolves on `PATH`. An absolute path
   like `/app/my_algo/run.sh` also works.

Note there is no `CMD`/`ENTRYPOINT` in any of these. CWL supplies the command: it runs
`baseCommand` with the bound `--flag value` arguments. An `ENTRYPOINT` would fight that.

## Pattern A — Python script

```dockerfile
FROM python:3.12-slim

COPY ./my_algo/my_algo.py /usr/local/bin/my_algo.py

RUN chmod +x /usr/local/bin/my_algo.py
```

With dependencies:

```dockerfile
FROM python:3.12-slim

COPY ./my_algo/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY ./my_algo/my_algo.py /usr/local/bin/my_algo.py
RUN chmod +x /usr/local/bin/my_algo.py
```

`run_command: my_algo.py`. The script needs a `#!/usr/bin/env python3` shebang.

The script must parse exactly the config's input names and write to `./output/`:

```python
#!/usr/bin/env python3
import argparse, os

OUTPUT_DIR = "output"

def main() -> None:
    parser = argparse.ArgumentParser(description="...")
    parser.add_argument("--text", required=True, help="...")
    parser.add_argument("--output_file", default="output.txt", help="...")
    args = parser.parse_args()

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, args.output_file)
    ...
```

## Pattern B — Jupyter notebook (papermill)

The notebook is not executable, so a `run.py` shim translates CLI flags into papermill parameters.
Copy `assets/run.py` and edit the argument list to match the config's inputs.

```dockerfile
FROM python:3.12-slim

COPY ./my_algo/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt \
    && python3 -m ipykernel install --name python3

COPY ./my_algo/my_algo.ipynb /app/my_algo.ipynb
COPY ./my_algo/run.py /usr/local/bin/run.py

RUN chmod +x /usr/local/bin/run.py
```

`run_command: run.py`. `requirements.txt` needs at least `papermill` and `ipykernel`.
The `ipykernel install` step is required — papermill needs a registered `python3` kernel.

The notebook needs a cell tagged **`parameters`**, holding every input as a variable with a
sensible local default. Papermill injects a cell below it overriding these at execution:

```python
# Papermill parameters cell -- values here are overridden at execution time.
input_catalog = "input"
bbox = "-122.55 37.70 -122.35 37.85"
output_file = "clipped.tif"
```

Tag the cell in Jupyter via *View → Cell Toolbar → Tags*, or set
`"metadata": {"tags": ["parameters"]}` on that cell in the `.ipynb` JSON. Without the tag, papermill
runs the notebook with its hardcoded defaults and the inputs are silently ignored.

The executed notebook is written into `output/` as a run record alongside the results.

### Base image with system libraries

When the algorithm needs GDAL or similar, start from a domain base image and add pip:

```dockerfile
FROM ghcr.io/osgeo/gdal:ubuntu-small-latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY ./my_algo/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --break-system-packages -r /app/requirements.txt \
    && python3 -m ipykernel install --name python3
```

`--break-system-packages` is needed on Debian/Ubuntu bases with an externally-managed Python.

## Pattern C — Compiled binary or shell script

Compile at build time and land the binary on `PATH`:

```dockerfile
FROM gcc:14

COPY ./my_algo/my_algo.f90 /app/my_algo.f90

RUN gfortran -O2 -o /usr/local/bin/my_algo /app/my_algo.f90
```

`run_command: my_algo`. The program parses `--flag value` pairs itself and must `mkdir -p output`
before writing. A multi-stage build keeps the runtime image small when the toolchain is large.

## Pattern D — Existing image

Set `algorithm_container_url: ghcr.io/org/image:tag` in `algorithm_config.yml`, write no
Containerfile, and omit `dockerfile-path` from the Action inputs. Exactly one of the two is
required: the generator errors out if both are supplied, and `validate_inputs.py` aborts with
`algorithm_container_url or dockerfile-path must be provided` if neither is.

**The image must already contain an entrypoint matching `run_command`** that accepts the
`--flag value` inputs and writes to `./output/`. This is the whole of the pattern's risk, so check it
before choosing: `docker run --rm --entrypoint sh <image> -c 'command -v <run_command>'`.

### The MAAP base-image trap

MAAP publishes base images that are the right answer for **DPS** algorithm registration and the
wrong one for an app pack:

| Image | Contents |
|---|---|
| `mas.maap-project.org/root/maap-workspaces/custom_images/maap_base:<ver>` | conda only — the minimal DPS default |
| `mas.maap-project.org/root/maap-workspaces/base_images/<python\|isce3\|pangeo\|r>:<ver>` | Workspace stacks with many conda packages |

Registry (confirm the exact path and current tag here, don't trust a remembered tag):
<https://repo.maap-project.org/root/maap-workspaces/container_registry>. Per-stack Dockerfiles:
<https://github.com/MAAP-Project/maap-workspaces/tree/main/base_images>.

These hold an *environment*, not the algorithm. DPS registration also takes a repository URL and
branch, and MAAP clones the code into the container at job time. **An OGC app pack has no such
step** — the CWL does `dockerPull` and then `baseCommand`, and nothing else. Point an app pack at a
bare base image and the container starts, fails to find `run_command`, and the job dies with an
empty output directory.

So a pre-built image is correct in exactly two cases:

1. The algorithm is already baked into it (someone built and pushed it — e.g.
   `ghcr.io/maap-project/sardem-sarsen:<tag>`).
2. `run_command` names a tool the image already ships, and the "algorithm" is that invocation —
   `gdal_translate` in a GDAL image, say.

In every other case, write the Containerfile. If the user wants a MAAP stack's environment without
its trap, use it as the `FROM` in Pattern A/B instead, which keeps the environment and adds the code.

## Common failures

| Symptom | Cause |
|---|---|
| `COPY failed: file not found` in CI, works locally | `COPY` path not relative to repo root |
| `permission denied` running the entrypoint | Missing `RUN chmod +x` |
| `exec format error` | Missing or wrong shebang on a script entrypoint |
| `unrecognized arguments: --foo` | Config input `name` doesn't match the arg parser |
| Run succeeds, results empty | Wrote outside `./output/`, or used an absolute path |
| Papermill: `No such kernel named python3` | Missing `python3 -m ipykernel install --name python3` |
| `command not found` immediately, empty output | `algorithm_container_url` points at a base image that doesn't contain the algorithm |
| Notebook runs but ignores inputs | The `parameters` cell tag is missing |
