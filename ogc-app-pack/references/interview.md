# Interview guide

The point of the interview is not to fill in a form — it is to make the user understand *what an
OGC Application Package is asserting about their algorithm*, so the answers are correct rather than
merely present. Every question comes with a "why" framed in terms of the resulting CWL and what
MAAP does with it.

Infer first (Phase 0), then confirm. A question the code already answers should be presented as
"I read X from your script — confirm?", not as an open question.

## Round 1 — Runtime and entrypoint

Ask this first: it determines the Containerfile pattern, whether a `run.py` shim is needed, and
what `run_command` should be.

**Q: What kind of thing is the algorithm?** Python script / Jupyter notebook / compiled binary or
shell script / already-built container image.

> *Why:* An app pack is a container plus a description of how to invoke it. The CWL's `baseCommand`
> has to name something executable inside that image, so the runtime decides both how the image is
> built and what `run_command` points at. A notebook isn't directly executable, so it gets a small
> papermill wrapper that translates the command-line flags into notebook parameters.

**Q: Should I write a `Containerfile`, or point the app pack at a pre-built image?**

> *Why:* Exactly one of the two is required — `validate_inputs.py` aborts with `algorithm_container_url
> or dockerfile-path must be provided` when neither is set, and rejects both when they are. Writing a
> Containerfile is the default and the only option that gets *this* algorithm's code into the image.
> Setting `algorithm_container_url` tells the generator to skip building and point
> `DockerRequirement.dockerPull` straight at the named image; then omit `dockerfile-path` from the
> Action too.

**Q (only if they want a pre-built image): Which image?** Ask outright — never pick one for them, and
never fill in a remembered tag. Offer the MAAP catalog and the escape hatch of pasting any image URL:

| Option | Image | Notes |
|---|---|---|
| MAAP minimal base | `mas.maap-project.org/root/maap-workspaces/custom_images/maap_base:<ver>` | conda only; the DPS default |
| MAAP stack base | `mas.maap-project.org/root/maap-workspaces/base_images/<python\|isce3\|pangeo\|r>:<ver>` | Workspace stacks with many conda packages |
| Their own image | anything, e.g. `ghcr.io/org/algo:tag` | The normal answer when the algorithm is already containerized |

Browse the registry for the exact path and current tag rather than trusting the shapes above:
<https://repo.maap-project.org/root/maap-workspaces/container_registry>. Dockerfiles for each stack:
<https://github.com/MAAP-Project/maap-workspaces/tree/main/base_images>.

> **Warn before they choose a bare MAAP base image.** Those images hold an environment, not your
> code. They work for DPS registration because MAAP clones the algorithm repo into the container at
> job time — an OGC app pack has no such step. The CWL does `dockerPull` then `baseCommand`, full
> stop, so a base image with no algorithm in it starts and dies on `command not found`. A pre-built
> image is the right answer only when it already contains an entrypoint matching `run_command` —
> either the algorithm is baked in, or `run_command` names a tool the image already ships (say
> `gdal_translate`). Otherwise write the Containerfile.

## Round 2 — Identity and provenance

Most of this comes from the repo. Show what you found and ask for corrections.

| Field | Ask or infer | Why it matters |
|---|---|---|
| `algorithm_name` | Ask. Propose a kebab-case name from the directory. | Becomes the CWL `id` **and** `label`. OGC req-9 requires both. In generator 1.1.0 it also drives the image name (`ghcr.io/<owner>/<algorithm-name>:<branch>`) and the CWL filename (`process_<name>_<branch>.cwl`). Must be lowercase, `[a-z0-9._-]`, because it is used as a Docker image name. It is the process identifier MAAP registers it under — change it later and you create a *second* process rather than updating the first. |
| `algorithm_description` | Ask, or lift the module docstring. | Becomes the CWL `doc` — OGC req-9 requires an abstract. This is the text a user sees when browsing processes on MAAP, so it should say what the algorithm does, not how it is implemented. |
| `algorithm_version` | Infer the current git branch. | Becomes `s:version`. Slashes are replaced with `_`. Keep it equal to the branch you push from: the Action names the image tag and CWL file from `GITHUB_REF_NAME`, so a mismatch makes the CWL claim a version that isn't the one built. |
| `keywords` | Ask, suggest `ogc` plus a domain term. | Becomes `s:keywords`; a plain comma-separated string. Used for discovery in the process catalog. |
| `author`, `contributor` | Infer from `git config user.name`. | Become `s:author` / `s:contributor` schema.org Person entries. OGC best practice for attribution and provenance. |
| `code_repository`, `citation` | Infer from `git remote get-url origin`. | Become `s:codeRepository` / `s:citation`. These are how someone who finds the process on MAAP gets back to the source. |
| `license` | Infer a raw URL to the repo's `LICENSE`. | Becomes `s:license`. Use a **raw** permalink, not a repo-browser URL, so it resolves to the license text. |
| `release_notes` | Ask; `None` is an accepted answer. | Becomes `s:releaseNotes`. |

## Round 3 — Inputs (the most important round)

Read the algorithm's argument parser and present the inputs you found. For each one confirm
**name, CWL type, whether it is optional, default, label, doc**.

> *Why this matters more than the rest:* the inputs section is the process's public API. MAAP builds
> the job submission form from it, and the generator binds each input as `--<name> <value>` on the
> command line. If `name` doesn't match the flag the code parses, the CWL validates, the container
> starts, and the algorithm dies on an unrecognized argument.

Per-input prompts, with the explanation to give:

- **name** — "This is used verbatim twice: as the parameter MAAP shows users, and as the CLI flag
  `--<name>` passed to your container. It has to match your arg parser exactly."
- **type** — "This is what MAAP validates submissions against and how it decides whether to *stage
  in* data. `File` and `Directory` are special: MAAP localizes the data onto the worker before your
  container runs, and your code receives a local path." See the type table in
  `algorithm-config.md`.
- **optional / default** — "Appending `?` makes the input optional, so MAAP won't require it at
  submission. A default is written into both the workflow and the tool level, so it applies whether
  the process is run through MAAP or directly with `cwltool`."
- **label** — "The short human-readable name for the form field."
- **doc** — "The help text under the field. Include units, expected format, and coordinate reference
  system for anything spatial — e.g. bbox order and EPSG code — because that's where users get it
  wrong."

**Always check** the output-filename input: most examples take an `output_file: string?` with a
default. Explain that this names the file *inside* `output/`, it does not change where results go.

**If the algorithm consumes STAC data**, explain stage-in: "MAAP stages the STAC Item into a local
catalog directory before your container starts, so declare it as `type: Directory` and have the code
read `catalog.json` from it. To reproduce that locally you create the directory yourself and drop
the item in."

## Round 4 — Outputs

Mostly a confirmation, not a question — the generator supports exactly one `Directory` output.

**Confirm: the algorithm writes everything into `./output/` relative to its working directory.**

> *Why:* The tool-level output is hardcoded to glob `./output*` and return it as a `Directory`, and
> the workflow output sources from it. This is the stage-out half of the OGC convention: MAAP
> collects that directory and publishes its contents as the job's results. Anything the algorithm
> writes elsewhere — `/tmp`, an absolute path, the home directory — is discarded when the container
> exits.

If the algorithm doesn't do this, fix the algorithm (add `os.makedirs("output", exist_ok=True)` and
join paths against it). Do not try to work around it in the config; you cannot.

If the user wants multiple distinct outputs, explain the constraint: declare one `Directory` and put
everything inside it. For STAC outputs, emit a self-contained catalog into `output/`.

## Round 5 — Resources

Users underestimate these. Ask for real numbers and explain the failure mode of each.

- **`ram_min`** (mebibytes) → `ResourceRequirement.ramMin`. "The minimum RAM the job needs. MAAP uses
  it to pick a worker; set it below the real peak and the run gets OOM-killed partway through."
- **`cores_min`** → `ResourceRequirement.coresMin`. "Minimum cores. Leave at 1 unless the algorithm
  actually parallelizes."
- **`outdir_max`** (mebibytes) → `ResourceRequirement.outdirMax`. "A cap on the output directory. This
  is the sneaky one: if the results exceed it the run fails at the very end, after all the compute.
  Size it generously against the largest expected output."

Ask what the algorithm's realistic peak memory and output size are, and pad both.

## Round 6 — Deployment and automation

- **Which MAAP environment?** Production (`https://api.maap-project.org/api/ogc/processes`), UAT
  (`https://api.uat.maap-project.org/api/ogc/processes`), or DIT
  (`https://api.dit.maap-project.org/api/ogc/processes`).
  > *Why:* This is the process registry the app pack is published to, and it decides which token
  > works — a UAT token 401s against production. Registration is an upsert, so re-registering an
  > existing `algorithm_name` overwrites the deployed process; proving it in UAT or DIT first is the
  > low-risk order. Say that once, then follow the user's choice.

  > The actual registration happens in Phase 5, after the CWL validates — see SKILL.md, which also
  > covers resolving `MAAP_TOKEN` and asking for it when the environment doesn't have it.
**Q: Set up the GitHub Action?** (Recommend yes — but explain what it turns on first.)

> *Why recommended:* It is the supported path and the only one that gets the provenance right. On
> each run it builds the image from the repo root, pushes it to GHCR, regenerates the CWL with the
> commit hash of the code being built, commits that CWL back to the branch, and registers the
> process from a raw GitHub URL that MAAP can fetch. Doing the same by hand means building with the
> right platform, pushing, committing, pinning a raw URL to a SHA, and POSTing — each a place to get
> it wrong.

> *What it turns on — say this before they agree:* once the workflow is in place, **every push to
> the branch it watches that touches the algorithm's files rebuilds and redeploys automatically**.
> No prompt, no separate approval, no chance to review between the merge and the deployment. Since
> registration is an upsert, each such push overwrites the live process of that name. That is the
> point of it, and it is also the reason to be deliberate about which branch.

**Q: Which branch should it watch?** Ask outright; don't assume `main`.

> *Why:* It goes in `on.push.branches` and in the `paths` filter. It also decides what gets built:
> the Action derives the image tag and the CWL filename from `GITHUB_REF_NAME`, so a workflow
> watching `develop` produces `...:develop` and `process_<name>_develop.cwl`. **Keep
> `algorithm_version` equal to that branch** — otherwise the CWL claims a version that isn't the one
> built. A feature branch is the low-risk place to watch it work before pointing it at `main`.

Setup requirements, all of which the user has to do — state them rather than discovering them in a
red CI run:

- `secrets.MAAP_TOKEN` on the repository, valid for the endpoint chosen above (a UAT token 401s
  against production). **Walk the user through this — only when they are setting up the Action**,
  since it is the Action that reads the secret; a purely local registration uses `$MAAP_TOKEN` in
  their own shell instead:

  1. **Get the token** from their MAAP profile:
     <https://console.maap-project.org/profile/tokens>. That console issues production tokens — for
     UAT or DIT, use that environment's own console, because a token only works against the
     environment that issued it.
  2. **Add it as a repository secret** named exactly `MAAP_TOKEN`, following GitHub's guide:
     <https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets>.
     In the UI that is *Settings → Secrets and variables → Actions → New repository secret*. Or, from
     the terminal, they run it themselves so the value never enters the transcript:
     ```bash
     ! gh secret set MAAP_TOKEN --repo <org>/<repo>     # prompts for the value, echoes nothing
     ```
  3. **Never hardcode the token in the workflow file** — it is referenced as
     `${{ secrets.MAAP_TOKEN }}` and nothing else. A token committed to the repo is a leaked
     credential, and the workflow YAML is as public as the repo.

  The secret is per-repository, so a fork or a second repo needs its own. When the Action starts
  failing at the register step with 401/403 and nothing else changed, the token expired — reissue it
  from the same profile page and update the secret.
- `permissions: contents: write` (the Action commits the CWL) and `packages: write` (it pushes to
  GHCR) — both are in `assets/github-workflow.yml`.
- The GHCR package is private on first push; MAAP cannot pull it until it is made public.
- `deploy-app-pack: false` is the middle setting: the Action still builds, pushes, generates,
  validates and commits the CWL, but registers nothing. Offer it to anyone who wants the automation
  without automatic publication.

**Q (if they decline the Action): register locally instead?** Confirm `MAAP_TOKEN` is available and
`docker login ghcr.io` has been done, then follow `deploy.md` — and confirm before pushing or
registering. Note that the local route needs `--platform linux/amd64` on Apple Silicon, which the
Action gets for free by running on `ubuntu-latest`.

## Round 7 — Which scaffold files to keep

Two scaffolded files are conveniences rather than requirements. Ask about both — but only where
there is a real choice, and state the consequence instead of a preference.

**Q: Keep `algorithm_config.yml` in the algorithm directory?** (Recommend yes.)

> *Why:* It is the generator's input, so it is always needed to *produce* the CWL — the question is
> only whether it stays in the repo afterwards. Nothing at runtime reads it: MAAP executes the CWL,
> not the config. What keeping it buys is regenerability. Raising `ram_min`, adding an input, or
> re-registering after a code change is an edit-and-regenerate when the config is in the repo, and a
> hand-reconstruction from the generated CWL when it isn't. It is also the file a reviewer reads to
> see what the process claims about itself, in 30 lines rather than 200 of CWL.

> **Don't offer the choice if they chose the GitHub Action** in Round 6. The Action takes
> `algorithm-configuration-path` and re-reads the config on every push, so it isn't optional on that
> route. Say that, and move on.

> If they decline: write the config to the scratchpad and generate from there. Tell them plainly
> that the CWL becomes the only artifact and the next change starts from scratch. Note that
> `generate_cwl.py` reads git from the config file's own directory, so a scratchpad config needs
> `--branch`, `--owner`, and `--commit` passed explicitly.

**Q: Write a sample `input.yml`?** (Recommend yes whenever a local test-run is plausible.)

> *Why:* It is a CWL job file — the second half of `cwltool <cwl> input.yml`. Nothing on MAAP reads
> it and the Action never touches it; it exists so a local test-run is a one-liner rather than
> retyping every flag, and so the next person can see what a valid submission looks like, including
> the `class: File` / `path:` shape that `File` and `Directory` inputs need.

> If they decline, test-run with inline flags instead: `cwltool <cwl> --text hello`. The equivalence
> is worth saying out loud — it is the same job, just typed rather than saved.
