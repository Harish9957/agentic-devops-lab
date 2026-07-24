# Phase 0 — Preflight

## Goal

Confirm all required tools are installed and Docker is running.

## Builds on

Nothing — first phase.

## Checks

- `kind version` exits 0
- `kubectl version --client` exits 0
- `docker info` exits 0

## Completion gate

- [x] All three checks pass on this machine (kind v0.31.0, kubectl v1.36.0 client, Docker daemon
      running — confirmed 2026-07-24) → proceed to phase 1.
