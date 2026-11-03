# DSS Application Development Guidelines

DSS applications are data-driven scientific web applications deployed on the Copernicus/ECMWF infrastructure. They come in three types: **Next.js** (server-side React), **Vite** (static React), and **Python Flask** (API server).

This file covers application development (code style, architecture, build and test, and app-level conventions). The root `AGENTS.md` directs agents to use these instructions for application files outside `src/` as well. For CI/CD, see `.github/AGENTS.md`; for Helm values, see `deployment/AGENTS.md`.

Inspect the downstream project's manifests, lockfiles, configuration, and nearby code before editing. Follow the sections for the detected application type; do not introduce a framework, library, package manager, or directory layout solely because it is described here.

## Code Style

### TypeScript (all frontend apps)

- Preserve strict mode when enabled. Do not introduce `any` unless bridging a third-party library with no usable types.
- Match the existing `tsconfig.json`; do not change module resolution or unused-code checks without a task-specific reason.
- Match the existing export style. Next.js page and layout files may require default exports.

### Python (Flask/uWSGI apps)

- Use the Python version declared by the project; new applications should target Python 3.11 or later.
- Use the configured formatter and import sorter. When the project uses Black and isort, keep Black's line length and isort's Black profile unless configuration says otherwise.
- Preserve the existing package and entry-point layout. A typical Flask/uWSGI application uses `src/<package_name>/` with `__main__.py`.
- Add dependencies through the mechanism already used by `pyproject.toml` or requirements files.

## Architecture

### Frontend app structure

Common locations are shown below. Only use the locations relevant to the detected framework and existing project:

```
app/            # Next.js app router (pages, layouts, components, hooks, contexts, redux)
src/            # Vite source (components, hooks, redux, utils)
lib/            # Framework-agnostic utilities (e.g. getBasePath.ts)
types/          # Shared TypeScript type declarations
styles/         # Global CSS
public/         # Static assets served at /
environments/   # Build-time env files (.env.dev, .env.prod, .env.public)
nginx/          # nginx.conf (Next.js reverse proxy or Vite static serving)
```

### UI library

When the application uses **Mantine** (`@mantine/core`, `@mantine/hooks`), preserve its existing theme and provider setup. DSS applications commonly use a shared `theme.ts` with:
- Brand colour swatch is named `"brand-primary"` — the primary colour is `#941333` (dark red).
- Font family: `Lato, Open Sans, sans-serif`.
- `"use client"` at the top when required by its Next.js import boundary.
- `<MantineProvider theme={theme} forceColorScheme="light">` when the application supports only light mode.
- `<ColorSchemeScript />` in the Next.js `<head>` when required by the installed Mantine version.

### State management (React apps)

When the application already uses **Redux Toolkit**, keep one `createSlice` per domain area (e.g. `uiSlice`, `dataSlice`):
- Define a typed interface for slice state.
- Use `PayloadAction<T>` for reducer action types.
- Export `RootState` and `AppDispatch` from `store.ts`.

### Next.js layout metadata

When editing a Next.js `app/layout.tsx`, preserve and update the application's metadata and structured data. Existing DSS applications commonly include:
- `title`, `description`, `keywords`, `authors`, `creator`, `publisher`
- `openGraph` and `twitter` card objects (use `/thumbnail.png` as the OG image)
- `robots` with `googleBot` settings
- A JSON-LD `<script type="application/ld+json">` block typed as `@type: "WebApplication"` with author/provider pointing to C3S and publisher pointing to ECMWF.

### Python server structure

Preserve the downstream application's layout. A typical separation is:

```
src/backend/
    __init__.py     # exposes __version__
    __main__.py     # uWSGI entry point
    server.py       # Flask app and route definitions
    config.py       # Environment/configuration loading
    params.py       # Request parameter validation
    aggregation.py  # Science/data logic (keep separate from Flask routing)
    utils.py
tests/
    test_server.py
```

Keep data/science logic in dedicated modules (`aggregation.py`, etc.) separate from Flask route handlers in `server.py`.

## Build and Test

### Frontend (Node.js)

Use the package manager selected by the lockfile and the scripts declared in `package.json`. Typical script names are `dev`, `build`, `lint`, and `test`. Do not replace the package manager or regenerate an unrelated lockfile. Never commit `node_modules` or package-manager caches.

### Python

Use the environment and commands declared by `pyproject.toml`, requirements files, and the existing test configuration. Run the narrowest relevant test first, then the configured formatter, linter, and broader tests when warranted.

### Docker (local)

```bash
docker build --platform linux/amd64 -t my-app:local --build-arg environment=dev .
docker run --rm -p 80:80 my-app:local
```

Always use `--platform linux/amd64` on Apple Silicon to match the deployment target.

## Conventions

### Application runtime env files

Some frontend apps keep build-time runtime environment variables in an `environments/` folder (these live in downstream app code, not in this template):

| File | Purpose |
|------|---------|
| `environments/.env.dev` | Docker build-time env for dev (`PUBLIC_URL`, etc.) |
| `environments/.env.prod` | Docker build-time env for prod |
| `environments/.env.public` | Shared/public env values |

When this layout is present, the Dockerfile selects the file with `ARG environment=dev` and copies `environments/.env.${environment}` to `.env`. Do not add or rename environment files unless the application build expects them.

### APP_PATH and base paths

Most deployments serve an application at the root of its own TLS hostname, so new applications should build for root deployment (empty `APP_PATH`/`basePath`) unless they are to be served under a path on the shared apps host. In that case the app must be built for that base path (e.g. Global Temperature Trend Monitor sets `basePath: "/global-temperature-trend-monitor"` in `next.config.mjs`); the deployment side (`ingress.path`) is configured in the Argo CD configs repository. When an existing application still defines an `APP_PATH` build argument, keep it working but leave it empty by default, and in Next.js applications that map it to `basePath`, use the existing base-path helper for asset URLs instead of hard-coded deployment paths.

### Scientific review

Before merging significant science/data logic, open an issue using the `.github/ISSUE_TEMPLATE/scientific-and-technical-code-review.md` template to track a peer review of calculations, data handling, and test coverage.
