# Interview guide

The point of the interview is not to fill in a form — it is to help the user understand *what the
package will claim about their algorithm*, so the answers are correct rather than merely present.

Each question below has two parts:

- **Say** — the plain-language question and explanation to give the user. Adapt the wording, keep
  the level. Follow `references/glossary.md`: explain a technical term the first time it comes up,
  in terms of what it does for them.
- **Notes** — the technical detail behind it. This is for you. Quote it only when the user asks,
  or has to type or read it (a field name in a file they will open, an error message).

Infer first (Phase 0), then confirm. A question the code already answers should be presented as
"I read X from your script — is that right?", not as an open question.

**Open with a one-paragraph orientation** before the first question, so the rest makes sense.
Something like:

> To run your algorithm, MAAP needs it packaged as an *OGC Application Package* — a standard
> bundle made of two parts. The first is a **container**: a sealed copy of your code plus the
> exact software it needs, so it runs the same on MAAP as on your laptop. The second is a **CWL
> workflow file**: a description of your algorithm's inputs, outputs, and resource needs, in a
> shared format that lets MAAP (and other platforms) run it the same way. I'll write both from a
> short settings file, and ask you a few questions to fill it in.

## Round 1 — What the algorithm is, and how it gets packaged

Ask this first: it decides how the container is built and what command starts the algorithm.

**Q: What kind of thing is the algorithm?** Python script / Jupyter notebook / compiled program or
shell script / something already packaged in a container.

> **Say:** "MAAP starts your algorithm by running a command inside the container, so I need to
> know what kind of program it is. A notebook can't be run as a command on its own, so for a
> notebook I add a small launcher script that feeds in the inputs and runs it top to bottom."
>
> **Notes:** The runtime decides the Containerfile pattern (`references/containers.md`), whether a
> `run.py` papermill shim is needed, and `run_command`, which becomes the CWL `baseCommand` and has
> to name something executable inside the image.

**Q: Should I write the container recipe for you, or use a container image that already exists?**

> **Say:** "The container has to be built from a recipe — a *Containerfile* listing the software
> to install and where your code goes. I'd normally write that for you; it's the only way your own
> code ends up inside. The alternative is pointing at a container someone has already built, which
> only works if your algorithm is already in it."
>
> **Notes:** Exactly one of the two is required — `validate_inputs.py` aborts with
> `algorithm_container_url or dockerfile-path must be provided` when neither is set, and rejects
> both. Setting `algorithm_container_url` makes the generator skip building and point
> `DockerRequirement.dockerPull` at that image; then omit `dockerfile-path` from the Action too.

**Q (only if they want an existing image): Which image?** Ask outright — never pick one for them,
and never fill in a remembered version tag. Offer the MAAP catalog, or any image address they paste:

| Option | Image | Say |
|---|---|---|
| MAAP minimal base | `mas.maap-project.org/root/maap-workspaces/custom_images/maap_base:<ver>` | MAAP's minimal starting environment |
| MAAP stack base | `mas.maap-project.org/root/maap-workspaces/base_images/<python\|isce3\|pangeo\|r>:<ver>` | MAAP's ready-made environments with many science libraries |
| Their own image | anything, e.g. `ghcr.io/org/algo:tag` | The usual answer if your algorithm is already packaged |

Look up the exact address and current version in the registry rather than trusting the shapes
above: <https://repo.maap-project.org/root/maap-workspaces/container_registry>. The recipes for
each MAAP environment: <https://github.com/MAAP-Project/maap-workspaces/tree/main/base_images>.

> **Warn before they choose a bare MAAP base image.**
>
> **Say:** "Those MAAP images contain the software environment, but not your code. They work for
> MAAP's older way of registering algorithms, which copies your code in when the job starts — but
> an application package doesn't do that step. MAAP would start the container, find nothing to
> run, and the job would fail straight away. If you like one of those environments, I can use it
> as the starting point of the recipe and add your code on top."
>
> **Notes:** DPS registration clones the repo into the container at job time; an app pack does
> `dockerPull` then `baseCommand` and nothing else, so a bare base image dies on `command not
> found`. A pre-built image is only right when it already contains an entrypoint matching
> `run_command` — the algorithm is baked in, or `run_command` is a tool the image ships (say
> `gdal_translate`). Otherwise write the Containerfile, optionally `FROM` the MAAP image.

## Round 2 — Name, description, and credit

Most of this comes from the repository. Show what you found and ask for corrections — don't ask
each one as an open question.

> **Say (once, for the round):** "This is how your algorithm will be listed on MAAP — the name
> people see, the description they read, and the links back to your code and license. I've filled
> in what I could from your repository; correct anything that's off."

| Field | Ask or infer | Say | Notes |
|---|---|---|---|
| `algorithm_name` | Ask. Propose a lowercase-with-dashes name from the directory. | "The name your algorithm is listed under on MAAP. Lowercase letters, numbers, and dashes only. Pick carefully: changing it later creates a second, separate listing rather than renaming this one." | CWL `id` and `label` (OGC req-9). In generator 1.1.0 it also drives the image name `ghcr.io/<owner>/<algorithm-name>:<branch>` and the CWL filename `process_<name>_<branch>.cwl`. Must be `[a-z0-9._-]`, since it is a Docker image name. |
| `algorithm_description` | Ask, or lift the module docstring. | "One or two sentences on what it does — this is what people read when they find it on MAAP, so describe the result, not the implementation." | CWL `doc`; OGC req-9 requires an abstract. |
| `algorithm_version` | Infer the current git branch. | "The version label. I've set it to the branch you're working on (`main`), which keeps it consistent with how the package gets built." | `s:version`; `/` → `_`. Keep equal to the branch pushed from — the Action derives the image tag and CWL filename from `GITHUB_REF_NAME`. |
| `keywords` | Ask; suggest `ogc` plus a domain term. | "A few search keywords, comma-separated, so people can find it on MAAP." | `s:keywords`, a plain string. |
| `author`, `contributor` | Infer from `git config user.name`. | "Who gets credit." | `s:author` / `s:contributor` schema.org Person; single name each. |
| `code_repository`, `citation` | Infer from `git remote get-url origin`. | "Links back to your code, so someone who finds it on MAAP can get to the source." | `s:codeRepository` / `s:citation`. |
| `license` | Infer a raw URL to the repo's `LICENSE`. | "A link to your license text." Ask about adding one if there isn't one. | `s:license`. Use a **raw** permalink so it resolves to the text, not a GitHub page. |
| `release_notes` | Ask; `None` is fine. | "Anything to note about this version? 'None' is fine." | `s:releaseNotes`. |

## Round 3 — Inputs (the most important round)

Read the algorithm's argument parser and present the inputs you found. For each one confirm the
name, the kind of value, whether it is optional, the default, the short label, and the help text.

> **Say:** "These inputs are what people fill in when they run your algorithm on MAAP — MAAP builds
> its submission form from this list. When the job runs, each one is handed to your code as a
> command-line option like `--input_file data.tif`, so the names have to match what your code
> already expects exactly. If one doesn't match, everything will look fine until the job starts,
> and then your code will reject the option."
>
> **Notes:** The generator binds each input as `--<name> <value>` (`inputBinding.prefix`). A name
> mismatch passes both validators and fails at runtime with `unrecognized arguments`.

Per-input prompts:

- **name** — Say: "Used twice: as the field name MAAP shows, and as the `--<name>` option your code
  receives. It has to match your code exactly."
- **type** — Say: "What kind of value it is — text, a whole number, a decimal, true/false, a file,
  or a folder. Files and folders are special: MAAP copies the data onto the computer running your
  algorithm before it starts, and your code just gets a local path." Notes: CWL types `string`,
  `int`, `float`, `boolean`, `File`, `Directory`, etc.; the table is in `algorithm-config.md`. A
  `boolean` is passed as a bare flag when true and omitted when false, so the parser needs
  `store_true`.
- **optional / default** — Say: "Can someone leave this blank? If so, what value should it use?"
  Notes: `?` suffix makes it optional; the default is written at both workflow and tool level, so
  it applies on MAAP and under `cwltool`.
- **label** — Say: "A short, readable name for the form field."
- **doc** — Say: "The help text under the field. Include units and format — and for anything on a
  map, the coordinate order and system (for example, 'min lon, min lat, max lon, max lat in
  EPSG:4326'). That's where people most often get it wrong."

**Always check** the output-filename input: most examples take an optional `output_file` with a
default. Say: "This only names the file inside your `output` folder — it doesn't change where
results go."

**If the algorithm consumes STAC data**, Say: "STAC is a standard way of describing satellite and
other geospatial data. MAAP will fetch the data item you point it at and hand your code a local
folder containing it, with a `catalog.json` file describing what's inside. So this input should
be a folder, and your code should read `catalog.json` from it. To test on your own computer, you
make that folder yourself and put the item in it." Notes: declare `type: Directory`.

## Round 4 — Outputs

Mostly a confirmation, not a question — the generator supports exactly one output folder.

**Confirm: the algorithm writes everything into an `output` folder in the directory it runs in.**

> **Say:** "When your algorithm finishes, MAAP collects whatever is in the `output` folder and
> publishes it as the job's results. Anything saved anywhere else is thrown away when the job
> ends."
>
> **Notes:** The tool-level output is hardcoded to glob `./output*` as a `Directory`, and the
> workflow output sources from it. Writing to `/tmp`, an absolute path, or `~` loses the results.
> The config's output `name` must start with `out` (use `out`) — MAAP relies on it to mount the
> results into the user's bucket. Don't ask the user to name it; set it. If an existing config
> uses another name, rename it and tell them why: "I renamed the output to `out` — MAAP needs the
> name to start with 'out' to put your results in your storage bucket."

If the algorithm doesn't do this, fix the algorithm (add `os.makedirs("output", exist_ok=True)` and
join paths against it). There is no way to work around it in the config.

If the user wants several outputs, Say: "MAAP returns a single results folder, so everything goes
inside it — you can organize it into subfolders." For STAC outputs, write a self-contained catalog
into `output/`.

## Round 5 — Computer resources

Users underestimate these. Ask for real numbers and explain what happens when each is wrong.

> **Say (once, for the round):** "MAAP uses these to pick a computer big enough for the job. It's
> worth padding them — too little is a failed run, too much just costs a bit of efficiency."

- **`ram_min`** — Say: "How much memory does it need at its peak, in MiB (1 MiB is about 1 MB)? If
  this is below what it actually uses, the run is stopped partway through." Notes:
  `ResourceRequirement.ramMin`, mebibytes; too low → OOM kill.
- **`cores_min`** — Say: "How many processors does it use? Leave it at 1 unless your code runs
  things in parallel." Notes: `ResourceRequirement.coresMin`.
- **`outdir_max`** — Say: "The largest your results could be, in MiB. This is the easy one to get
  wrong: if the results are bigger than this, the run fails at the very end, after all the work is
  done. Be generous." Notes: `ResourceRequirement.outdirMax`, mebibytes.

Ask what the realistic peak memory and largest output are, and pad both.

## Round 6 — Deploying to MAAP, and automating it

**Q: Which MAAP environment should it go to?** Production is the default and recommended. UAT is
the secondary option. DIT only if the user asks for it.

> **Say:** "MAAP runs a few separate copies of itself. **Production** is the real one everyone
> uses — that's where I'd publish it. **UAT** (user acceptance testing) is a test copy, if you'd
> like to try it out before other people can see it. Each has its own access token, so a token
> from one won't work on the other. Publishing again under the same name replaces the earlier
> version in that environment."
>
> **Notes:** Endpoints — production `https://api.maap-project.org/api/ogc/processes`, UAT
> `https://api.uat.maap-project.org/api/ogc/processes`, DIT
> `https://api.dit.maap-project.org/api/ogc/processes`. Registration is an upsert (POST, then PUT on
> 409). Mention UAT once, then follow the user's choice. The registration itself is Phase 6 in
> SKILL.md, which also covers resolving `MAAP_TOKEN`.

**Q: Set up a GitHub Action to deploy it automatically?** (Recommend yes — but explain what it
turns on first.)

> **Say:** "A GitHub Action is an automation that runs on GitHub's computers. I'd set one up to
> handle deployment to MAAP for you: every time you push a change to your algorithm, it rebuilds
> the container, regenerates the workflow file, stores the container on GitHub's registry, and
> updates your algorithm on MAAP — with no manual steps. It's MAAP's recommended route, and it
> avoids several steps that are easy to get wrong by hand.
>
> The trade-off to be aware of: once it's set up, **every push to the branch it watches goes
> straight to MAAP**, with no separate approval, and replaces the version that's there. That's the
> point of it, and it's also why it's worth choosing that branch deliberately."
>
> **Notes:** On each run it builds from the repo root, pushes to GHCR, regenerates the CWL with the
> built commit's hash (the only route that stamps `s:commitHash` correctly), commits the CWL back to
> the branch, and registers from a raw GitHub URL. By hand that is: build for the right platform,
> push, commit, pin a raw URL to a SHA, and POST.

**Q: Which branch should it watch?** Ask outright; don't assume `main`.

> **Say:** "A branch is a named line of work in your repository, like `main`. The Action deploys
> whatever lands on the branch it watches. `main` is typical; a separate branch is a safer place to
> watch it work the first time."
>
> **Notes:** Goes in `on.push.branches` and drives the `paths` filter. The image tag and CWL
> filename come from `GITHUB_REF_NAME`, so watching `develop` produces `...:develop` and
> `process_<name>_develop.cwl`. **Keep `algorithm_version` equal to that branch.**

Setup the user has to do themselves — tell them up front rather than letting them find out from a
failed run:

- **A MAAP token stored as a repository secret.** Walk the user through this — **only when they are
  setting up the Action**, since it is the Action that reads the secret; someone registering from
  their own computer uses `$MAAP_TOKEN` in their shell instead.

  > **Say:** "The Action needs permission to publish to MAAP on your behalf. That permission is a
  > *MAAP token* — a personal access key from your MAAP profile page; treat it like a password.
  > GitHub keeps it as a *repository secret*: a value stored securely in your repository's
  > settings, which the Action can use but which never appears in your code."

  1. **Get the token** from the MAAP profile page **of the environment they chose** — a token only
     works on the environment that issued it:

     | Deploying to | Get the token from |
     |---|---|
     | Production | <https://console.maap-project.org/profile/tokens> |
     | UAT | <https://console.uat.maap-project.org/profile/tokens> |
     | DIT | The DIT console's own profile page — ask the user rather than guessing the address |

     A token from the wrong environment is the usual reason a build succeeds and then fails at the
     publishing step (HTTP 401/403).
  2. **Add it as a repository secret** named exactly `MAAP_TOKEN`, following GitHub's guide:
     <https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets>.
     On GitHub that is *Settings → Secrets and variables → Actions → New repository secret*. Or
     from the terminal — they run it themselves, so the value never appears in this conversation:
     ```bash
     ! gh secret set MAAP_TOKEN --repo <org>/<repo>     # asks for the value, shows nothing
     ```
  3. **Never put the token in the workflow file** — it is referenced only as
     `${{ secrets.MAAP_TOKEN }}`. The workflow file is as public as the repository.

  The secret belongs to one repository, so a fork or another repository needs its own. If the
  Action starts failing at the publishing step and nothing else changed, the token has probably
  expired — Say: "get a new one from the same page and replace the secret."
- **Permissions** (Notes): `contents: write` (the Action commits the CWL) and `packages: write` (it
  pushes to GHCR) — both already in `assets/github-workflow.yml`. Nothing for the user to do.
- **Making the container public.** Say: "The first time the Action stores your container on GitHub
  Container Registry (GHCR), GitHub makes it private. MAAP can't download it until you switch it to
  public in the package's settings — a one-time step."
- **Automation without publishing.** Say: "If you'd like the automation but want to publish to MAAP
  yourself, I can set it to do everything except the final publishing step." Notes:
  `deploy-app-pack: false` — builds, pushes, generates, validates, and commits the CWL, but
  registers nothing.

**Q (if they decline the Action): publish from your own computer instead?** Confirm `MAAP_TOKEN` is
available and they are logged in to GHCR (`docker login ghcr.io`), then follow `deploy.md` —
confirming before pushing anything or registering. On an Apple Silicon Mac, Say: "Macs with Apple
chips use a different kind of processor than MAAP's computers, so I'll build the container
specially for MAAP." Notes: `--platform linux/amd64`, which the Action gets for free on
`ubuntu-latest`.

## Round 7 — Which helper files to keep

Two of the files are conveniences rather than requirements. Ask about both — but only where there
is a real choice, and state the consequence instead of a preference.

**Q: Keep the settings file (`algorithm_config.yml`) in your repository?** (Recommend yes.)

> **Say:** "This short settings file is what the workflow file is generated from. MAAP never reads
> it — it only matters when you make a change. With it in your repository, raising the memory,
> adding an input, or republishing after a code change is a quick edit and regenerate. Without it,
> the next change means reconstructing it from the much longer workflow file. It's also the easiest
> place for someone to see what your package says about itself."
>
> **Notes:** It is always needed to *generate* the CWL; nothing at runtime reads it.

> **Don't offer the choice if they chose the GitHub Action** in Round 6. The Action re-reads the
> settings file (`algorithm-configuration-path`) on every push, so it has to stay. Say that, and
> move on.

> If they decline: write the config to the scratchpad and generate from there. Tell them plainly
> that the workflow file becomes the only record and the next change starts from scratch. Notes:
> `generate_cwl.py` reads git from the config file's own directory, so a scratchpad config needs
> `--branch`, `--owner`, and `--commit` passed explicitly.

**Q: Write a sample input file (`input.yml`) for testing?** (Recommend yes whenever a local test run
is plausible.)

> **Say:** "This is a small file of example input values, so testing your algorithm on your own
> computer is one short command instead of typing every input each time. It also shows the next
> person what a valid set of inputs looks like. MAAP never uses it."
>
> **Notes:** A CWL job file — the second half of `cwltool <cwl> input.yml`. The Action never
> touches it. It shows the `class: File` / `path:` shape that `File` and `Directory` inputs need.

> If they decline, test with the inputs typed on the command line instead — `cwltool <cwl> --text
> hello`. Say that it's the same test, just typed rather than saved.
