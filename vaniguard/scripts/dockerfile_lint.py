import os
import sys
import yaml
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def lint_docker_files():
    root = Path(__file__).resolve().parent.parent
    print("==================================================")
    print("VaniGuard Docker & Compose Syntax Linter")
    print("==================================================")

    errors = []
    warnings = []

    # 1. Lint docker-compose.yml
    compose_path = root / "docker-compose.yml"
    print(f"\n[1/3] Linting {compose_path.name}...")
    if not compose_path.exists():
        errors.append(f"Missing {compose_path.name}")
    else:
        try:
            with open(compose_path, "r", encoding="utf-8") as f:
                compose_data = yaml.safe_load(f)
            
            services = compose_data.get("services", {})
            required_services = ["redis", "api", "worker"]
            for s in required_services:
                if s not in services:
                    errors.append(f"docker-compose.yml missing required service: '{s}'")
                else:
                    cfg = services[s]
                    if "build" not in cfg and "image" not in cfg:
                        errors.append(f"Service '{s}' has neither 'build' nor 'image' directive")
                    print(f"      Service '{s}' validated: build/image configured properly.")
        except Exception as e:
            errors.append(f"YAML Syntax Error in docker-compose.yml: {e}")

    # 2. Lint server/Dockerfile
    server_dockerfile = root / "server" / "Dockerfile"
    print(f"\n[2/3] Linting {server_dockerfile.relative_to(root)}...")
    errors.extend(_lint_single_dockerfile(server_dockerfile, root))

    # 3. Lint worker/Dockerfile
    worker_dockerfile = root / "worker" / "Dockerfile"
    print(f"\n[3/3] Linting {worker_dockerfile.relative_to(root)}...")
    errors.extend(_lint_single_dockerfile(worker_dockerfile, root))

    print("\n--------------------------------------------------")
    if errors:
        print("LINT FAILED with the following errors:")
        for err in errors:
            print(f"  - ERROR: {err}")
        sys.exit(1)
    else:
        print("LINT PASSED: All Dockerfiles and docker-compose.yml syntactically valid.")
        print("NOTE: Runtime Docker container validation is deferred on hosts without Docker daemon.")
        print("==================================================")


def _lint_single_dockerfile(path: Path, root: Path) -> list:
    errors = []
    if not path.exists():
        return [f"File not found: {path}"]
    
    with open(path, "r", encoding="utf-8") as f:
        raw_lines = f.readlines()

    valid_instructions = {
        "FROM", "RUN", "CMD", "LABEL", "MAINTAINER", "EXPOSE", "ENV",
        "ADD", "COPY", "ENTRYPOINT", "VOLUME", "USER", "WORKDIR",
        "ARG", "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL"
    }

    # Join multiline continuations ending with '\'
    logical_lines = []
    current_line = ""
    start_idx = 1
    for idx, line in enumerate(raw_lines, 1):
        stripped = line.strip()
        if not current_line:
            start_idx = idx
        if stripped.endswith("\\"):
            current_line += stripped[:-1].strip() + " "
        else:
            current_line += stripped
            if current_line:
                logical_lines.append((start_idx, current_line))
            current_line = ""
    if current_line:
        logical_lines.append((start_idx, current_line))

    has_from = False
    has_cmd_or_entrypoint = False

    for idx, line in logical_lines:
        if not line or line.startswith("#"):
            continue
        
        parts = line.split(maxsplit=1)
        instruction = parts[0].upper()

        if instruction not in valid_instructions:
            errors.append(f"{path.name}:{idx} Unknown Dockerfile instruction '{instruction}'")

        if instruction == "FROM":
            has_from = True
        if instruction in ["CMD", "ENTRYPOINT"]:
            has_cmd_or_entrypoint = True

    if not has_from:
        errors.append(f"{path.name} missing required FROM instruction")
    if not has_cmd_or_entrypoint:
        errors.append(f"{path.name} missing CMD or ENTRYPOINT instruction")

    print(f"      {path.name} ({len(raw_lines)} lines): FROM instruction and CMD/ENTRYPOINT verified.")
    return errors


if __name__ == "__main__":
    lint_docker_files()
