# SIEM Lab — Detection Rules in Elastic (ELK)

A local Elastic SIEM (Elasticsearch + Kibana in Docker) used to **deploy and
validate detection rules** against simulated attack logs. This is where the
Sigma rules in [`../detection/`](../detection/) go from authored logic to a
running detection that fires an alert.

> **Result:** a threshold detection rule for SSH brute force (MITRE ATT&CK
> T1110) was built, enabled, and **fired an alert** on simulated attack traffic
> (6 failed logins from one source IP). Screenshot below.

## Architecture

```
sample auth logs ──(bulk API)──> Elasticsearch (store + search)
                                        │
                                   Kibana (UI, detection engine)
                                        │
                            Threshold rule runs on a schedule
                                        │
                              src_ip failures >= 5  ──> ALERT
```

- **Elasticsearch** — stores and indexes the logs; runs the queries.
- **Kibana** — the UI and the detection-rule engine; where alerts surface.
- Both run as containers via `docker-compose.yml` (Docker Compose).

## What was built

1. **Stood up a secured ELK stack** in Docker. Security is enabled (auth
   required) because Elastic's detection engine will not run without it.
2. **Ingested sample auth logs** into an `auth-logs` index via the bulk API —
   six failed SSH logins from a single source IP (`192.168.1.100`) plus a
   legitimate success, i.e. a brute-force pattern.
3. **Built a Threshold detection rule:**
   - Query: `event: "ssh_login_failed"`
   - Group by `src_ip.keyword`, threshold `>= 5`
   - Severity High, mapped to the SSH brute-force technique (ATT&CK T1110)
   - Runs every 5 minutes with a 24h look-back.
4. **Validated it end to end** — the rule ran, matched 6 failures from one IP,
   and generated an alert.

## Proof

![Detection alert fired](alert-fired.png)

*The Alerts view showing the fired "SSH_login_failed Alert" (High severity).*

## Detection logic → why it works

The rule expresses the same logic as the authored Sigma rule
(`../detection/ssh-bruteforce.yml`): **many failed logins from one source in a
window = brute force.** Grouping by `src_ip.keyword` and alerting at `>= 5`
catches the noisy single-source attack. (Its blind spots — distributed and
low-and-slow attacks — are documented with the Sigma rule.)

## Security notes (secrets are NOT in this repo)

This is a local lab, but it was configured the right way:

- **Security enabled** — Elasticsearch and Kibana both require authentication.
- **Encryption key generated, not guessed** — `openssl rand -hex 16` produces a
  random key for Kibana's saved-objects encryption. The committed
  `docker-compose.yml` uses **placeholders**; real passwords and keys are set
  via environment / a `.gitignored` file and never committed. Hardcoding
  secrets in a public repo is exactly the vulnerability being avoided.
- **Production framing** — locally this runs in Docker for free. In production
  the same SIEM would run on cloud infrastructure, ingesting logs from the EC2
  fleet built in this repo; detections would notify via connectors (Slack,
  PagerDuty) rather than only the Alerts page.

## Run it

```bash
# set real secrets in your shell/.env first (never commit them):
#   ELASTIC_PASSWORD, kibana password, and
#   XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY (openssl rand -hex 16)

docker compose up -d                 # start Elasticsearch + Kibana
# set the kibana_system password inside Elasticsearch, then restart kibana
# load sample logs via the bulk API into auth-logs
# build/enable the Threshold rule in Security > Rules, watch Security > Alerts
docker compose down                  # stop (named volume keeps the data)
```

## What this demonstrates

Not just *authoring* detections, but **operating a SIEM**: standing up the
platform, securing it, ingesting logs, writing a detection rule, and validating
it fires — the core of what a detection engineer / SOC does.
