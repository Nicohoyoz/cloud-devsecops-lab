# Detection Engineering — Sigma Rules mapped to MITRE ATT&CK

This folder contains detection rules written in [Sigma](https://github.com/SigmaHQ/sigma),
a vendor-neutral format for detection logic. A Sigma rule describes a suspicious
pattern once and converts to the query language of any SIEM (Splunk, Elastic,
Microsoft Sentinel), so the detection logic isn't locked to one tool.

Each rule is mapped to a technique in [MITRE ATT&CK](https://attack.mitre.org/),
the industry-standard catalog of real-world attacker behavior.

## Why these techniques

The rules target techniques that are both currently prevalent and relevant to a
Linux server. Prevalence was informed by 2026 threat reporting (e.g. Picus Red
Report 2026, which found scripting interpreters and credential attacks among the
most common techniques). Techniques that are prevalent but do not fit a single
Linux web server — phishing (targets humans/email) and process injection
(largely a Windows-endpoint technique) — were deliberately left out rather than
forced in. Matching the detection to what the system actually is, is the point.

## The rules

### `ssh-bruteforce.yml` — SSH Brute Force (T1110)

**Technique:** [T1110 Brute Force](https://attack.mitre.org/techniques/T1110/),
tactic Credential Access.

**What it detects:** many failed SSH logins from a single source IP in a short
window. On Linux these appear in `/var/log/auth.log` as repeated
"Failed password" entries. The rule fires when one source IP exceeds 10 failures
in a minute.

**Why it's relevant here:** this instance exposes SSH to the internet
(`0.0.0.0/0`), so internet-facing brute force is a direct, constant threat — the
same exposure Checkov flags in the Terraform.

**Known limitations (blind spots):**
- **Distributed brute force** — an attacker spreading attempts across many IPs
  keeps each IP under the threshold, so the rule stays silent.
- **Low-and-slow** — staying under 10 attempts per minute evades the time
  window. (2026 reporting notes this "low and slow" shift is now dominant.)
- **Mitigation:** complementary rules that aggregate by targeted username across
  all IPs, or over a longer window, would cover these gaps.

### `suspicious-command.yml` — Download and Execute (T1059)

**Technique:** [T1059 Command and Scripting Interpreter](https://attack.mitre.org/techniques/T1059/),
tactic Execution.

**What it detects:** a command that downloads a remote script (`curl`/`wget`) and
pipes it straight into a shell (`| bash` / `| sh`) — a common one-line malware
delivery pattern. The rule requires **both** conditions, so downloading alone or
piping alone won't trigger it.

**Known limitations (blind spots):**
- **High false-positive rate** — legitimate software installers use
  `curl … | bash` (Docker, Rust, Homebrew all do). A real admin install would
  trip this rule.
- **Mitigation:** allowlist known-good domains (`get.docker.com`, etc.), or
  correlate with other signals (unusual user, off-hours, right after a
  brute-force spike). One weak signal becomes strong when correlated.

## How these run in production

In a real SOC, logs from every host ship to a central SIEM. A Sigma rule is
converted into that SIEM's query language and loaded as an always-on scheduled
search. A match raises an alert into a queue/dashboard for a Tier-1 analyst to
triage. The detection engineer's job is the lifecycle these files represent:
research a technique, write the detection, map it to ATT&CK, document its
limitations, and tune it to reduce false positives.

**Scope note:** these are validated detection *rules* — the real authoring
artifact. Running them against live logs in a SIEM at scale is a separate step
(a local Elastic/ELK stack is the planned next phase) and is what a production
environment provides.
