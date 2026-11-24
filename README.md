# ML-Dev-Workspace

**By: Jackson R. Tomski**

This repo runs all of my ML projects as one Docker environment so I can have a dev container open for each of them at the same time, switch between products without tearing anything down, and drive all of them from one UI. Every project still runs on its own from its own repo. This just ties them together.

Everything is driven by one file, `projects.json`. It lists each project, where its repo lives, its API, and how much CPU and memory it gets. A small generator turns that into the Docker Compose file, one VS Code dev container per project, and the calculator registry the UI reads. Adding a new project is a few lines in `projects.json` and one command.

---

## What's Inside

### Shared Services

Instead of every project spinning up its own copies, they share:

| Service | What it does | Port |
|---------|--------------|------|
| MLflow | One tracking server for every project, each logging to its own experiment | 5050 |
| PostgreSQL | Database for projects that need one (Production-Prediction-ML today) | 5433 |
| ML-Platform-UI | Landing page for every calculator, run one or several at once, jobs and results | 5173 |

MLflow history and Postgres data live in Docker volumes, so they survive restarts.

### Projects

| Project | Repo | API | CPU / Memory limit |
|---------|------|-----|--------------------|
| `ppml` | Production-Prediction-ML | 8100 | 4 / 8 GB |
| `petro` | 3D-Petrophysical-Prediction-ML | 8101 | 2 / 4 GB |
| `weather` | Weather-Forecasting-ML | 8102 | 2 / 4 GB |
| `pointcloud` | Point-Cloud-ML | 8103 | 2 / 4 GB |

Each project gets two containers built from that repo's own `Dockerfile`: the dev container I code in, and its API (`<name>-api`) that the UI talks to. Both mount the repo at `/workspace`, so edits and git commits go straight to the real repo, and the API picks up code changes on save. The limits are caps, not reservations, so idle containers don't hold onto resources.

### How the UI Finds Everything

```
Browser (localhost:5173)
    ↓
ML-Platform-UI: /api/<name>/... proxied using calculators.json
    ↓
<name>-api containers (health, schema, calculate, status, output)
    ↓
Shared MLflow
```

Every calculator API answers the same endpoints, so the UI builds each calculator's form from its `/schema` and shows it as online or offline based on `/health`. Whatever projects are running are the calculators the UI can use.

### Generator

`generate.py` reads `projects.json` and writes:

- `docker-compose.yml` with the shared services, the UI, and a dev container plus API service per project
- `.devcontainer/<project>/devcontainer.json` for each project, plus one for the UI
- `calculators.json`, the registry the UI uses to reach each API

It checks `projects.json` first (required fields, unique lowercase names) and reports every problem at once. It only uses the Python standard library, so it runs on the host with nothing to install.

### Multiple Dev Containers

Opening a project's dev container also starts its API, the shared MLflow and the UI. They're all set so closing one VS Code window doesn't stop the containers the other windows are using.

---

## Getting Started

**You need:** Docker Desktop, VS Code with the Dev Containers extension, and the repos cloned next to this one:

```
GitHubProjects/
├── ML-Dev-Workspace/
├── ML-Platform-UI/
├── Production-Prediction-ML/
├── 3D-Petrophysical-Prediction-ML/
├── Weather-Forecasting-ML/
└── Point-Cloud-ML/
```

```bash
git clone https://github.com/tomskija/ML-Dev-Workspace.git
cd ML-Dev-Workspace
make clone        # clones any project repos (and the UI) that are missing
```

**Open several projects at once in VS Code:**

1. Open the `ML-Dev-Workspace` folder and run **Dev Containers: Reopen in Container**. Pick a project (e.g. `Production-Prediction-ML (workspace)`).
2. **File > New Window**, then **Dev Containers: Open Folder in Container...** and choose `ML-Dev-Workspace` again. Pick a different project.
3. Repeat for as many projects as you want open.

Each window lands in that project's repo at `/workspace`. Open http://localhost:5173 and the projects you have open show up as online.

**From the terminal:**

```bash
make up                       # everything
make up P="petro weather"     # just these two, with their APIs and the UI
make ps                       # what's running
make shell P=weather          # bash inside a project
make test P=pointcloud        # run a project's pytest suite
make logs P=weather-api       # follow logs
make stop P=weather           # stop one project, leave the rest running
make down                     # stop everything, keep MLflow and Postgres data
```

| Service          | URL                         |
|------------------|-----------------------------|
| ML Platform UI   | http://localhost:5173       |
| MLflow UI        | http://localhost:5050       |
| PPML API         | http://localhost:8100/docs  |
| Petrophysical API | http://localhost:8101/docs |
| Weather API      | http://localhost:8102/docs  |
| Point Cloud API  | http://localhost:8103/docs  |
| PPML React UI    | http://localhost:3000 (after `npm run dev` in the ppml container) |
| PostgreSQL       | localhost:5433              |

The MLflow, Postgres and API ports are different from each project's standalone setup, so you can still run a project on its own without clashing.

If you plan on running all four at once, give Docker Desktop enough memory under **Settings > Resources**.

---

## Configuration

### Adding a Project

Add an entry to `projects.json`:

```json
{
  "name": "newproject",
  "label": "New-Project-ML",
  "repo": "New-Project-ML",
  "git": "git@github.com:tomskija/New-Project-ML.git",
  "package": "newProjectCalculator",
  "cpus": 2,
  "memory": "4g",
  "api": {
    "port": 8004,
    "host_port": 8104,
    "command": "uvicorn api:app --host 0.0.0.0 --port 8004 --reload"
  }
}
```

Then:

```bash
make clone
make generate
```

That's it. The new project shows up in `docker-compose.yml`, gets its own dev container, logs to the shared MLflow, and appears as a card in the UI. The repo needs a `Dockerfile` at its root that keeps the container running (`CMD ["sleep", "infinity"]`) and an `api.py` that follows the calculator contract (`/health`, `/schema`, `/calculate`, `/runs/{job_id}/status`, `/jobs/{job_id}/output`), which all of my project repos have.

### Project Options

| Field | What it does |
|-------|--------------|
| `name` | Short name used for the service, the dev container folder and `make ... P=` |
| `label` | Name shown in VS Code and the UI |
| `repo` | Folder name next to this repo |
| `git` | Clone URL, used by `make clone` |
| `package` | Python package folder, added to `PYTHONPATH` |
| `cpus`, `memory` | Resource limits for the container |
| `uses_postgres` | Wait for the shared Postgres before starting |
| `api` | `port` inside the container, `host_port` on your machine, and the `command` that starts it |
| `forward_ports` | Extra ports VS Code forwards (e.g. a frontend dev server) |
| `post_create` | Command run once when the dev container is first created |
| `env` | Extra environment variables |
| `set_pythonpath` | Set to `false` to leave `PYTHONPATH` alone |

Workspace-wide settings (MLflow and Postgres ports, Postgres credentials, the UI repo and port, where the project repos live) are under `workspace` at the top of `projects.json`.

Don't edit `docker-compose.yml`, `calculators.json` or the dev container files by hand. CI fails if they don't match `projects.json`.

---

## Project Structure

```
ML-Dev-Workspace/
├── .devcontainer/
│   ├── ppml/devcontainer.json          # Generated, one per project
│   ├── petro/devcontainer.json
│   ├── weather/devcontainer.json
│   ├── pointcloud/devcontainer.json
│   └── ui/devcontainer.json            # For working on the UI itself
├── .github/workflows/ci.yml            # Checks generated files match projects.json, validates compose
├── scripts/clone_projects.py           # Clones missing repos
├── projects.json                       # The one file you edit
├── generate.py                         # Builds compose, dev containers and calculators.json
├── docker-compose.yml                  # Generated
├── calculators.json                    # Generated, mounted into the UI
├── Dockerfile.mlflow                   # Shared MLflow server
└── Makefile                            # up, down, logs, shell, test, generate, clone
```

---

## Dependencies

Docker Desktop · VS Code Dev Containers · Python 3 (standard library only) · make

Each project's own dependencies live in its repo.
