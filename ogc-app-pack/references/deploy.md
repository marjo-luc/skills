# Building, pushing, and registering

Two routes. **Prefer the GitHub Action** — it is the supported path, it commits the CWL with the
real commit hash, and it registers from a raw GitHub URL MAAP can fetch. Do it locally only when
the user asks directly.

Pushing an image and registering a process are both outward-facing and both overwrite whatever
already exists under that name. **Confirm with the user before either.**

## First, commit and push

Both routes need the work committed and pushed, for different reasons: the Action only runs on a
push, and a local registration sends MAAP a URL it fetches server-side, which has to resolve
anonymously. Review the diff with the user, commit, and push — asking before each.

Two things to get right:

- **`s:commitHash` follows generation order.** It is stamped from `HEAD` when the CWL is built, so a
  CWL generated before its algorithm was committed names the parent commit. Commit source and
  config, regenerate, then commit the CWL; or let the Action do it, since it generates after
  checking out the pushed commit and commits the CWL back itself.
- **The push may be the deployment.** With `deploy-app-pack: true` in a workflow watching that
  branch, pushing builds the image, pushes it to GHCR, commits the CWL, and registers the process at
  whatever `app-pack-register-endpoint` names. Tell the user which endpoint that is before they push,
  not after.

```bash
git status --short && git diff --stat     # review together
git add <the app pack files> && git commit
git push
git rev-parse HEAD                        # the SHA for the raw CWL URL
```

## Route 1 — GitHub Actions (recommended)

Write `.github/workflows/<algorithm-name>.yml` from `assets/github-workflow.yml`:

```yaml
name: my-algorithm
on:
  push:
    branches: [main]
    paths:
      - 'my_algo/**'
      - '.github/workflows/my-algorithm.yml'

jobs:
  generate_app_pack:
    runs-on: ubuntu-latest
    permissions:
      contents: write     # required: the Action commits the CWL back
      packages: write     # required: the Action pushes to GHCR
    steps:
      - uses: actions/checkout@v6
      - uses: MAAP-Project/ogc-app-pack-generator@1.1.0
        with:
          algorithm-configuration-path: my_algo/algorithm_config.yml
          dockerfile-path: my_algo/Containerfile
          cwl-workflow-dir: my_algo/cwl_workflows
          deploy-app-pack: true
          app-pack-register-endpoint: https://api.uat.maap-project.org/api/ogc/processes
        env:
          MAAP_TOKEN: ${{ secrets.MAAP_TOKEN }}
```

On push the Action: validates the config and derives `DOCKER_TAG` + `CWL_WORKFLOW_FILE_NAME` →
generates the CWL → runs `cwltool --validate --strict` and `ap-validator` → logs into GHCR, builds
from the repo root and pushes → commits the CWL to the triggering branch → POSTs the raw CWL URL to
the register endpoint.

Setup notes:

- `MAAP_TOKEN` must exist as a repository secret (a MAAP PGT or JWT). Get the token from the profile
  page of the environment being deployed to — production
  <https://console.maap-project.org/profile/tokens>, UAT
  <https://console.uat.maap-project.org/profile/tokens> — and add it under *Settings → Secrets and
  variables → Actions → New
  repository secret*, per
  <https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets>.
  `gh secret set MAAP_TOKEN --repo <org>/<repo>` does the same from a terminal without echoing the
  value. Reference it only as `${{ secrets.MAAP_TOKEN }}`; never commit it to the workflow file.
- Omit `dockerfile-path` when the config sets `algorithm_container_url`; supplying both is rejected.
- If several algorithms live in one repo, give each its own workflow and add a
  `concurrency: {group: ogc-app-pack-deploy, cancel-in-progress: false}` block to a shared reusable
  workflow — the Action pushes commits, so parallel runs race on the push.
- It pushes to the triggering branch, so it must run where it is allowed to push. Don't run it on
  untrusted pull requests.

## Route 2 — Local

### Build and push

The image tag must match `dockerPull` in the generated CWL:

```bash
TAG=$(~/.claude/skills/ogc-app-pack/scripts/generate_cwl.py \
        --config-file my_algo/algorithm_config.yml --print-docker-tag)

docker build --platform linux/amd64 -f my_algo/Containerfile -t "$TAG" .   # context is the repo root
echo "$GITHUB_TOKEN" | docker login ghcr.io -u <username> --password-stdin
docker push "$TAG"
```

**`--platform linux/amd64` is not optional on Apple Silicon.** A local build defaults to the host
architecture, so an arm64 Mac produces an arm64 image that test-runs perfectly with `cwltool` — and
then fails on MAAP's amd64 workers with `exec format error`, or won't be pulled at all. Check with
`docker image inspect <tag> --format '{{.Architecture}}'` before pushing. The Action doesn't have
this problem: it builds on `ubuntu-latest`, which is amd64. One more reason to prefer Route 1.

The GHCR token needs `write:packages`. A newly pushed package is **private** by default — MAAP
cannot pull it until it is made public in the package settings, or credentials are configured.

### Register

MAAP fetches the CWL from the URL you send, so it has to be publicly reachable first — commit and
push the CWL, then use its raw URL pinned to a commit SHA:

```bash
CWL_URL="https://raw.githubusercontent.com/ORG/REPO/$(git rev-parse HEAD)/my_algo/cwl_workflows/process_<name>_<branch>.cwl"

~/.claude/skills/ogc-app-pack/scripts/register_app_pack.sh \
    --cwl-url "$CWL_URL" \
    --endpoint https://api.maap-project.org/api/ogc/processes \
    --dry-run                      # drop to submit
```

`--dry-run` prints the endpoint, the URL, the exact body, and the token's length and source — never
its value — and submits nothing. Always do that first and show it to the user.

The script needs no venv (curl + python3), checks the CWL URL resolves anonymously before sending,
and handles the 409 → PUT upsert. The generator's own `deploy_app_pack.py` does the same thing and
is equivalent, if you want the upstream code path:

```bash
export MAAP_TOKEN=...
python3 "$GEN_DIR/deploy_app_pack.py" \
    --process-cwl-url "$CWL_URL" \
    --app-pack-register-endpoint https://api.maap-project.org/api/ogc/processes \
    --app-pack-template-file "$GEN_DIR/templates/ogcapppkg.yml"
```

`$GEN_DIR` is printed by `scripts/fetch_generator.sh`; run it inside that venv (`requests`, `yaml`).
It reads the token from `$MAAP_TOKEN` only, and raises `ValueError` when it is unset.

### Handling the token

The token is a MAAP PGT or JWT and it is a credential — treat it like one.

1. **Prefer the environment.** Test `[ -n "${MAAP_TOKEN:-}" ]`; never `echo "$MAAP_TOKEN"`.
2. **If it is unset or empty, ask the user for it.** Offer the route that keeps it out of the
   transcript first — they run it themselves:
   ```bash
   ! printf '%s' '<token>' > ~/.maap_token && chmod 600 ~/.maap_token
   ```
   then pass `--token-file ~/.maap_token`. Note that a token pasted into chat is in the transcript,
   and is worth rotating afterwards.
3. **If they paste it**, write it to the scratchpad at mode 600, use `--token-file`, and delete it
   when finished.

Never write a token into the repository, `algorithm_config.yml`, the CWL, a commit message, a
GitHub workflow file, or memory. In CI it belongs in `secrets.MAAP_TOKEN` and nowhere else. A token
is environment-specific: one issued for UAT will 401 against production.

The request body is `{"executionUnit": {"href": "<cwl url>"}}` with the token in a `proxy-ticket`
header. It POSTs; on **409 Conflict** (process already exists) it extracts the `processID` and
retries as `PUT /<processID>`, overwriting the existing process. So **registration is an upsert** —
re-registering the same `algorithm_name` replaces the deployed process. A successful response
carries a `processPipelineLink.href` for watching deployment status.

### Endpoints

| Environment | Register endpoint | Token from |
|---|---|---|
| Production | `https://api.maap-project.org/api/ogc/processes` | <https://console.maap-project.org/profile/tokens> |
| UAT | `https://api.uat.maap-project.org/api/ogc/processes` | <https://console.uat.maap-project.org/profile/tokens> |
| DIT | `https://api.dit.maap-project.org/api/ogc/processes` | The DIT console's profile page — ask, don't guess the host |

The token has to come from the same row as the endpoint; a token from one environment 401s against
another.

Registering in UAT or DIT first, and confirming the process runs there, is the low-risk order —
production registration overwrites the live process of that name. Follow the user's choice of
environment; mention the order once if they go straight to production.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Environment variable 'MAAP_TOKEN' is not set` | Missing secret or unexported local variable |
| HTTP 401/403 | Expired or wrong-environment MAAP token (a UAT token 401s against production) |
| `GET <cwl-url> returned HTTP 404` from the register script | CWL not committed and pushed yet, or the raw URL names a wrong branch/SHA |
| HTTP 409 then failure | Response lacked `additionalProperties.processID`; inspect the printed body |
| MAAP can't fetch the CWL | URL not public, or points at a branch/commit not yet pushed |
| MAAP can't pull the image | GHCR package still private |
| `exec format error`, or no manifest for linux/amd64 | Image built on Apple Silicon without `--platform linux/amd64` |
| Action fails at the commit step | Workflow lacks `contents: write` |
| Action fails pushing the image | Workflow lacks `packages: write` |
