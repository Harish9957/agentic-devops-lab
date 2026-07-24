# Phase 2 — Apply

## Goal

Actually create the VPC, subnet, Internet Gateway, and route table in AWS, from the plan reviewed
in phase 1.

## Builds on

Phase 1 (plan reviewed, `tfplan` file exists and matches what was shown).

## BLOCKED

Do not run `terraform apply` for this phase until the user explicitly authorizes this specific
run — a general "go ahead with 02" earlier in the conversation does not count as authorization for
this step. This file stays unchecked until that explicit go-ahead is given and recorded below.

## Steps (once authorized)

1. `terraform apply tfplan` — applies the exact plan from phase 1, not a freshly generated one
2. `aws ec2 describe-vpcs --vpc-ids <output.vpc_id>` and
   `aws ec2 describe-subnets --subnet-ids <output.public_subnet_id>` to confirm real state matches

## Completion gate

- [ ] User explicitly authorized this apply (record date/confirmation here when it happens)
- [ ] `terraform apply` completes: 5 added, 0 changed, 0 destroyed
- [ ] `aws ec2 describe-vpcs` shows the VPC in `available` state

## Notes / decisions

(Fill in once authorized and run.)
