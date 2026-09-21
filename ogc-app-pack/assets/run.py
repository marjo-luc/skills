#!/usr/bin/env python3
"""Entrypoint that maps the OGC ``--<name> value`` inputs onto papermill
parameters and executes the notebook.

Each argparse flag here must match an input `name` in algorithm_config.yml, and
each parameter key must match a variable in the notebook's `parameters` cell.
"""

import argparse
import os

import papermill as pm

NOTEBOOK_PATH = "/app/NOTEBOOK.ipynb"
OUTPUT_DIR = "output"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Execute the NOTEBOOK notebook with papermill."
    )
    parser.add_argument(
        "--input_param",
        required=True,
        help="What this parameter is.",
    )
    parser.add_argument(
        "--output_file",
        default="output.txt",
        help="Name of the output file (default: output.txt).",
    )
    args = parser.parse_args()

    # The notebook writes results into ./output; keep the executed copy there too.
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    executed_notebook = os.path.join(OUTPUT_DIR, "executed_NOTEBOOK.ipynb")

    pm.execute_notebook(
        NOTEBOOK_PATH,
        executed_notebook,
        parameters={
            "input_param": args.input_param,
            "output_file": args.output_file,
        },
    )


if __name__ == "__main__":
    main()
