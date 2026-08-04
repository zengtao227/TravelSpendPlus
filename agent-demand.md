# Agent Demand Gate: GitHub-to-GitLab Release Automation

## 1. Friction Point
- Current user friction: Publishing from the GitHub source of truth to a GitLab mirror would otherwise require a second manual push and a separate verification step for every release.
- Who experiences it: The project maintainer preparing releases for F-Droid.
- Why fixed rules or normal automation are insufficient: They are sufficient; no adaptive Agent behavior is required.
- Evidence source: The requested release workflow requires GitHub to remain the only development repository while GitLab receives synchronized branches and tags.

## 2. Quantified Gap
- Baseline metric: Without automation, each release requires at least one additional manual GitLab synchronization and verification cycle.
- Target metric: One push to GitHub automatically synchronizes the `main` branch or pushed tag, with zero routine manual pushes to GitLab after initial secret configuration.
- Failure or exit point: The mirror is not ready for release if the GitLab commit or tag does not match GitHub after a successful workflow run.
- Acceptable error / misclassification rate: No branch or tag may be reported as synchronized when commit IDs differ.
- Measurement window: Every push to `main` and every tag push used for a release.

## 3. Solution Choice
- Recommended path: non-agent-automation
- Why this path fits current data and change frequency: Git ref synchronization is deterministic and GitHub Actions provides an auditable, repository-owned trigger.
- Why the rejected paths are weaker: Agent or prompt-based approaches add nondeterminism; a GitLab pull mirror may require a paid tier and moves operational control away from the GitHub source repository.
- Smallest useful prototype: A single GitHub Actions workflow that pushes `main` and tags to a GitLab repository using scoped secrets.

## 4. Success Preview And Risk Plan
- Success standard: A GitHub push produces a successful workflow run and the corresponding GitLab branch or tag resolves to the same commit. F-Droid publication remains a separate source-build process controlled by F-Droid metadata and infrastructure.
- Pause / kill signal: Disable the workflow if it overwrites unexpected GitLab-only refs, credentials are exposed, or repeated synchronization failures occur.
- Degraded fallback: Perform an explicit one-time push from a clean local clone after comparing both remotes; do not develop on GitLab.
- Owner and review cadence: The maintainer reviews each release sync and rotates the GitLab token according to the project's credential policy.
