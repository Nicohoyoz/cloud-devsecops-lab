# cloud-devsecops-lab

AWS infrastructure built as code with Terraform and configured with Ansible.
Everything here is provisioned from version control, not clicked together in a
console. The aim is one documented system that shows how cloud infrastructure
gets built, configured, and (in later phases) secured and automated.

Status: in progress. The AWS networking, a running EC2 instance, and Ansible
configuration are built and working. Security scanning, CI/CD, and detection
are planned and listed in the roadmap. Each item moves out of "planned" only
once it actually works.

## Built so far

**Networking and compute (Terraform).** A VPC (`10.0.0.0/16`) with a public
subnet (`10.0.1.0/24`), an internet gateway, a route table sending outbound
traffic through it, and a default-deny security group that allows inbound SSH
and HTTP only. An Ubuntu 22.04 EC2 instance (`t3.micro`) runs in the subnet,
reachable over SSH by a registered key pair. The Ubuntu AMI is resolved at plan
time by a data source instead of being hardcoded, so it stays current and
isn't pinned to one region.

**Configuration (Ansible).** A playbook installs nginx, ensures it is running
and enabled on boot, and deploys a custom `index.html` over the default page.
The instance serves that page publicly on port 80. This is the split worth
noticing: Terraform builds the machine, Ansible decides what it runs.

The whole stack comes up with `terraform apply`, gets configured with
`ansible-playbook`, and tears down with `terraform destroy` in dependency
order. A full rebuild takes about two minutes.

## Layout

```
terraform/ (root main.tf)  VPC, subnet, gateway, routing, security group, EC2
ansible/
  inventory.ini            target host and SSH connection settings
  web.yml                  install nginx, deploy the page
  files/index.html         the page that gets served
```

## Running it

```bash
terraform init            # download the AWS provider
terraform plan            # read this before every apply
terraform apply           # build the infrastructure

cd ansible
ansible-playbook -i inventory.ini web.yml   # configure the server

terraform destroy         # tear it all down, stops cost
```

Credentials come from the AWS CLI (`~/.aws`) and are never stored in the repo.
The Terraform state file and provider cache are git-ignored. The inventory
holds the instance's public IP, which changes on each rebuild; a later phase
will have Terraform generate the inventory so that step is automatic.

## Notes on the choices

- The AMI is looked up, not hardcoded. Hardcoded AMI IDs go stale and differ
  per region.
- The security group is default-deny. Only SSH (22) and HTTP (80) are open
  inbound. SSH is open to `0.0.0.0/0` here for lab convenience; in production
  that would be a known admin IP or a bastion host.
- Compute is destroyed after each session. Infrastructure as code makes a
  two-minute rebuild cheap, so there is no reason to leave it running. A
  zero-spend billing alarm backs this up.
- Work is done as a scoped IAM user, not the AWS root account.

## Roadmap

| Phase | Item | Status |
|---|---|---|
| 2 | VPC, subnet, gateway, routing, security group, EC2 (Terraform) | Done |
| 2 | Install nginx and deploy a page (Ansible) | Done |
| 2 | Run the service in a Docker container | Planned |
| 3 | IaC security scanning with Checkov | Planned |
| 3 | CI/CD with GitHub Actions running scans on push | Planned |
| 3 | Detection rules (Sigma) mapped to MITRE ATT&CK | Planned |
| 3 | If time allows: Semgrep, Falco, k3s | Planned |

## Related

Builds on [`linux-infra-lab`](https://github.com/Nicohoyoz/linux-infra-lab):
Terraform against a local container fleet, Ansible, Docker, and
Prometheus/Grafana. This repo takes the same patterns to real cloud and adds a
security focus.
