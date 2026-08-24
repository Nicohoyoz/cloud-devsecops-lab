# Checkov Security Triage — cloud-devsecops-lab

Scan run with Checkov 3.3.13 against the Terraform in this repo.

**Result: 9 passed, 12 failed (Terraform). 4 passed, 0 failed (Ansible).**

A failed check is not automatically a defect. It is a flagged risk to make a
decision about. Below, each of the 12 Terraform findings is triaged into one of
three buckets: fix it, accept it with a reason, or not applicable at this scale.

---

## Bucket 1 — Fixed

Real, low-effort improvements that were applied to the Terraform.

| Check | Finding | Fix applied |
|---|---|---|
| CKV_AWS_79 | IMDSv1 enabled on the instance | Enforced IMDSv2 (`http_tokens = "required"`). Prevents SSRF-based theft of instance credentials. |
| CKV_AWS_8 | Root EBS volume not encrypted | Enabled EBS encryption at rest on the root volume. |
| CKV_AWS_382 | Egress open to 0.0.0.0/0 on all ports | Left in place but documented; see note. (Optional tightening.) |
| CKV_AWS_23 | Security group rules missing descriptions | Added descriptions to each rule. |

IMDSv2 is the highest-value fix here: Instance Metadata Service v1 has been the
root cause of real cloud breaches (an attacker who can make the server fetch a
URL can read its credentials). v2 requires a session token and blocks that path.

---

## Bucket 2 — Accepted, with reason

These are intentional to what this project is: a single, publicly reachable web
server. They are "failures" only against a production-hardening baseline.

| Check | Finding | Why accepted |
|---|---|---|
| CKV_AWS_24 | SSH (22) open to 0.0.0.0/0 | Deliberate lab convenience. In production this would be restricted to a known admin IP or reached through a bastion host. Flagged in code from the start. |
| CKV_AWS_260 | HTTP (80) open to 0.0.0.0/0 | This is the function of a public web server, not a defect. |
| CKV_AWS_88 | Instance has a public IP | Intended: the lab is a directly reachable server. In production the instance would be private, fronted by a load balancer for web traffic and reached over SSH through a bastion host, so it would carry no public IP. Not built here because a single-instance lab does not need that complexity. |

**On bastion / load balancer:** both exist to remove direct public exposure from
the real server — a bastion is a single hardened SSH entry point to otherwise
private servers; a load balancer takes the public traffic so servers sit private
behind it. Correct at production scale with multiple servers and a team. Adding
either to a one-instance lab would be complexity to satisfy a scanner rather than
to solve a real problem, so the decision is to document the approach, not build it.

---

## Bucket 3 — Not applicable at this scale

Production/cost-scale concerns that do not meaningfully apply to a free-tier
single-instance learning lab. Noted, not actioned.

| Check | Finding | Note |
|---|---|---|
| CKV_AWS_126 | Detailed monitoring not enabled | Adds cost; a production/observability concern. |
| CKV_AWS_135 | Instance not EBS-optimized | Matters at production I/O scale; adds cost. |
| CKV2_AWS_11 | VPC flow logs not enabled | Real in production for network forensics; cost-adding and overkill here. |
| CKV2_AWS_41 | No IAM role attached to instance | Would matter if the instance needed to call AWS APIs; it does not. |
| CKV2_AWS_12 | Default security group not locked down | Production hardening of the untouched default SG. |
| CKV2_AWS_35 | NAT gateway not used for default route | Applies to private-subnet architectures, not this design. |

---

## The point

The value of this exercise is not a clean score. It is the documented judgment:
which findings were fixed, which were accepted as intentional, and which were
out of scope for a lab — each with a reason that holds up to a follow-up question.
