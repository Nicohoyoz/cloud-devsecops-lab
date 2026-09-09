# cloud-devsecops-lab

AWS infrastructure built as code with Terraform, configured with Ansible, checked
by automated security scanning in a CI/CD pipeline, and paired with detection
rules mapped to MITRE ATT&CK. Everything is provisioned from version control, not
clicked together in a console. The aim is one documented system showing how cloud
infrastructure gets built, configured, secured, continuously checked, and
monitored for attacks.

Status: in progress. AWS networking, a running EC2 instance, Ansible
configuration, an IAM role, Checkov scanning, a GitHub Actions pipeline, and
Sigma detection rules are built. A live SIEM deployment (Elastic) and container
packaging are planned, and listed in the roadmap. Each item moves out of
"planned" only once it works.

## Built so far

**Networking and compute (Terraform).** A VPC (`10.0.0.0/16`) with a public
subnet (`10.0.1.0/24`) pinned to an availability zone, an internet gateway, a
route table, and a default-deny security group allowing inbound SSH and HTTP
only. An Ubuntu 22.04 EC2 instance (`t3.micro`) runs in the subnet. The AMI is
resolved at plan time by a data source instead of being hardcoded.

**Configuration (Ansible).** A playbook installs nginx, ensures it runs and is
enabled on boot, and deploys a custom page. Terraform builds the machine; Ansible
decides what it runs.

**IAM role (Terraform).** The instance has a least-privilege IAM role attached
through an instance profile, granting SSM management access via the AWS-managed
`AmazonSSMManagedInstanceCore` policy. The instance gets temporary,
auto-rotating credentials through the metadata endpoint (protected by IMDSv2)
rather than static keys.

**Security scanning (Checkov).** The Terraform is scanned with Checkov. Findings
were triaged, not blindly fixed to green: real issues corrected, intentional lab
choices accepted with reasons, production-scale items ruled out of scope. Score
went from 9 passed / 12 failed to 20 passed / 8 failed. Fixes: IMDSv2 enforced
(SSRF mitigation), EBS encryption at rest, IAM role attached, security-group rule
descriptions. Full triage in
[`security/checkov-triage.md`](security/checkov-triage.md).

**CI/CD (GitHub Actions).** A workflow in
[`.github/workflows/`](.github/workflows/) runs the Checkov scan automatically on
every push and pull request, with soft-fail so findings surface as annotations
while the build passes on already-triaged risks.

**Detection (Sigma + MITRE ATT&CK).** Detection rules in
[`detection/`](detection/) written in vendor-neutral Sigma format and mapped to
ATT&CK techniques: SSH brute force (T1110) and download-and-execute (T1059).
Techniques were chosen from current threat reporting and for fitting a Linux
host; each rule documents its blind spots and false positives. See
[`detection/README.md`](detection/README.md).

The stack comes up with `terraform apply`, is configured with `ansible-playbook`,
is scanned on every push, and tears down with `terraform destroy`. A full rebuild
takes about two minutes.

## Layout

```
main.tf                       VPC, subnet, gateway, routing, security group,
                              EC2, IAM role + instance profile
ansible/
  inventory.ini               target host and SSH connection settings
  web.yml                     install nginx, deploy the page
  files/index.html            the page that gets served
security/
  checkov-triage.md           every finding, triaged with reasons
  checkov-results.txt         raw scan output
.github/workflows/
  security_scanner.yml        runs Checkov on every push / pull request
detection/
  ssh-bruteforce.yml          Sigma rule — SSH brute force (T1110)
  suspicious-command.yml      Sigma rule — download and execute (T1059)
  README.md                   rule logic, ATT&CK mappings, limitations
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
State file and provider cache are git-ignored. The inventory holds the instance's
public IP, which changes each rebuild; a later phase will have Terraform generate
it automatically.

## Notes on the choices

- **AMI looked up, not hardcoded.** Hardcoded IDs go stale and differ per region.
- **Default-deny security group.** Only SSH (22) and HTTP (80) open inbound. SSH
  is open to `0.0.0.0/0` for lab convenience; production would restrict it or use
  SSM Session Manager. Checkov flags this; the triage doc accepts it with reason.
- **Public IP is intentional.** A single reachable lab server; production would be
  private behind a load balancer, reached via a bastion.
- **Least-privilege IAM role.** SSM access via an AWS-managed policy; temporary
  credentials over the IMDSv2-protected metadata endpoint, no static keys.
- **Soft-fail in CI.** The pipeline reports every finding but blocks only on hard
  errors, so triaged-and-accepted risks don't fail the build.
- **Detections match the system.** Rules target trending techniques that fit a
  Linux host; unfit ones (phishing, process injection) were deliberately excluded.
- **Destroy after each session.** IaC makes a two-minute rebuild cheap. A
  zero-spend billing alarm backs this up.

## Roadmap

| Phase | Item | Status |
|---|---|---|
| 2 | VPC, subnet, gateway, routing, security group, EC2 (Terraform) | Done |
| 2 | Install nginx and deploy a page (Ansible) | Done |
| 3 | IaC security scanning with Checkov, findings triaged | Done |
| 3 | CI/CD pipeline running the scan on every push (GitHub Actions) | Done |
| 3 | IAM role as code, attached to the instance | Done |
| 3 | Sigma detection rules mapped to MITRE ATT&CK | Done |
| 3 | Deploy detections to a live SIEM (Elastic / ELK in Docker) | Planned |
| 2 | Run the service in a Docker container | Planned |

## Related

Builds on [`linux-infra-lab`](https://github.com/Nicohoyoz/linux-infra-lab):
Terraform against a local container fleet, Ansible, Docker, and
Prometheus/Grafana. This repo takes those patterns to real cloud and adds a
security and detection focus.
