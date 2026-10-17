#!/usr/bin/env python3
"""Antes de flutter build/run, manda o comando pelo script que tira o acento do caminho."""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WRAPPER = os.path.join(ROOT, "scripts", "build_ascii.sh")


def command_of(payload):
    if isinstance(payload.get("command"), str):
        return payload["command"], payload
    tool_input = payload.get("tool_input") or payload.get("input") or {}
    if isinstance(tool_input, dict) and isinstance(tool_input.get("command"), str):
        return tool_input["command"], tool_input
    return "", payload


def needs_wrap(command):
    if "build_ascii.sh" in command:
        return False
    stripped = command.strip()
    return stripped.startswith("flutter build") or stripped.startswith("flutter run")


def main():
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        print(json.dumps({"permission": "allow"}))
        return

    command, tool_input = command_of(payload)
    if not needs_wrap(command):
        print(json.dumps({"permission": "allow"}))
        return

    if not os.path.realpath(ROOT).isascii():
        updated = dict(tool_input)
        updated["command"] = f'"{WRAPPER}" {command}'
        print(
            json.dumps(
                {
                    "permission": "allow",
                    "updated_input": updated,
                    "agent_message": (
                        "O caminho do projeto tem acento. O build foi encaminhado "
                        "para scripts/build_ascii.sh, que compila em ~/builds/controleSaude."
                    ),
                }
            )
        )
        return

    print(json.dumps({"permission": "allow"}))


if __name__ == "__main__":
    main()
