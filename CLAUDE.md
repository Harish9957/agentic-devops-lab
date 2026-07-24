# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal sandbox for experimenting with agentic AI / DevOps patterns, mostly on a local
[Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) cluster. No production stakes — this is
where new ideas get tried before they'd ever be proposed at work. The owner is a DevOps engineer
strong in Kubernetes, Terraform, GitLab CI, AWS, GPU scheduling (HAMi), KEDA, and Karpenter, using
this repo to explore what of that translates into an AI-native platform.

## Repo structure

Each use case is a numbered top-level directory (`01-kind-nginx/`, `02-...`, etc.), expected to grow
to roughly two dozen over time. Conventions:

- The numbered prefix is load-bearing — don't reorder or renumber existing directories.
- Each use case is self-contained: its own `spec/` (goal, rules, phase docs — see Process below),
  its own manifests/scripts/tests. Nothing outside a use case's own directory should need to change
  when that use case's internals change.
- Shared, cross-use-case things stay at repo root: this `CLAUDE.md`, `requirements.txt`, the shared
  `.venv/`, and `.env` (credentials — Anthropic API key, etc. — reused across use cases rather than
  duplicated per directory).
- Only scope and write the next use case once the current one is solid. Don't pre-create empty
  numbered folders for use cases that haven't been designed yet.

### Use cases

| # | Directory | What it is |
|---|-----------|------------|
| 01 | [`01-kind-nginx/`](./01-kind-nginx/) | Claude (`agent.py`) drives a kind cluster from scratch and deploys nginx onto it, phase by phase |

## Commands

One-time setup (repo root):

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Running a use case's agent (from inside that use case's directory, so its relative paths resolve):

```bash
cd 01-kind-nginx
python3 agent.py    # runs the full spec/spec.md phase progression; needs ANTHROPIC_API_KEY in ../.env
```

## Process (applies to every use case)

- `spec/spec.md` + `spec/phases/phaseN-*.md`: `spec.md` states the overall goal and non-negotiable
  rules and links to phase docs; each `phaseN-*.md` has its own goal, steps, and completion gate.
  Don't start phase N until phase N-1's gate is checked off. Only write the next phase doc once the
  current one is solid — don't pre-write the whole roadmap.
- **Tests are the actual gate, not the model's judgment.** Every use case's completion gates should
  be backed by a real script with a hard pass/fail exit code, not the agent's self-report.
- Teardown/reset operations are not phases (a phase implies forward progress that later phases build
  on; teardown is the opposite). Give them their own unnumbered `spec/teardown.md` instead — see
  `01-kind-nginx/spec/teardown.md` for the pattern.

## Notes on strengths vs. a local Kind cluster

Some of the owner's usual tools are cloud- or hardware-specific and don't map 1:1 onto a local Kind
cluster — call this out explicitly in a phase doc rather than silently skipping or faking it:

- **Karpenter** provisions real cloud nodes; it has no meaning on Kind's fixed set of
  Docker-container "nodes". A use case that wants to explore Karpenter needs a real cloud target (or
  scope itself to reading/adapting Karpenter's provisioning concepts, not running it).
- **GPU / HAMi** need a GPU actually passed through to the Kind node's container runtime. Not
  checked yet on this machine — confirm before assuming a HAMi use case can run as designed.
- **KEDA** and general autoscaling-on-metrics work fine on Kind as-is.
- **GitLab** can run in-cluster (Helm chart) or be simulated with a local runner against
  gitlab.com — pick per use case depending on whether the point is GitLab CI/CD or just "a git remote".
- **Terraform**: not used for cluster creation yet (plain `kind create cluster` in `01-kind-nginx`);
  revisit once there's enough to declare that Terraform earns its keep.

## Writing standards for docs in this repo

- Direct and declarative. No filler, no hedging.
- If something in a phase doc turned out to be wrong or was abandoned, say so plainly rather than
  quietly deleting it — the failed attempt is useful context for next time.
