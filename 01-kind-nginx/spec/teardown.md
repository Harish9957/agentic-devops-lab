# Teardown

## Goal

Cleanly remove the `devops-01` kind cluster and confirm no leftover state, so the environment can
be rebuilt from phase 1 with a clean, idempotent history.

## Not a phase

This is a reset/lifecycle operation, not forward progress toward `spec.md`'s Completion Promise.
Nothing in `phases/` builds on top of it, and it doesn't build on any phase either — run it
whenever, independent of where phase progression currently stands.

## Steps

1. `kind delete cluster --name devops-01`

## Completion gate

- [x] `kind get clusters` does not list `devops-01` (confirmed 2026-07-24)
- [x] `kubectl config get-contexts` does not list `kind-devops-01`

## Notes / decisions

`kind delete cluster` removed the kubectl context automatically — no manual `kubectl config
delete-context` needed. Nothing left behind on the first run.
