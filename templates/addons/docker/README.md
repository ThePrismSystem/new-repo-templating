# docker

A container image built from a `Dockerfile` at the repo root, linted with
hadolint and scanned with Trivy. Combines with any other addon, usually the
one for the language the image runs.

## What it adds

- A starter `Dockerfile` that serves `site/` with BusyBox httpd. Whatever
  replaces it keeps the rules the starter follows: a base image pinned by
  digest, a non-root `USER` and a `HEALTHCHECK`
- `.dockerignore` keeping `.git`, `.env` files, dependency folders and
  coverage out of the build context
- hadolint at warning level over every Dockerfile git doesn't ignore
- Trivy's misconfiguration scan over the repo
- Trivy's image scan of the built image, failing on HIGH or CRITICAL
  vulnerabilities that have a fix, with the findings uploaded to code
  scanning as SARIF on public repos
- Renovate pinning base images by digest, so a tag update moves the digest
  with it

CI installs hadolint and Trivy from their release downloads, checked by
SHA-256. There's no coverage upload and no CodeQL language for Docker.

## Checks

`scripts/check-docker.sh <step>` runs each check. CI runs one step per job,
and every job is a required check.

| Step | CI job | Runs |
|---|---|---|
| `lint` | `docker-lint` | hadolint, `trivy config` |
| `scan` | `docker-scan` | `docker build`, then `trivy image` |

## In the generated project

```sh
docker build --tag demo .
docker run --rm -p 8080:8080 demo
```

`scripts/check-docker.sh scan` tags the image as `check-docker:local`; set
`IMAGE` to use another tag.
