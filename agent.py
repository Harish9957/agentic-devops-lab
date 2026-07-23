#!/usr/bin/env python3
"""
Agentic DevOps 01 — Claude orchestrates kind cluster creation and nginx deployment.
"""

import subprocess
import sys
import anthropic

client = anthropic.Anthropic()
MODEL = "claude-opus-4-7"

TOOLS = [
    {
        "name": "run_command",
        "description": "Run a shell command and return its stdout, stderr, and exit code.",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "The shell command to execute",
                },
            },
            "required": ["command"],
        },
    }
]

SYSTEM_PROMPT = """You are an agentic DevOps engineer. Your job is to execute the spec at spec/SPEC.md exactly.

Work through each phase sequentially:
- Phase 0: preflight checks (kind, kubectl, docker)
- Phase 1: create kind cluster using kind-config.yaml, then run tests/validate_cluster.sh
- Phase 2: deploy manifests/nginx-deployment.yaml, then run tests/validate_nginx.sh

Rules:
- Use run_command for every shell operation — never assume success
- If a command fails, report the error and stop
- After all phases pass, print the final completion summary from the spec
- Be concise in your narration; let command output speak for itself
"""

INITIAL_PROMPT = "Execute the spec at spec/SPEC.md. Begin with Phase 0."


def run_command(command: str) -> dict:
    result = subprocess.run(
        command,
        shell=True,
        capture_output=True,
        text=True,
    )
    return {
        "stdout": result.stdout.strip(),
        "stderr": result.stderr.strip(),
        "exit_code": result.returncode,
    }


def process_tool_call(tool_name: str, tool_input: dict) -> str:
    if tool_name == "run_command":
        result = run_command(tool_input["command"])
        output = f"exit_code: {result['exit_code']}"
        if result["stdout"]:
            output += f"\nstdout:\n{result['stdout']}"
        if result["stderr"]:
            output += f"\nstderr:\n{result['stderr']}"
        return output
    return f"Unknown tool: {tool_name}"


def run_agent():
    print(f"Starting Agentic DevOps 01 with model {MODEL}\n{'='*50}")

    messages = [{"role": "user", "content": INITIAL_PROMPT}]

    while True:
        response = client.messages.create(
            model=MODEL,
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        # Print any text the agent produces
        for block in response.content:
            if hasattr(block, "text"):
                print(f"\nAgent: {block.text}")

        if response.stop_reason == "end_turn":
            print("\n" + "="*50 + "\nAgent finished.")
            break

        if response.stop_reason == "tool_use":
            messages.append({"role": "assistant", "content": response.content})

            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    print(f"\n> {block.input.get('command', '')}")
                    result = process_tool_call(block.name, block.input)
                    print(result)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": result,
                    })

            messages.append({"role": "user", "content": tool_results})
        else:
            print(f"Unexpected stop reason: {response.stop_reason}")
            sys.exit(1)


if __name__ == "__main__":
    run_agent()
