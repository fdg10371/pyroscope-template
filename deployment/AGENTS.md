# DSS Application Deployment Guidelines

**This directory is legacy.** It holds Helm values for the `single-pod-application` chart that are read only by the legacy `deploy.yml` workflow, for applications not yet migrated to Argo CD. That workflow merges `values.yaml` with the selected environment file (`values-dev.yaml` or `values-prod.yaml`) from left to right.

Applications are deployed by Argo CD from the [dss-applications-argocd-configs](https://github.com/ecmwf/dss-applications-argocd-configs) repository, which holds their values under `<app>/values/`, the chart version in `<app>/<app>-app-deployment-<env>.yaml`, and the per-cluster lists of deployed apps (`dev-cluster-web-apps.yaml`, `prod-cluster-web-apps.yaml`). A new application's values start from `climate-pulse/values/` in that repository, not from this directory. For an application on Argo CD, editing these files deploys nothing and the directory should be removed. When asked to change a deployment setting of such an application, make the change in the configs repository (or say that it belongs there), not here.

The conventions below apply to the values in either place.

## Editing values

- Put settings shared by all environments in `values.yaml`.
- Put only environment-specific overrides in `values-<environment>.yaml`.
- By default an application is served at the root of its own TLS hostname (`ingress.hostname`, set per environment). Alternatively it can be served under a path on the shared apps host (`apps.dss-app-cci?.compute.cci?.ecmwf.int`): set `ingress.path` (`single-pod-application` >= 0.5.4), `ingress.tls: false` and the `nginx.org/mergeable-ingress-type: minion` annotation, and build the app for that base path; see `apps-host/README.md` in the configs repository. `ingress.stripPathPrefix` no longer exists: remove it when updating older downstream repositories (the `nginx.org/rewrites` annotation strips a prefix when needed).
- TLS is enabled by the chart by default, serving the certificate from the Secret `tls-<name>` (override with `ingress.tlsSecretName`). The chart ships no ingress annotations (since `single-pod-application` 0.5.1): the certificate issuer, DNS and proxy-tuning annotations depend on the target cluster, so set `ingress.annotations` in each `values-<environment>.yaml`.
- With several hostnames (`ingress.hostnames`), one certificate covers them all by default, so every name must validate before it issues. When hostnames need independent certificates (e.g. during a cluster migration where one name still points at the old cluster), set `ingress.tlsEntries` (since `single-pod-application` 0.5.3); see the chart's `values.yaml` for the format.
- Keep the image repository and container port consistent with the Docker image and `.github/options*.env` configuration.
- On the dev cluster every Ingress uses HTTP basic auth with the shared `dss-web-apps-htpasswd` Secret (`nginx.org/basic-auth-secret` and `nginx.org/basic-auth-realm` annotations).
- Non-secret environment variables go in `deployment.environment` (`single-pod-application` >= 0.5.6), rendered into a `<name>-env` ConfigMap.
- Do not put secrets in these files. Credentials are Kubernetes Secrets applied by a cluster administrator (from `CHANGE_ME` templates in the configs repository) and mounted with the chart's `secrets` / `secretMounts` values. (`SECRET_VALUES_YAML` serves only the legacy `deploy.yml`.)
- Validate changed files with the repository's configured YAML or Helm tooling when available.

Container port conventions are:

- `80` — Nginx (Next.js reverse proxy or Vite static)
- `3000` — Next.js direct
- `8000` — Python Flask/uWSGI

## Updating from the application template

The files in `deployment/` are application-specific, so downstream values take precedence. Do not overwrite them wholesale when updating from the template.

1. Add and fetch the template remote if needed:

   ```bash
   git remote add template https://github.com/ecmwf/dss-application-template.git
   git fetch template main
   ```

2. Compare the downstream deployment files with the template:

   ```bash
   git diff template/main -- deployment/
   ```

3. Review template changes and apply relevant structural or documentation updates manually while retaining application names, image repositories, hostnames, tags, replica counts, and other downstream settings.

4. Stage only the reviewed deployment changes:

   ```bash
   git add deployment/
   ```