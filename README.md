# DSS Application Template

A template repository for creating web applications deployed on the DSS (Data Stores Services) infrastructure. It provides a standardised starting point covering Docker packaging and the GitHub Actions image build.

**Deployment is managed by Argo CD, not by this repository.** An application repository only builds the container image and pushes it to Harbor. Every deployment setting (Helm values, chart version, image tag, hostnames, replicas) lives in the [dss-applications-argocd-configs](https://github.com/ecmwf/dss-applications-argocd-configs) repository, which Argo CD deploys from into the shared `dss-web-apps` namespace on the dev (dss-app-cci2) and prod (dss-app-cci1) clusters. See [Deployment with Argo CD](#deployment-with-argo-cd).

## Application Types

This template has been designed based on the following DSS applications:

| Type | Framework | Examples |
|------|-----------|---------|
| **Next.js** (server-side React) | Node 18 + Next.js + Mantine | [Climate Pulse](https://github.com/ecmwf/climate-pulse), [Global Temperature Trend Monitor](https://github.com/c3s-applications/global-temperature-trend-monitor) |
| **Vite** (static React) | Node 18 + Vite + Mantine | [Methane Explorer](https://github.com/c3s-applications/methane-explorer) |
| **Python Flask** (API server) | Python 3.11 + Flask + uWSGI | [UTCI Explorer Server](https://github.com/ecmwf/UTCI-explorer-server) |

---

## Project Structure

```
├── .github/
│   ├── AGENTS.md                   # CI/CD and template-update guidance
│   ├── ISSUE_TEMPLATE/
│   │   └── scientific-and-technical-code-review.md  # Template for scientific reviews
│   ├── options.env                 # Shared build and deploy defaults
│   ├── options-dev.env             # Dev-specific overrides
│   ├── options-prod.env            # Prod-specific overrides
│   └── workflows/
│       ├── build.yml               # Manual: build & push Docker image to Harbor
│       └── deploy.yml              # LEGACY: Helm deploy, only for apps not yet on Argo CD
├── deployment/                     # LEGACY: Helm values read only by deploy.yml
│   ├── AGENTS.md                   # Deployment and template-update guidance
│   ├── values.yaml                 # Helm chart base values (shared)
│   ├── values-dev.yaml             # Helm chart dev overrides
│   └── values-prod.yaml            # Helm chart prod overrides
├── src/
│   └── AGENTS.md                   # Application development guidance
├── Dockerfile                      # Starting point — fill in your build steps
├── AGENTS.md                       # AI agent guidance and scope routing
├── .gitignore
└── .dockerignore
```

### AI Agent Guidelines

Agent instructions are scoped by concern:

- `AGENTS.md` provides repository-wide context and routes tasks to the relevant instructions.
- `src/AGENTS.md` covers application development, including application files outside `src/` such as `app/`, `lib/`, and `tests/`.
- `.github/AGENTS.md` covers workflows, build options, and updating `.github/` from this template.
- `deployment/AGENTS.md` covers Helm values (the legacy `deployment/` files, and where the live values are kept) and reviewing deployment changes from this template.

---

## Quick Start

1. **Use this template** — click **"Use this template"** on GitHub to create your new repository.

2. **Replace all placeholder values:**
   - `YOUR_APP_NAME` — your application name in kebab-case (e.g. `climate-pulse`)
   - `YOUR_APP_HOSTNAME` — the production hostname (each app is served at the root of its own TLS hostname)

   Files to update: `deployment/values.yaml`, `deployment/values-dev.yaml`, `deployment/values-prod.yaml`. These are **legacy** files, read only by the legacy `deploy.yml`: skip this step for an application deployed by Argo CD, whose values are set in the configs repository (step 6).

3. **Build your Dockerfile.** The `Dockerfile` in this template is an intentional stub — fill it in to suit your application type. See [Dockerfile Examples](#dockerfile-examples) below.

4. **Configure GitHub secrets** — see [Required Secrets](#required-secrets).

5. **Trigger the first build** via the [Build & push to Harbor](#manual-build--push) workflow.

6. **Deploy it with Argo CD** — add the application to the Argo CD configs repository. See [Deployment with Argo CD](#deployment-with-argo-cd).

---

## Configuration

### Helm Values

> **The `deployment/` directory is legacy.** It is read only by the legacy `deploy.yml` workflow, for applications not yet migrated to Argo CD. For an application deployed by Argo CD, the Helm values live in the configs repository under `<app>/values/` (start from `climate-pulse/values/` there), and changing `deployment/` in the application repository deploys nothing; remove `deployment/` from the application repository once it is migrated. The conventions below apply to the values in either place.

The application is deployed using the [`single-pod-application`](https://github.com/ecmwf/dss-application-helm-chart) Helm chart. Configuration is split across a shared file and environment-specific overrides; each deployment merges the shared file with the selected environment file:

| File | Purpose |
|------|---------|
| `deployment/values.yaml` | Shared base values — app name, image repository, port |
| `deployment/values-dev.yaml` | Dev overrides — hostname, image tag, replica count |
| `deployment/values-prod.yaml` | Prod overrides — hostname, image tag, replica count |

Update `deployment/values.yaml` with your application name, then set the correct hostnames in the environment-specific files. TLS is enabled by the chart by default (certificate Secret `tls-<name>`). The chart ships no ingress annotations: the certificate issuer, DNS and proxy-tuning annotations depend on the target cluster, so set `ingress.annotations` per environment.

An application is served in one of two ways:

- **At the root of its own hostname** (the default, e.g. Climate Pulse): set `ingress.hostname`. On the clusters, `<app>.dss-app-cci2.compute.cci2.ecmwf.int` (dev) and `<app>.dss-app-cci1.compute.cci1.ecmwf.int` (prod) work for any app: external-dns creates the DNS record and cert-manager issues the certificate.
- **Under a path on the shared apps host** (e.g. Global Temperature Trend Monitor at `https://apps.dss-app-cci2.compute.cci2.ecmwf.int/global-temperature-trend-monitor/`): set `ingress.path` (chart >= 0.5.4), `ingress.tls: false` and the `nginx.org/mergeable-ingress-type: minion` annotation; the host's master Ingress holds TLS. The app must be built for that base path. See `apps-host/README.md` in the configs repository.

On the dev cluster every Ingress is behind HTTP basic auth, using the shared `dss-web-apps-htpasswd` Secret (the last two annotations in the example below). Non-secret environment variables go in `deployment.environment` (chart >= 0.5.6), rendered into a `<name>-env` ConfigMap.

Key `deployment/values.yaml` fields:

```yaml
name: YOUR_APP_NAME
deployment:
  image: eccr.ecmwf.int/c3s-applications/YOUR_APP_NAME
  # Port exposed by the container:
  #   80   — Nginx (Next.js via reverse proxy, or Vite static)
  #   3000 — Next.js direct (no Nginx)
  #   8000 — Python Flask/uWSGI
  port: 80
```

And per environment (e.g. the dev values of an application on Argo CD, `<app>/values/values-dev.yaml` in the configs repository):

```yaml
ingress:
  hostname: YOUR_APP_NAME.dss-app-cci2.compute.cci2.ecmwf.int
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
    ingress.kubernetes.io/ssl-redirect: "true"
    external-dns.alpha.kubernetes.io/ttl: "300"
    nginx.org/proxy-buffer-size: 128K
    nginx.org/proxy-buffers: 4 256K
    nginx.org/proxy-busy-buffers-size: 256K
    nginx.org/basic-auth-secret: dss-web-apps-htpasswd
    nginx.org/basic-auth-realm: "dss-web-apps (dev)"
```

### Build and Deploy Options

`.github/options.env` configures the image build (and the legacy Helm deploy). Environment-specific settings in `.github/options-dev.env` or `.github/options-prod.env` override the shared file. For an application deployed by Argo CD only the build options matter; the deploy options (`RELEASE_NAME` onwards) are read only by the legacy `deploy.yml`.

All variables have sensible defaults — only set what you need to override:

```bash
# Harbor project and image repository
# IMAGE_PROJECT=c3s-applications
# IMAGE_REPOSITORY=your-app-name

# --- Legacy deploy.yml only (ignored by Argo CD) ---

# Helm release name (defaults to the GitHub repository name)
# RELEASE_NAME=your-app-name

# Kubernetes namespace (defaults to cads-apps-<environment>)
# NAMESPACE=cads-apps-prod

# Helm chart and version
# HELM_CHART=oci://eccr.ecmwf.int/c3s-applications/single-pod-application
# HELM_CHART_VERSION=0.5.3

# Path to kubeconfig on the self-hosted runner (defaults to /home/cds/.kubeconfig)
# KUBECONFIG=/home/cds/.kubeconfig

# Comma-separated values files merged left to right (defaults to deployment/values.yaml,deployment/values-<env>.yaml)
# VALUES_FILE=deployment/values.yaml,deployment/values-dev.yaml

# Extra arguments for 'helm upgrade --install'
# HELM_EXTRA_ARGS=--timeout 5m0s
```

---

## GitHub Actions Workflows

### Manual: Build & Push

**File:** `.github/workflows/build.yml`

Builds the Docker image and pushes it to the ECMWF Harbor registry at `eccr.ecmwf.int`.

**Trigger:** Actions → **Build & push to Harbor** → Run workflow

| Input | Description | Default |
|-------|-------------|---------|
| `environment` | Passed as `--build-arg environment=<value>` to Docker | `dev` |
| `image_tag` | Tag applied to the pushed image; blank uses the commit SHA | `latest` |
| `options_directory` | Directory containing `options.env` and environment overrides | `.github/` |

The workflow loads `IMAGE_PROJECT` and `IMAGE_REPOSITORY` from the shared and environment-specific options files, then calls the [ecmwf/reusable-workflows](https://github.com/ecmwf/reusable-workflows) `build-and-push-image` workflow. The repository name is used when `IMAGE_REPOSITORY` is not overridden.

Building does not deploy anything. To roll out the new image, see [Releasing a new image](#releasing-a-new-image).

---

### Manual: Deploy (legacy)

**File:** `.github/workflows/deploy.yml`

> **Do not use this workflow for an application deployed by Argo CD.** Argo CD self-heals, so it reverts anything this workflow changes in the `dss-web-apps` namespace. It remains only for applications not yet migrated to Argo CD (the old `cads-apps-<environment>` namespaces), and will be removed once they all are.

Deploys a previously-built image to Kubernetes using Helm.

**Trigger:** Actions → **Deploy Single Pod Application Chart** → Run workflow

| Input | Description | Default |
|-------|-------------|---------|
| `deployment_environment` | `dev` or `prod` | `dev` |
| `options_directory` | Directory containing `options.env` and environment overrides | `.github/` |
| `clear_existing_pods` | Delete existing pods after a successful deploy | `false` |

The deploy workflow loads shared and environment-specific options, then reads `deployment/values.yaml` and `deployment/values-<environment>.yaml` for Helm values. It optionally applies `SECRET_VALUES_YAML` last for sensitive overrides (e.g. mounting SSH keys or API tokens).

---

## Required Secrets

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Required | Description |
|--------|----------|-------------|
| `HARBOR_USERNAME` | For builds | Username for the ECMWF Harbor registry |
| `HARBOR_PASSWORD` | For builds | Password for the ECMWF Harbor registry |
| `SECRET_VALUES_YAML` | Legacy `deploy.yml` only | Additional Helm values injected at deploy time (e.g. to mount Kubernetes secrets) |

With Argo CD, an application's credentials are Kubernetes Secrets applied by a cluster administrator from the `CHANGE_ME` templates in the configs repository, and mounted with the chart's `secrets` / `secretMounts` values. Never commit real credentials to either repository.

---

## Deployment with Argo CD

Argo CD deploys every DSS web application from the [dss-applications-argocd-configs](https://github.com/ecmwf/dss-applications-argocd-configs) repository's `main` branch, into the `dss-web-apps` namespace of the `dss-web-apps` Argo CD project. A push to `main` there is a deployment; reverting the commit is a rollback. The configs repository's README is the reference; in short:

### Adding an application

1. In the configs repository, create a directory for the app (copy `climate-pulse/`, which uses the shared chart from Harbor), with:
   - `values/values.yaml`, `values/values-dev.yaml`, `values/values-prod.yaml` — adapt the copied `climate-pulse/values/` (see [Helm Values](#helm-values) for the conventions);
   - one config file per environment, `<app>-app-deployment-<env>.yaml`, giving the Application's `name` and its `sources` (the chart version as `targetRevision`, and the values files);
   - a README with any setup steps an administrator must do first (e.g. Secrets).
2. Have an administrator put those prerequisites in place.
3. Add the path of the config file to the cluster's list at the root of the configs repository and push to `main`:

   ```yaml
   # dev-cluster-web-apps.yaml (dss-app-cci2), or prod-cluster-web-apps.yaml (dss-app-cci1)
   apps:
     - your-app-name/your-app-name-app-deployment-dev.yaml
   ```

   The `dss-web-apps` ApplicationSet creates the Application and deploys the app within a few minutes.

### Releasing a new image

- **Versioned tag (production):** build the image with a version tag (e.g. `1.2.0`), set `deployment.tag` to it in the configs repository's `values-prod.yaml`, and push.
- **`latest` (dev):** Argo CD does not redeploy when `latest` is re-pushed. After a build, restart the deployment, from the Argo CD UI (**Restart** on the Deployment) or with `kubectl -n dss-web-apps rollout restart deploy/<name>`.

Changing the chart version, hostnames, replicas or any other setting is likewise an edit to the app's files in the configs repository.

### Removing an application

Removal takes two steps, so that an application cannot be taken down by accident:

1. Remove its entry from the cluster's list (`dev-cluster-web-apps.yaml` / `prod-cluster-web-apps.yaml`) and push. Nothing is deleted: the ApplicationSet stops updating the Application, and the app keeps running.
2. Delete the Application in the cluster's Argo CD UI (**Delete**, then type the app's name). The default cascading delete also removes its resources.

### Managing the application

The team logs in to the cluster's Argo CD dashboard (e.g. `https://argocd.dss-app-cci2.compute.cci2.ecmwf.int` on dev) with the shared `dss-web-apps` account, which can view, sync, restart, view logs of and delete the applications in the project.

On prod, to be emailed when the application is unhealthy or fails to sync, add the annotation `notifications.argoproj.io/subscribe.email: alice@ecmwf.int;bob@ecmwf.int` to its Application. In the Argo CD UI this is under **Details** → **Summary** → **Edit** → **Annotations**. See the configs repository's README, "Notification emails".

---

## Dockerfile Examples

The `Dockerfile` in this template is intentionally minimal — it sets the base image and build arg, and leaves the rest for you to complete. Below are representative patterns from the existing DSS applications.

### Next.js (Node 18 + Nginx reverse proxy)

Used by [Climate Pulse](https://github.com/ecmwf/climate-pulse) and [Global Temperature Trend Monitor](https://github.com/c3s-applications/global-temperature-trend-monitor).

Multi-stage build: install deps → build → production (Nginx proxying to Next.js on port 3000).

```dockerfile
FROM node:18-alpine AS base
ARG environment=dev
WORKDIR /app
RUN corepack enable && corepack prepare yarn@4.8.1 --activate
COPY package.json yarn.lock ./
RUN yarn install
COPY app/ app/
COPY lib/ lib/
COPY styles/ styles/
COPY public/ public/
COPY environments/.env.${environment} .env
COPY next.config.mjs tsconfig.json theme.ts postcss.config.cjs ./

FROM base AS build
ARG APP_PATH=""
ENV APP_PATH=${APP_PATH}
RUN yarn build

FROM node:18-alpine AS production
WORKDIR /app
COPY package.json yarn.lock ./
RUN corepack enable && corepack prepare yarn@4.8.1 --activate && \
    yarn workspaces focus --production && \
    apk add --no-cache nginx && \
    rm -rf /var/cache/apk/* /root/.yarn
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/next.config.mjs ./
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 3000 80
CMD ["/entrypoint.sh"]
```

### Vite (static React + Nginx)

Used by [Methane Explorer](https://github.com/c3s-applications/methane-explorer).

Multi-stage build: install deps → build static assets → copy into Nginx image.

```dockerfile
FROM node:18 AS build
ARG environment=dev
WORKDIR /app
RUN corepack enable && corepack prepare yarn@4.5.0 --activate
COPY package.json yarn.lock ./
COPY src/ src/
COPY public/ public/
COPY index.html vite.config.ts ./
COPY environments/.env.${environment} .env
RUN yarn install && yarn build

FROM nginx:alpine AS production
COPY --from=build /app/dist /usr/share/nginx/html/
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf /etc/nginx/conf.d/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Python Flask / uWSGI

Used by [UTCI Explorer Server](https://github.com/ecmwf/UTCI-explorer-server).

Installs system dependencies, builds a Python package from `pyproject.toml`, and serves via uWSGI.

```dockerfile
FROM python:3.11-slim-bookworm AS production
WORKDIR /opt/python/
COPY . /opt/python/
RUN apt-get update && apt-get install -y build-essential && \
    pip install --upgrade pip && \
    pip install -r dev-requirements.txt && \
    python -m build && \
    python -m venv /opt/python/backend && \
    . /opt/python/backend/bin/activate && \
    pip install /opt/python/dist/*.tar.gz
USER nobody:nogroup
ENV UWSGI_HTTP_PORT=8000
EXPOSE 8000
CMD ["/opt/python/backend/bin/python", "-m", "backend"]
```

---

## Scientific & Technical Review

A GitHub Issue template is provided at `.github/ISSUE_TEMPLATE/scientific-and-technical-code-review.md` to guide peer review of calculations, data processing, reproducibility, and test coverage before publishing an application. Open one of these issues when preparing to go to production.

---

## Updating from the Template

Downstream repositories created from this template can pull in updates as the template evolves. The precedence rule is:

- **Template wins** for `.github/workflows/` and `.github/ISSUE_TEMPLATE/` — these files always replace the downstream versions.
- **Downstream wins** for everything else — your customisations (Dockerfile, Helm values, options files, application code, AGENTS.md, README, etc.) take precedence.

### Using an AI coding agent

If you have an AI coding agent (e.g. GitHub Copilot) configured in your downstream repo, you can ask it to perform the update for you. Scoped instructions are in `.github/AGENTS.md` and `deployment/AGENTS.md`. Simply prompt the agent:

> Update this repository from the dss-application-template.

The agent will add and fetch the template remote, restore template-owned files, and highlight downstream-owned changes for review.

### Manual procedure

1. **Add the template as a remote** (once per clone):

   ```bash
   git remote add template https://github.com/ecmwf/dss-application-template.git
   ```

2. **Fetch the latest template changes:**

   ```bash
   git fetch template main
   ```

3. **Create a branch for the update:**

   ```bash
   git checkout -b chore/update-template
   ```

4. **Restore template-owned files:**

   ```bash
   git checkout template/main -- .github/workflows/ .github/ISSUE_TEMPLATE/
   ```

5. **Review downstream-owned template changes.** Apply relevant changes manually while retaining application-specific configuration:

   ```bash
   git diff template/main -- .github/AGENTS.md .github/options.env .github/options-dev.env .github/options-prod.env AGENTS.md src/AGENTS.md Dockerfile deployment/ README.md
   ```

6. **Commit and open a PR:**

   ```bash
   git add .github/workflows/ .github/ISSUE_TEMPLATE/
   # Stage only other changes that you reviewed and adopted.
   git commit -m "chore: update from dss-application-template"
   ```

### What gets updated

| Path | Precedence | Notes |
|------|-----------|-------|
| `.github/workflows/*.yml` | **Template** | Always replaced wholesale |
| `.github/ISSUE_TEMPLATE/` | **Template** | Always replaced wholesale |
| `.github/AGENTS.md` | Downstream | Merge new CI/CD guidance manually |
| `.github/options*.env` | Downstream | Review template changes manually; adopt as needed |
| `AGENTS.md` | Downstream | Merge new repository-wide guidance manually |
| `src/AGENTS.md` | Downstream | Merge new application guidance manually |
| `Dockerfile` | Downstream | Template provides a stub; downstream has the real build |
| `deployment/` | Downstream | Legacy Helm values, read only by `deploy.yml`; remove once the app is on Argo CD. Follow `deployment/AGENTS.md` |
| Application code | Downstream | Not present in the template |
