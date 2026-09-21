# `algorithm_config.yml` reference

The generator's only input. Every field below maps to a specific place in the generated CWL.
Missing keys are not fatal — `build_cwl_workflow.py` logs a warning and leaves the template's
`null` in place — but a `null` in a required OGC field makes `ap-validator` fail, so treat all of
the top-level fields as required.

## Top-level fields → CWL target

| Config key | CWL target | Notes |
|---|---|---|
| `algorithm_description` | `$graph[0].doc` | OGC req-9 abstract. |
| `algorithm_name` | `$graph[0].label` **and** `$graph[0].id` | OGC req-9 title + identifier. Lowercase `[a-z0-9._-]`; also becomes the image name and the CWL filename. |
| `algorithm_version` | `s:version` | `/` replaced with `_`. |
| `keywords` | `s:keywords` | Free string, e.g. `ogc, sar`. |
| `code_repository` | `s:codeRepository` | |
| `citation` | `s:citation` | |
| `author` | `s:author[0].s:name` | Wrapped as a `s:Person`. Single author only. |
| `contributor` | `s:contributor[0].s:name` | Single contributor only. |
| `license` | `s:license` | Use a raw permalink to the license text. |
| `release_notes` | `s:releaseNotes` | `None` is fine. |
| `run_command` | `$graph[1].baseCommand` | Must be on `PATH` in the image or an absolute path. |
| `ram_min` | `ResourceRequirement.ramMin` | Mebibytes. |
| `cores_min` | `ResourceRequirement.coresMin` | |
| `outdir_max` | `ResourceRequirement.outdirMax` | Mebibytes. Output dir cap — size generously. |
| `algorithm_container_url` | `DockerRequirement.dockerPull` | **Optional.** Set it only to reuse a pre-built image; then do not pass `dockerfile-path` to the Action. |

Filled in by the generator, not by you:

- `s:dateCreated` — today's date at generation time.
- `s:softwareVersion` — hardcoded `1.0.0`.
- `s:commitHash` — from `GIT_COMMIT_HASH`.
- `DockerRequirement.dockerPull` — from `DOCKER_TAG` when no `algorithm_container_url`.
- `NetworkAccess.networkAccess: true` — always on, from the template.

## `inputs`

A list; each entry becomes three things — a workflow input, a step input, and a tool input with a
command-line binding.

```yaml
inputs:
  - name: bbox            # required: the parameter name AND the CLI flag (--bbox)
    doc: Clip bounding box as 'MINX MINY MAXX MAXY' in EPSG:4326   # required: help text
    label: Bounding box   # required: form field label
    type: string          # required: CWL type
    default: "-122.55 37.70 -122.35 37.85"   # optional
```

Generated per input, with `position` counting from 1 in list order:

```yaml
# workflow level                  # tool level
bbox:                             bbox:
  doc: ...                          type: string
  label: ...                        inputBinding:
  type: string                        position: 1
  default: ...                        prefix: --bbox
                                    default: ...
```

Input names must be unique — a duplicate raises `ValueError` and the build fails.

### Types

| `type` | Meaning | What the algorithm receives |
|---|---|---|
| `string` | Text | The string |
| `int`, `long` | Integer | Digits |
| `float`, `double` | Real | Number |
| `boolean` | True/false | Note: CWL emits a bare flag for `true` and omits it for `false`, so the arg parser needs `store_true`, not a value |
| `File` | A single file | A **local path**; MAAP stages the file in before the container runs |
| `Directory` | A directory | A **local path**; used for staged STAC catalogs |
| `<type>?` | Optional | Not required at submission |
| `<type>[]` | Array | Repeated occurrences of the flag |

`File` and `Directory` defaults are wrapped by the generator as `{class: File, path: <default>}`.
Defaults for primitive types are written through as-is.

## `outputs`

Exactly one entry, `type: Directory`:

```yaml
outputs:
  - name: out
    type: Directory
```

The generator ignores everything but `name` and `type`, and hardcodes the tool-level output to:

```yaml
outputs_result:
  outputBinding:
    glob: ./output*
  type: Directory
```

A second output entry reuses the same `outputs_result` key and silently clobbers the first. One
output, always.

## Complete example

```yaml
algorithm_description: Clips a raster asset from a staged STAC Catalog to a bounding box.
algorithm_name: stac-clip
algorithm_version: main
keywords: ogc, stac, raster
code_repository: https://github.com/ORG/REPO.git
citation: https://github.com/ORG/REPO.git
author: jdoe
contributor: jdoe
license: https://raw.githubusercontent.com/ORG/REPO/refs/heads/main/LICENSE
release_notes: None
run_command: run.py
ram_min: 5        # mebibytes
cores_min: 1
outdir_max: 10    # mebibytes

inputs:
  - name: input_catalog
    doc: Path to the STAC Catalog directory
    label: Input STAC Catalog
    type: Directory
  - name: bbox
    doc: Clip bounding box as 'MINX MINY MAXX MAXY' in EPSG:4326
    label: Bounding box
    type: string
  - name: output_file
    doc: Name of the output COG
    label: Output filename
    type: string?
    default: clipped.tif

outputs:
  - name: out
    type: Directory
```
