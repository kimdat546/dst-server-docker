#!/usr/bin/env python3
"""Extract DST_* env vars from the master service of a docker-compose.yml.
Outputs lines KEY=value (suitable for .world.env). No PyYAML dependency."""
import re, sys

def extract(path):
    with open(path) as f:
        lines = f.readlines()

    out, in_master, in_env = {}, False, False
    env_indent = None

    for raw in lines:
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        # services.master:
        m = re.match(r"^(\s*)master:\s*$", line)
        if m:
            in_master = True
            in_env = False
            continue

        if in_master:
            # Leaving master service (top-level or sibling service)
            if re.match(r"^\S", line) or re.match(r"^  \w+:\s*$", line) and not re.match(r"^  master:", line):
                if not line.startswith("    "):  # de-indented out of master
                    in_master = False
                    in_env = False
                    continue

            # environment: block
            if re.match(r"^\s+environment:\s*$", line):
                in_env = True
                env_indent = len(line) - len(line.lstrip())
                continue

            if in_env:
                indent = len(line) - len(line.lstrip())
                if indent <= env_indent:
                    in_env = False
                else:
                    m = re.match(r'^\s+([A-Z_][A-Z0-9_]*)\s*:\s*"?(.*?)"?\s*$', line)
                    if m and m.group(1).startswith("DST_"):
                        out[m.group(1)] = m.group(2)
    return out

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "server/docker-compose.yml"
    for k, v in extract(path).items():
        # Quote values that contain whitespace or special chars
        if re.search(r'[\s#"\'$`]', v):
            v = '"' + v.replace('"', '\\"') + '"'
        print(f"{k}={v}")
