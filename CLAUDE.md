# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal sandbox for experimenting with agentic AI / DevOps patterns on a local
[Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) cluster. No production stakes — this is
where new ideas get tried before they'd ever be proposed at work. The owner is a DevOps engineer
strong in Kubernetes, Terraform, GitLab CI, AWS, GPU scheduling (HAMi), KEDA, and Karpenter, using
this repo to explore what of that translates into an AI-native platform.

The first exercise (`agent.py`) is Claude itself acting as the agentic CLI that drives a kind
cluster through `spec.md`'s phases via a single `run_command` tool — see Architecture below.

## Commands

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=...    # or however credentials are provided
python3 agent.py                # runs the full spec.md phase progression
```

Manual / debugging equivalents of what the agent does:

```bash
kind create cluster --name devops-01 --config kind-config.yaml
kubectl config use-context kind-devops-01
bash tests/validate_cluster.sh
kubectl apply -f manifests/nginx-deployment.yaml
kubectl rollout status deployment/nginx -n default --timeout=120s
bash tests/validate_nginx.sh
```

Tear down: `kind delete cluster --name devops-01`.

## Architecture

- `agent.py` is a minimal agent loop against the Anthropic Messages API: one tool (`run_command`,
  arbitrary shell) and a system prompt that tells the model to execute `spec.md` phase by phase,
  never assume a command succeeded, and stop on the first failure. There's no other tool — the
  model does everything (checking cluster state, applying manifests, running tests) by shelling out.
- The **tests are the actual gate**, not the model's judgment: `tests/validate_cluster.sh` and
  `tests/validate_nginx.sh` are plain bash scripts with hard pass/fail exit codes. The agent is
  instructed to run them and treat a nonzero exit as a stop condition.
- `spec.md` + `phaseN-*.md` is the process this and future exercises follow: `spec.md` states the
  overall goal and non-negotiable rules and links to phase docs; each `phaseN-*.md` has its own
  goal, steps, and completion gate. Don't start phase N until phase N-1's gate is checked off. Only
  write the next phase doc once the current one is solid — don't pre-write the whole roadmap.

## Cluster conventions

- Cluster name: `devops-01`, kubectl context `kind-devops-01` (both hardcoded in the test scripts —
  keep them in sync if either ever changes).
- Two nodes: control-plane + worker (`kind-config.yaml`).
- Namespaces: `default` for now; move to one-per-logical-area, descriptive kebab-case, if later
  phases add distinct components.
- Verify `kubectl config current-context` before any mutating command if more than one cluster
  context exists on this machine.

## Notes on strengths vs. this environment

Some of the owner's usual tools are cloud- or hardware-specific and don't map 1:1 onto a local Kind
cluster — call this out explicitly in a phase doc rather than silently skipping or faking it:

- **Karpenter** provisions real cloud nodes; it has no meaning on Kind's fixed set of
  Docker-container "nodes". A phase that wants to explore Karpenter needs a real cloud target (or
  scope itself to reading/adapting Karpenter's provisioning concepts, not running it).
- **GPU / HAMi** need a GPU actually passed through to the Kind node's container runtime. Not
  checked yet on this machine — confirm before assuming a HAMi phase can run as designed.
- **KEDA** and general autoscaling-on-metrics work fine on Kind as-is.
- **GitLab** can run in-cluster (Helm chart) or be simulated with a local runner against
  gitlab.com — pick per phase depending on whether the point is GitLab CI/CD or just "a git remote".
- **Terraform**: not used for cluster creation yet (plain `kind create cluster` for now per
  phase1); revisit once there's enough to declare that Terraform earns its keep.

## Writing standards for docs in this repo

- Direct and declarative. No filler, no hedging.
- If something in a phase doc turned out to be wrong or was abandoned, say so plainly rather than
  quietly deleting it — the failed attempt is useful context for next time.
