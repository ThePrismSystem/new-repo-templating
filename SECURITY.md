# Security Policy

## Reporting a vulnerability

Report suspected vulnerabilities through GitHub's private vulnerability
reporting: open the **Security** tab of this repository and choose **Report a
vulnerability**. Reports stay private until a fix is published.

Do not open a public issue. Issues are disabled on this repository.

## Scope

In scope:

- `setup.sh` and `verify.sh`: argument handling, placeholder substitution, and
  anything that could run untrusted input during scaffolding
- `apply-settings.sh` and `lib/`: anything that could apply weaker settings or
  rulesets than the manifest asks for, or report success when a change failed
- The check scripts under `templates/**/scripts/`, which run in every generated
  project's CI and on its developers' machines
- The workflow files under `.github/workflows/` and `templates/**/.github/workflows/`
- Template configuration that would make a generated project ship an insecure
  default

Out of scope:

- Vulnerabilities in the third-party dependencies that generated projects
  install. Report those upstream.
- Findings that require write access to this repository to exploit.

## Supported versions

Only the current `main` branch is supported. There are no releases.
