#!/usr/bin/env python3
# ------------------------------------------------------------------------------
# OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
# ------------------------------------------------------------------------------
# Name.......: connector_setup.py
# Author.....: Stefan Oehrli (oes) stefan.oehrli@oradba.ch
# Date.......: 2026.10.19
# Version....: v0.1.0
# Purpose....: Run the Data Safe connector setup.py install non-interactively.
# Notes......: Same approach as odb_datasafe ds_connector_create.sh: getpass is
#              replaced so the bundle key is never typed and never an argument.
#              Usage: connector_setup.py <setup.py> <key.b64> <connector-port>
# Reference..: https://github.com/oehrlis/oci-labs
# License....: Apache License Version 2.0
# ------------------------------------------------------------------------------
"""Non-interactive wrapper around the Data Safe connector setup.py."""

import base64
import getpass
import pathlib
import runpy
import sys


def main() -> int:
    """Read the base64 bundle key and run setup.py install."""
    if len(sys.argv) != 4:
        print("Usage: connector_setup.py <setup.py> <key.b64> <connector-port>", file=sys.stderr)
        return 2
    setup_path, key_file, port = sys.argv[1:4]
    bundle_key = base64.b64decode(pathlib.Path(key_file).read_text().strip()).decode().strip()
    if not bundle_key:
        print(f"ERROR: empty bundle key in {key_file}", file=sys.stderr)
        return 1

    def _prompt(prompt="Enter install bundle key:", stream=None):  # noqa: ARG001
        return bundle_key

    getpass.getpass = _prompt
    sys.argv = [setup_path, "install", "--connector-port", port]
    runpy.run_path(setup_path, run_name="__main__")
    return 0


if __name__ == "__main__":
    sys.exit(main())
