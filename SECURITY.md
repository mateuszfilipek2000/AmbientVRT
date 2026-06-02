# Security Policy

## Supported versions

AmbientVRT is pre-1.0 software under active development. Security fixes are
applied to the latest release only. There is no long-term support commitment
for older versions.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Instead, report privately via GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository (Security → Report a vulnerability), or email the maintainer
at mateuszfilipek2000@gmail.com.

When reporting, please include:

- a description of the issue and its impact,
- steps to reproduce or a proof of concept,
- affected version(s) and environment.

This is a volunteer-maintained open-source project. Reports are handled on a
best-effort basis; there is no guaranteed response time or service-level
agreement.

## Handling credentials

AmbientVRT never reads storage credentials from configuration files. The
S3-compatible backend reads its access key and secret key only from the
environment variables named in `ambient.config.yaml` (by default
`AMBIENT_S3_ACCESS_KEY` and `AMBIENT_S3_SECRET_KEY`). Keep those secrets out of
committed config and out of CI logs.

## Disclaimer of warranty and liability

AmbientVRT is provided **"as is", without warranty of any kind**, express or
implied, including but not limited to the warranties of merchantability,
fitness for a particular purpose, and non-infringement. In no event shall the
authors, copyright holders, or contributors be liable for any claim, damages,
or other liability — whether in an action of contract, tort, or otherwise —
arising from, out of, or in connection with the software or the use of or other
dealings in the software.

This software is licensed under the [Apache License 2.0](LICENSE); sections 7
("Disclaimer of Warranty") and 8 ("Limitation of Liability") of that license
govern and take precedence. You use AmbientVRT entirely at your own risk.
