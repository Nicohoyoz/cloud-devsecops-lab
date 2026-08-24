# cloud-devsecops-lab

AWS infrastructure built as code with Terraform, configured with Ansible, and
checked by automated security scanning in a CI/CD pipeline. Everything here is
provisioned from version control, not clicked together in a console. The aim is
one documented system that shows how cloud infrastructure gets built, configured,
secured, and continuously checked.

Status: in progress. The AWS networking, a running EC2 instance, Ansible
configuration, Checkov security scanning, and a GitHub Actions pipeline are built
and working. Container packaging and threat detection are planned and listed in
the roadmap. Each item moves out of "planned" only once it actually works.

## Built so far

**Networking and compute (Terraform).** A VPC (`10.0.0.0/16`) with a public
subnet (`10.0.1.0/24`) pinned to an availability zone, an internet gateway, a
route table sending outbound traffic through it, and a default-deny security
group that allows inbound SSH and HTTP only. An Ubuntu 22.04 EC2 instance
(`t3.micro`) runs in the subnet, reachable over SSH by a registered key pair.
The Ubuntu AMI is resolved at plan time by a data source instead of being
hardcoded, so it stays current and isn't pinned to one region.

**Configuration (Ansible).** A playbook installs nginx, ensures it is running
and enabled on boot, and deploys a custom page over the default. The instance
serves that page publicly on port 80. The split worth noticing: Terraform builds
the machine, Ansible decides what it runs.

**Security scanning (Checkov).** The Terraform is scanned with Checkov. Findings
were triaged rather than blindly "fixed to green": genuine issues were corrected,
intentional lab choices were accepted with reasons, and production-scale items
were noted as out of scope. Fixes applied and verified:

- **IMDSv2 enforced** (`http_tokens = "required"`) — blocks SSRF-based theft of
  the instance's credentials via the metadata service.
- **EBS encryption at rest** on the root volume.
- **Security-group rule descriptions** on every rule.

The full triage is in
[`security/checkov-triage.md`](security/checkov-triage.md); raw scan output is in
[`security/checkov-results.txt`](security/checkov-results.txt).

**CI/CD (GitHub Actions).** A workflow in
[`.github/workflows/`](.github/workflows/) runs the Checkov scan automatically on
every push and pull request, on a GitHub-hosted runner. It uses soft-fail, so all
findings surface as annotations for visibility while the build passes on the
risks already triaged and accepted. The scan is no longer something to remember
to run; the pipeline enforces it.

The whole stack comes up with `terraform apply`, gets configured with
`ansible-playbook`, is scanned on every push by the pipeline, and tears down with
`terraform destroy`. A full rebuild takes about two minutes.

## Layout

```
main.tf                       VPC, subnet, gateway, routing, security group, EC2
ansible/
  inventory.ini               target host and SSH connection settings
  web.yml                     install nginx, deploy the page
  files/index.html            the page that gets served
security/
  checkov-triage.md           every finding, triaged with reasons
  checkov-results.txt         raw scan output
.github/workflows/
  security_scanner.yml        runs Checkov on every push / pull request
```

## Running it

```bash
terraform init            # download the AWS provider
terraform plan            # read this before every apply
terraform apply           # build the infrastructure

cd ansible
ansible-playbook -i inventory.ini web.yml   # configure the server

checkov -d .              # scan locally (also runs automatically in CI)

terraform destroy         # tear it all down, stops cost
```

Credentials come from the AWS CLI (`~/.aws`) and are never stored in the repo.
The Terraform state file and provider cache are git-ignored. The inventory holds
the instance's public IP, which changes on each rebuild; a later phase will have
Terraform generate the inventory so that step is automatic.

## Notes on the choices

- **AMI looked up, not hardcoded.** Hardcoded AMI IDs go stale and differ per
  region.
- **Default-deny security group.** Only SSH (22) and HTTP (80) are open inbound.
  SSH is open to `0.0.0.0/0` here for lab convenience; in production that would
  be a known admin IP or a bastion host. Checkov flags this and the triage doc
  accepts it with that reasoning.
- **Public IP is intentional.** The lab is a single reachable server. In
  production the instance would be private, fronted by a load balancer for web
  traffic and reached over SSH through a bastion, carrying no public IP.
- **Soft-fail in CI.** The pipeline reports every finding but only blocks on hard
  errors, so triaged-and-accepted risks don't fail the build. A stricter,
  fail-the-build posture is a later step.
- **Destroy after each session.** Infrastructure as code makes a two-minute
  rebuild cheap. A zero-spend billing alarm backs this up.
- **Scoped IAM user, not root.** All work is done as a non-root IAM user.

## Roadmap

| Phase | Item | Status |
|---|---|---|
| 2 | VPC, subnet, gateway, routing, security group, EC2 (Terraform) | Done |
| 2 | Install nginx and deploy a page (Ansible) | Done |
| 3 | IaC security scanning with Checkov, findings triaged | Done |
| 3 | CI/CD pipeline running the scan on every push (GitHub Actions) | Done |
| 2 | Run the service in a Docker container | Planned |
| 3 | IAM role as code, attached to the instance | Planned |
| 3 | Detection rules (Sigma) mapped to MITRE ATT&CK | Planned |
| 3 | If time allows: Semgrep, Falco, k3s | Planned |

## Related

Builds on [`linux-infra-lab`](https://github.com/Nicohoyoz/linux-infra-lab):
Terraform against a local container fleet, Ansible, Docker, and
Prometheus/Grafana. This repo takes the same patterns to real cloud and adds a
security focus.
