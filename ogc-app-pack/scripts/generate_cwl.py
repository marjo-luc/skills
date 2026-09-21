#!/usr/bin/env python3
"""Generate an OGC Application Package CWL locally, exactly as the GitHub Action would.

The Action derives three environment variables before calling the generator's
``build_cwl_workflow.py``:

    CWL_WORKFLOW_FILE_NAME   process_<algorithm_name>_<branch>.cwl
    DOCKER_TAG               ghcr.io/<owner>/<algorithm-name>:<branch>, or algorithm_container_url
    GIT_COMMIT_HASH          the commit the CWL describes

This script reproduces that derivation from the local git repository (mirroring
``validate_inputs.py`` at tag 1.1.0) and then shells out to the generator's own
``build_cwl_workflow.py``, so the local output matches what CI will commit.

Run scripts/fetch_generator.sh first.

Usage:
    generate_cwl.py --config-file my_algo/algorithm_config.yml \
                    --cwl-workflow-dir my_algo/cwl_workflows
    generate_cwl.py --config-file my_algo/algorithm_config.yml --print-docker-tag
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

DEFAULT_REF = "1.1.0"
CACHE_ROOT = Path(os.environ.get("OGC_APP_PACK_CACHE", Path.home() / ".cache" / "ogc-app-pack"))


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def git(*args, cwd=None):
    """Run a git command, returning stripped stdout or None on failure."""
    try:
        out = subprocess.run(
            ["git", *args], cwd=cwd, capture_output=True, text=True, check=True
        )
        return out.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def owner_from_remote(remote_url):
    """Extract the GitHub owner from an https or ssh remote URL."""
    if not remote_url:
        return None
    m = re.search(r"(?:github\.com[:/])([^/]+)/", remote_url)
    return m.group(1).lower() if m else None


def load_config(path):
    try:
        import yaml
    except ImportError:
        die("PyYAML is not available. Run this with the generator venv python "
            "(see scripts/fetch_generator.sh), or pip install PyYAML.")
    try:
        with open(path) as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        die(f"Config file not found: {path}")
    except yaml.YAMLError as e:
        die(f"Config file is not valid YAML: {e}")


def derive(config, config_path, args):
    """Mirror validate_inputs.py (1.1.0): validate, then derive the Action's env vars."""
    algorithm_name = (config.get("algorithm_name") or "").strip()
    if not algorithm_name:
        die("`algorithm_name` is required in the algorithm configuration file.")

    container_url = (config.get("algorithm_container_url") or "").strip()
    if container_url and args.containerfile:
        die("`algorithm_container_url` is set in the config, but --containerfile was also "
            "given. Only one may be provided.")

    repo_dir = Path(config_path).resolve().parent
    branch = args.branch or os.environ.get("GITHUB_REF_NAME") or git(
        "rev-parse", "--abbrev-ref", "HEAD", cwd=repo_dir
    )
    if not branch or branch == "HEAD":
        die("Could not determine the branch name. Pass --branch explicitly.")
    branch_clean = branch.replace("/", "_")

    cwl_name = f"process_{algorithm_name.replace('/', '_')}_{branch_clean}.cwl"

    if container_url:
        docker_tag = container_url
    else:
        owner = args.owner or owner_from_remote(git("remote", "get-url", "origin", cwd=repo_dir))
        if not owner:
            die("Could not determine the GitHub owner from the git remote. Pass --owner, "
                "or set `algorithm_container_url` in the config.")
        # Docker image names must be lowercase and limited to [a-z0-9._-].
        image = re.sub(r"[^a-z0-9._-]+", "-", algorithm_name.lower()).strip("-")
        docker_tag = f"ghcr.io/{owner}/{image}:{branch_clean}"

    commit = args.commit or git("rev-parse", "HEAD", cwd=repo_dir) or ""

    return cwl_name, docker_tag, commit


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--config-file", required=True, help="Path to algorithm_config.yml")
    p.add_argument("--cwl-workflow-dir", help="Output directory "
                   "(default: cwl_workflows/ beside the config file)")
    p.add_argument("--generator-dir", help=f"Generator checkout (default: {CACHE_ROOT}/generator-<ref>)")
    p.add_argument("--ref", default=DEFAULT_REF, help=f"Pinned generator tag (default: {DEFAULT_REF})")
    p.add_argument("--branch", help="Branch name; defaults to the current git branch")
    p.add_argument("--owner", help="GitHub owner; defaults to the origin remote")
    p.add_argument("--commit", help="Commit hash; defaults to HEAD")
    p.add_argument("--containerfile", help="Containerfile path, only to check it against "
                   "algorithm_container_url the way the Action does")
    p.add_argument("--print-docker-tag", action="store_true", help="Print the derived image tag and exit")
    p.add_argument("--print-cwl-name", action="store_true", help="Print the derived CWL filename and exit")
    args = p.parse_args()

    config_path = Path(args.config_file)
    config = load_config(config_path)
    cwl_name, docker_tag, commit = derive(config, config_path, args)

    if args.print_docker_tag:
        print(docker_tag)
        return
    if args.print_cwl_name:
        print(cwl_name)
        return

    gen_dir = Path(args.generator_dir) if args.generator_dir else CACHE_ROOT / f"generator-{args.ref}"
    builder = gen_dir / "build_cwl_workflow.py"
    if not builder.is_file():
        die(f"Generator not found at {gen_dir}. Run scripts/fetch_generator.sh first.")

    out_dir = Path(args.cwl_workflow_dir) if args.cwl_workflow_dir else config_path.resolve().parent / "cwl_workflows"

    # Prefer the generator venv's python so PyYAML is guaranteed present.
    venv_python = CACHE_ROOT / f"venv-{args.ref}" / "bin" / "python"
    python = str(venv_python) if venv_python.is_file() else sys.executable

    env = {
        **os.environ,
        "CWL_WORKFLOW_FILE_NAME": cwl_name,
        "DOCKER_TAG": docker_tag,
        "GIT_COMMIT_HASH": commit,
    }

    print(f"CWL_WORKFLOW_FILE_NAME = {cwl_name}", file=sys.stderr)
    print(f"DOCKER_TAG             = {docker_tag}", file=sys.stderr)
    print(f"GIT_COMMIT_HASH        = {commit}", file=sys.stderr)

    result = subprocess.run(
        [
            python, str(builder),
            "--config-file", str(config_path.resolve()),
            "--cwl-workflow-dir", str(out_dir),
            "--cwl-template-file", str(gen_dir / "templates" / "process.v1_2.cwl"),
        ],
        env=env,
    )
    if result.returncode != 0:
        die("build_cwl_workflow.py failed. Check the config against "
            "references/algorithm-config.md.")

    print(f"\nNext: validate it\n  "
          f"~/.claude/skills/ogc-app-pack/scripts/validate_cwl.sh {out_dir / cwl_name}")


if __name__ == "__main__":
    main()
