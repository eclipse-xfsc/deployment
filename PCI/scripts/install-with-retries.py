#!/usr/bin/env python3
"""Run the PCI installer with bounded transport retries, without editing source."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import threading
import time
import urllib.parse


TRANSIENT = re.compile(
    r"curl: \((?:5|6|7|18|28|52|55|56|92)\)|"
    r"i/o timeout|connection timed out|connection timeout|"
    r"TLS handshake timeout|context deadline exceeded|Client.Timeout exceeded|"
    r"connection reset|connection refused|"
    r"temporary failure in name resolution|unexpected EOF|"
    r"server is currently unable to handle the request|"
    r"curl: \(22\).*\b(?:408|429|500|502|503|504)\b", re.I
)
PERMANENT = re.compile(
    r"Unauthorized|Forbidden|certificate verify failed|"
    r"curl: \((?:51|60|77)\)|curl: \(22\).*\b(?:400|401|403|404|409)\b", re.I
)


def can_retry(output, submitted=False, deadline=False):
    return not submitted and not PERMANENT.search(output) and bool(
        deadline or TRANSIENT.search(output)
    )


def captured(command, timeout):
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(command, 124, "", "Connection timeout: request deadline exceeded.\n")


def run_installer(command, env, source, log, timeout=300):
    submitted = False
    expired = threading.Event()
    lines = []
    with subprocess.Popen(command, cwd=source, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True,
                          start_new_session=True) as process:
        def terminate():
            expired.set()
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        timer = threading.Timer(timeout, terminate)
        timer.start()
        try:
            for line in process.stdout:
                print(line, end="", flush=True)
                log.write(line)
                log.flush()
                lines.append(line)
                # This marker precedes the deployment POST. Any later failure
                # requires inspection of the live revision, never a blind POST.
                if "deploying nodes:" in line:
                    submitted = True
            code = process.wait()
        except BaseException:
            terminate()
            process.wait()
            raise
        finally:
            timer.cancel()
    return code, "".join(lines), submitted, expired.is_set()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--gateway-ip")
    parser.add_argument("--api-ip", action="append", default=[])
    parser.add_argument("--attempts", type=int, default=5)
    args = parser.parse_args()
    if not 1 <= args.attempts <= 5:
        parser.error("--attempts must be between 1 and 5")
    for address in [value for value in [args.gateway_ip, *args.api_ip] if value]:
        if ipaddress.ip_address(address).version != 4:
            parser.error("this helper accepts IPv4 Gateway and API addresses")
    os.umask(0o077)
    source = args.source.resolve()
    version = (source / "VERSION").read_text().strip()
    if version not in {"0.5.0-rc.6", "0.5.0-rc.7", "0.5.0-rc.8", "0.5.0-rc.9", "0.5.0-rc.12"}:
        parser.error("this helper was reviewed against 0.5.0-rc.6, 0.5.0-rc.7, 0.5.0-rc.8, 0.5.0-rc.9 and 0.5.0-rc.12")
    config = json.loads(args.config.read_text())
    options = config["g0Args"]

    def option(name):
        if options.count(name) != 1:
            raise ValueError("Missing or duplicate configuration option: " + name)
        return options[options.index(name) + 1]

    editor = config["editorUrl"].rstrip("/")
    endpoint = urllib.parse.urlsplit(editor)
    if (endpoint.scheme != "https" or endpoint.hostname != option("--main-host")
            or endpoint.username or endpoint.password or endpoint.query or endpoint.fragment
            or endpoint.port not in (None, 443)):
        parser.error("editor URL must match the configured HTTPS provider host")
    notes = args.config.resolve().parent.parent / "deployment-test-notes"
    notes.mkdir(parents=True, exist_ok=True)
    record = notes / f"{version}-artifact-retry-record.json"
    state = {
        "sourceArtifactsModified": False, "status": "running",
        "attemptLimit": args.attempts, "backoffSeconds": [5, 10, 20, 30],
        "gatewayIp": args.gateway_ip, "apiIps": args.api_ip,
        "httpProtocol": "1.1", "tlsVerification": True,
        "retryPolicy": "Transport failures before deployment submission only",
        "upstreamFollowUp": [
            "Add bounded retries to safe installer preparation operations",
            "Add bounded request deadlines and sanitized phase diagnostics",
            "Inspect live revision after an ambiguous flow POST; never blindly replay it"
        ],
        "upstreamFiles": ["automation/stage1/install.sh", "scripts/lifecycle.py"],
        "attempts": [],
    }

    def save():
        temporary = record.with_suffix(".tmp")
        temporary.write_text(json.dumps(state, indent=2) + "\n")
        temporary.replace(record)

    save()
    env = os.environ.copy()
    env.update(config.get("environment", {}))
    env.pop("BASH_ENV", None)
    env.pop("ENV", None)
    with tempfile.TemporaryDirectory(prefix="pci-retry-") as directory:
        temporary = Path(directory)
        view = captured([
            "kubectl", "--kubeconfig", option("--kubeconfig"),
            "--context", option("--context"), "config", "view", "--raw",
            "--minify", "--flatten", "-o", "json"
        ], timeout=30)
        if view.returncode:
            state["status"] = "configuration-failed"
            save()
            raise SystemExit("Could not read the selected kubeconfig context.")
        original_kube = json.loads(view.stdout)
        api = urllib.parse.urlsplit(original_kube["clusters"][0]["cluster"]["server"])
        if api.scheme != "https" or not api.hostname:
            raise SystemExit("Kubernetes API must use HTTPS.")
        curl = temporary / "editor.curl"
        base_curl = (
            'http1.1\nnoproxy = "*"\n'
            + (f'resolve = "{endpoint.hostname}:443:{args.gateway_ip}"\n' if args.gateway_ip else '')
            +
            'connect-timeout = 15\nmax-time = 120\ntlsv1.3\ntls-max = "1.3"\n'
        )
        request = temporary / "auth.request"
        request.write_text(urllib.parse.urlencode({
            "client_id": "node-red-admin", "grant_type": "password", "scope": "*",
            "username": config.get("editorUsername", "admin"),
            "password": Path(config["editorPasswordFile"]).read_text().rstrip("\r\n")
        }))
        response = temporary / "auth.response"
        kube_file = temporary / "kubeconfig.json"
        exit_code = 1
        for attempt in range(1, args.attempts + 1):
            print(f"\nInstallation attempt {attempt}/{args.attempts}", flush=True)
            kube = json.loads(json.dumps(original_kube))
            cluster = kube["clusters"][0]["cluster"]
            if args.api_ip:
                address = args.api_ip[(attempt - 1) % len(args.api_ip)]
                cluster["server"] = urllib.parse.urlunsplit((
                    api.scheme, f"{address}:{api.port or 443}", api.path, api.query, ""
                ))
                cluster["tls-server-name"] = cluster.get("tls-server-name", api.hostname)
            kube_file.write_text(json.dumps(kube))
            env["KUBECONFIG"] = str(kube_file)
            curl.write_text(base_curl)
            env["PCI_ORCE_CURL_CONFIG"] = str(curl)
            ready = captured([
                "kubectl", "--kubeconfig", str(kube_file), "--context", option("--context"),
                "--request-timeout=15s", "get", "--raw=/readyz"
            ], timeout=25)
            submitted = deadline = False
            if ready.returncode:
                code, output = ready.returncode, ready.stderr
                print(output, end="", flush=True)
            else:
                auth = captured([
                    "curl", "-fsS", "--config", str(curl), "--max-time", "30",
                    "-H", "Content-Type: application/x-www-form-urlencoded",
                    "--data-binary", "@" + str(request), "-o", str(response),
                    editor + "/auth/token"
                ], timeout=40)
                if auth.returncode:
                    code, output = auth.returncode, auth.stderr
                    print(output, end="", flush=True)
                else:
                    try:
                        token = json.loads(response.read_text()).get("access_token")
                    except (ValueError, AttributeError):
                        token = None
                    if not isinstance(token, str) or not token or "\r" in token or "\n" in token:
                        state["status"] = "authentication-failed"
                        save()
                        raise SystemExit("Authentication returned no valid editor token.")
                    curl.write_text(base_curl + "header = " + json.dumps("Authorization: Bearer " + token) + "\n")
                    command = ["bash", "automation/stage1/install.sh",
                               "--kubeconfig", str(kube_file), "--context", option("--context"),
                               "--orce-namespace", option("--orce-namespace"),
                               "--orce-deployment", option("--orce-deployment"),
                               "--orce-container", option("--orce-container"), "--admin-url", editor]
                    with (notes / f"{version}-artifact-retry-{attempt}.log").open("w") as log:
                        code, output, submitted, deadline = run_installer(command, env, source, log)
            state["attempts"].append({"attempt": attempt, "exitCode": code,
                                      "deploymentMayHaveBeenSubmitted": submitted,
                                      "deadlineExceeded": deadline})
            save()
            if code == 0:
                state["status"] = "complete"
                save()
                print("Installation complete. Record:", record)
                return 0
            exit_code = code if 0 < code < 256 else 1
            if not can_retry(output, submitted, deadline):
                print("Stopped: inspect the failed phase before another deployment attempt.")
                break
            if attempt < args.attempts:
                delay = [5, 10, 20, 30][attempt - 1]
                print(f"Transient preparation failure; retrying in {delay} seconds.", flush=True)
                time.sleep(delay)
        state["status"] = "failed"
        save()
        return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
