# cloud-devsecops-lab

A hands-on cloud infrastructure project built to demonstrate **infrastructure
as code, cloud networking, and (in progress) DevSecOps practices** on AWS.

Everything here is provisioned from version-controlled Terraform, not clicked
together in a console. The goal is one coherent, documented system that shows
how cloud infrastructure is built, secured, and automated, end to end.

> **Status:** actively building. Layer 2 (AWS networking + compute) is complete
> and working. Security scanning, CI/CD, and threat detection are planned and
> tracked in the roadmap below. This README reflects what is genuinely built at
> each stage.

---

## What's built so far

A complete, working AWS network built from scratch in Terraform, with a Linux
server running inside it:

- **VPC** — an isolated private network (`10.0.0.0/16`).
- **Public subnet** — a `/24` slice of the VPC (`10.0.1.0/24`).
- **Internet gateway** — the connection between the VPC and the internet.
- **Route table + association** — routes outbound traffic (`0.0.0.0/0`) through
  the gateway and attaches those rules to the subnet.
- **Security group** — default-deny firewall allowing only inbound SSH (22) and
  HTTP (80), with all outbound traffic permitted.
- **EC2 instance** — an Ubuntu 22.04 server (`t3.micro`, free-tier), launched
  into the subnet, guarded by the security group, and reachable over SSH using a
  registered key pair. The Ubuntu AMI is looked up dynamically with a Terraform
  data source rather than hardcoded.

The entire stack builds with `terraform apply` and tears down cleanly with
`terraform destroy`, in correct dependency order, in about two minutes.

### Architecture (current)

```
                    Internet
                       |
              [ Internet Gateway ]
                       |
        +--------------------------------+
        |  VPC  10.0.0.0/16              |
        |                                |
        |   [ Route Table ] --> 0.0.0.0/0 via IGW
        |          |                     |
        |   [ Public Subnet 10.0.1.0/24 ]
        |          |                     |
        |   [ Security Group ]           |
        |     inbound: SSH 22, HTTP 80   |
        |     outbound: all              |
        |          |                     |
        |   [ EC2: Ubuntu 22.04 t3.micro ]
        |                                |
        +--------------------------------+
```

---

## Tech used

- **Terraform** (HCL) — all infrastructure as code
- **AWS** — VPC, subnet, internet gateway, route tables, security groups, EC2
- **Ubuntu 22.04** on EC2, accessed via SSH key pair

---

## How it works

```bash
# initialize the working directory and download the AWS provider
terraform init

# preview exactly what will be created (read this before every apply)
terraform plan

# build the infrastructure
terraform apply

# tear it all down when done (stops all cost)
terraform destroy
```

Credentials are supplied through the AWS CLI (`~/.aws`) and are **never** stored
in the repo. The Terraform state file and provider cache are git-ignored.

---

## Design decisions worth noting

- **Look up the AMI, don't hardcode it.** A Terraform data source fetches the
  latest official Canonical Ubuntu 22.04 image, so the AMI never goes stale and
  isn't pinned to one region.
- **Default-deny security group.** Nothing is allowed inbound except the two
  ports the workload actually needs. This mirrors least-privilege firewall
  design.
- **SSH open to `0.0.0.0/0` is a deliberate lab choice.** In production this
  would be restricted to a known admin IP or a bastion host. Flagged rather than
  hidden.
- **Destroy after each session.** Compute costs money by the hour, so the
  workflow is build → verify → destroy, which infrastructure as code makes
  trivial. A zero-spend billing alarm guards the account.
- **Non-root IAM user.** All work is done as a scoped IAM user, not the AWS root
  account.

---

## Roadmap

This project is built in layers. Each item is added only when it is genuinely
working and documented.

| Layer | Focus | Status |
|---|---|---|
| **2** | AWS networking + EC2 via Terraform | **Complete** |
| 2 | Configure the instance with Ansible (web server) | Planned |
| 2 | Run a containerized service (Docker) on the instance | Planned |
| 3 | IaC security scanning (Checkov) | Planned |
| 3 | CI/CD pipeline (GitHub Actions) running scans on every push | Planned |
| 3 | Threat detection loop (Sigma rules + MITRE ATT&CK) | Planned |
| 3 | Extras if time allows: Semgrep (SAST), Falco (runtime), k3s | Planned |

---

## Related work

This project builds on a prior infrastructure lab
([`linux-infra-lab`](https://github.com/Nicohoyoz/linux-infra-lab)), which
covers Terraform against a local container fleet, Ansible configuration
management, Docker, and Prometheus/Grafana monitoring. `cloud-devsecops-lab`
takes those same patterns to real cloud infrastructure and adds a security focus.
