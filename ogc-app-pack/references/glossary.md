# Plain-language glossary

The people using this skill are usually scientists and algorithm developers, not DevOps engineers.
Talk to them in plain language. When a technical term has to come up, explain it the first time
you use it: what it is, and what it does for *them*. After that, the term alone is fine.

Use the explanations below as a starting point. Adjust to the user — someone who clearly knows
Docker doesn't need containers explained, and someone who asks "what's a branch?" needs more than
this table gives.

## Rules

- **Lead with the outcome, not the mechanism.** "This lets MAAP run your algorithm on its
  computers" before "this registers an OGC process".
- **Explain a term the first time it appears**, in a clause, not a lecture: "a CWL file — a
  workflow file that describes your algorithm so MAAP and other platforms can run it the same way".
- **Don't say what the user doesn't need to act on.** Field paths like
  `ResourceRequirement.ramMin`, requirement IDs like `req-9`, env vars like `GITHUB_REF_NAME`, and
  script names like `validate_inputs.py` are notes for you, not things to recite. Mention one only
  when the user has to type it, read it in an error, or asked for the detail.
- **Say abbreviations in full first.** "GitHub Container Registry (GHCR)", not "GHCR".
- **Explain an error in terms of what went wrong for them**, then the fix: "MAAP couldn't read your
  workflow file because it isn't on GitHub yet — push it and I'll retry", not "HTTP 404 on the raw
  URL".
- **Question options are user-facing too.** Keep `AskUserQuestion` labels and descriptions plain.

## Terms

| Term | Say something like |
|---|---|
| **MAAP** | NASA and ESA's Multi-Mission Algorithm and Analysis Platform — the platform that will run your algorithm on its own computers, close to the data. |
| **OGC Application Package** (app pack) | A standard bundle MAAP knows how to run: your algorithm packaged with everything it needs, plus a file describing how to run it. OGC (the Open Geospatial Consortium) is the standards body that defines the format. |
| **OGC process** / **process** | Your algorithm as it appears on MAAP once registered — something other users can find and run. |
| **CWL** (Common Workflow Language) file | A workflow file that describes your algorithm — its inputs, outputs, and what computer resources it needs — so MAAP (and any other platform that speaks CWL) can run it the same way. That shared format is what makes the algorithm interoperable. I generate it for you; you never edit it by hand. |
| **`algorithm_config.yml`** | A short settings file, in plain text, that I fill in with your algorithm's name, inputs, and resource needs. The CWL workflow file is generated from it. |
| **YAML** | The simple plain-text format that settings file is written in. |
| **Container** / **container image** | A sealed, portable copy of your algorithm together with the exact software it needs (Python version, libraries), so it runs the same on MAAP as on your laptop. |
| **Containerfile** (Dockerfile) | The recipe for building that container: which base software to start from, what to install, and where your code goes. |
| **Docker** / **Podman** | Programs that build and run containers on your own computer. Only needed if you want to test locally. |
| **Base image** | A ready-made starting point for a container, with common software pre-installed. It doesn't include your code. |
| **Registry** | An online library that stores container images so MAAP can download them. |
| **GHCR** (GitHub Container Registry) | GitHub's registry — where your container image is stored so MAAP can download it. New images there start out private, and need to be made public before MAAP can use them. |
| **GitHub Action** (GHA) | An automation that runs on GitHub's computers. Here it automates deployment to MAAP: each time you push a change, it rebuilds your container, regenerates the workflow file, and updates your algorithm on MAAP — no manual steps. |
| **Workflow file** (`.github/workflows/...yml`) | The file that tells GitHub when to run the GitHub Action and what it should do. Not the same thing as the CWL workflow file. |
| **Branch** | A named line of work in your git repository, like `main`. The GitHub Action watches one branch and deploys whatever lands on it. |
| **Commit** / **push** | A commit saves a snapshot of your changes in git on your computer; a push uploads it to GitHub. MAAP can only see what has been pushed. |
| **Repository secret** | A password-like value stored securely in your GitHub repository's settings, so the GitHub Action can use it without it ever appearing in your code. |
| **MAAP token** | A personal access key from your MAAP profile page that proves to MAAP it's you registering the algorithm. Treat it like a password. |
| **Register** / **registration** | Publishing your algorithm to MAAP so it shows up as a process people can run. Registering again under the same name replaces the earlier version. |
| **Production / UAT / DIT** | Separate copies of MAAP. Production is the real one everyone uses. UAT (user acceptance testing) is a test copy for trying things out first. DIT is an internal development copy. Each has its own tokens. |
| **Endpoint** | The web address the algorithm is registered at — one per MAAP environment. |
| **Validate** / **validator** | An automatic check that the workflow file is correctly written and follows the OGC rules, before anything is sent to MAAP. |
| **`cwltool`** | A program that reads a CWL workflow file and runs it on your own computer — the way to test your algorithm locally before MAAP runs it. |
| **`ap-validator`** | The checker for the OGC Application Package rules. |
| **`input.yml`** (job file) | A small sample file of input values, so a local test run is one short command instead of typing every input. |
| **Generator** (`ogc-app-pack-generator`) | MAAP's tool that turns the settings file into the CWL workflow file. |
| **papermill** | A tool that runs a Jupyter notebook from start to finish with the input values you give it, so a notebook can run on MAAP without anyone clicking through it. |
| **Entrypoint** / **`run_command`** | The command that starts your algorithm inside the container. |
| **Command-line flag** | How an input is handed to your algorithm when it starts, like `--input_file data.tif`. |
| **STAC** | SpatioTemporal Asset Catalog — a standard way of describing satellite and other geospatial data. MAAP uses it to hand your algorithm its input data. |
| **Stage-in / stage-out** | MAAP copying your input data onto the computer running your algorithm before it starts (stage-in), and collecting your results from its `output/` folder after it finishes (stage-out). |
| **RAM / cores / MiB** | Memory, processors, and the unit sizes are measured in (1 MiB ≈ 1 MB). MAAP uses these to pick a computer big enough for the job. |
| **`linux/amd64`**, Apple Silicon | MAAP's computers use a different kind of processor than recent Macs, so a container built on a Mac has to be built specially to run on MAAP. |
| **Commit hash** / **SHA** | The unique ID of a commit — used to point MAAP at an exact version of your files. |
