# DSS Application Agent Guidelines

DSS applications are data-driven scientific web applications deployed on the Copernicus/ECMWF infrastructure. They come in three types: **Next.js** (server-side React), **Vite** (static React), and **Python Flask** (API server). All are containerised and their images built through GitHub Actions. They are deployed to Kubernetes by Argo CD, with the `single-pod-application` Helm chart, from the [dss-applications-argocd-configs](https://github.com/ecmwf/dss-applications-argocd-configs) repository: an application repository only builds the image, and changing deployment settings (values, chart version, image tag, hostnames) means changing that repository, not this one.

Guidelines are split by concern:

- [src/AGENTS.md](src/AGENTS.md) — application development: code style, architecture, build & test, and app-level conventions.
- [.github/AGENTS.md](.github/AGENTS.md) — CI/CD: build options, GitHub Actions workflows, and updating these aspects from the template.
- [deployment/AGENTS.md](deployment/AGENTS.md) — Helm values (the legacy `deployment/` files, read only by the legacy `deploy.yml`; the live values are in the Argo CD configs repository), deployment conventions, and updating deployment configuration from the template.

Before changing application code or its configuration, read `src/AGENTS.md`, including when the files are outside `src/` (for example `app/`, `lib/`, `tests/`, or root-level framework configuration). Before changing anything under `.github/`, read `.github/AGENTS.md`. Before changing Helm values under `deployment/`, read `deployment/AGENTS.md`.

Use the downstream repository's manifests, lockfiles, configuration, and existing code as the source of truth. Apply framework-specific guidance only when that framework or tool is present, preserve established project conventions, and run the narrowest relevant validation after editing.

See the README for the full project structure and deployment workflows.
