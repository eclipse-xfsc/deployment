#!/usr/bin/env python3
# Copyright (c) 2026 LEANEA GmbH and others.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License, Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0.
#
# SPDX-License-Identifier: Apache-2.0
#
# Prepared with AI-assisted tools and reviewed by the author.
# Assisted-by: AI

"""Collect the private captures that scripts/privacy-audit.py scans (FR-PCI-48).

Run after a successful and a failed synthetic issuance that used the canary values
of `canaries`. Writes the captures and capture-manifest.json into a private
directory outside Git; never prints capture contents. Categories it cannot collect
from the cluster (NATS server state, trace backend, backups) are written to the
manifest only when their files are supplied with --extra CATEGORY=PATH; a category
without a capture makes the audit INCOMPLETE, as it must.

  python3 scripts/collect-privacy-captures.py canaries --out /private/canaries.txt
  python3 scripts/collect-privacy-captures.py collect --out /private/captures \\
      --orce-namespace xfsc-orce-pci-orce --orce-deployment xfsc-orce \\
      --ocm-namespace ocm-wstack --since 2h \\
      --extra traces=/private/jaeger-export.json --extra backups=/private/backup/data.tgz \\
      --extra nats=/private/nats-report.txt
  python3 scripts/privacy-audit.py --canary-file /private/canaries.txt \\
      --manifest /private/captures/capture-manifest.json
"""
import argparse
import json
import os
import secrets
import subprocess
import sys
from pathlib import Path

CATEGORIES = ['pci-logs', 'ocm-logs', 'database', 'nats', 'orce-context', 'traces', 'backups']


def kubectl(args, context=None):
    command = ['kubectl'] + (['--context', context] if context else []) + args
    return subprocess.run(command, check=True, capture_output=True).stdout


def private_dir(path):
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    os.chmod(path, 0o700)
    return path


def write(path, data):
    path.write_bytes(data)
    os.chmod(path, 0o600)
    return str(path)


def canaries(args):
    # Three synthetic values: a claim value, a journey input value and a subject-like value.
    values = ['PCI-CANARY-' + secrets.token_hex(12) for _ in range(3)]
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    write(out, ('\n'.join(values) + '\n').encode())
    print(json.dumps({'canaries': len(values), 'file': str(out),
                      'use': 'enter them as participant claim, journey input and display name of a synthetic principal'}))


def collect(args):
    out = private_dir(args.out)
    manifest = []
    ctx = args.context
    # PCI logs: the ORCE deployment, all containers.
    pods = json.loads(kubectl(['-n', args.orce_namespace, 'get', 'pods', '-o', 'json'], ctx))['items']
    pci = []
    for pod in pods:
        owner = pod['metadata'].get('labels', {})
        name = pod['metadata']['name']
        if not name.startswith(args.orce_deployment) and owner.get('app.kubernetes.io/part-of') != 'fap-pci':
            continue
        for container in pod['spec']['containers']:
            data = kubectl(['-n', args.orce_namespace, 'logs', name, '-c', container['name'], '--since', args.since], ctx)
            pci.append(write(out / f'pci-{name}-{container["name"]}.log', data))
    manifest.append({'category': 'pci-logs', 'paths': pci})
    # OCM logs: every pod of the OCM namespace.
    ocm = []
    for pod in json.loads(kubectl(['-n', args.ocm_namespace, 'get', 'pods', '-o', 'json'], ctx))['items']:
        name = pod['metadata']['name']
        for container in pod['spec']['containers']:
            try:
                data = kubectl(['-n', args.ocm_namespace, 'logs', name, '-c', container['name'], '--since', args.since], ctx)
            except subprocess.CalledProcessError:
                continue
            ocm.append(write(out / f'ocm-{name}-{container["name"]}.log', data))
    manifest.append({'category': 'ocm-logs', 'paths': ocm})
    # Database: a data-only dump of the PCI database, with the pod's own credentials.
    dump = kubectl(['-n', args.orce_namespace, 'exec', args.postgres_pod, '--', 'sh', '-c',
                    'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --data-only --no-owner'], ctx)
    manifest.append({'category': 'database', 'paths': [write(out / 'pci-database.sql', dump)]})
    # ORCE context: the file-backed context store and the flow file directory of /data.
    context = kubectl(['-n', args.orce_namespace, 'exec', f'deploy/{args.orce_deployment}', '--', 'sh', '-c',
                       'cd /data && tar -czf - context 2>/dev/null || true'], ctx)
    manifest.append({'category': 'orce-context', 'paths': [write(out / 'orce-context.tgz', context)] if context else []})
    supplied = {}
    for item in args.extra or []:
        category, _, path = item.partition('=')
        if category not in CATEGORIES or not path:
            raise SystemExit(f'--extra expects CATEGORY=PATH with CATEGORY in {", ".join(CATEGORIES)}')
        supplied.setdefault(category, []).append(path)
    for category in ['nats', 'traces', 'backups']:
        manifest.append({'category': category, 'paths': supplied.get(category, [])})
    manifest_path = out / 'capture-manifest.json'
    write(manifest_path, (json.dumps(manifest, indent=2) + '\n').encode())
    summary = {c['category']: len(c['paths']) for c in manifest}
    missing = [c for c, n in summary.items() if n == 0]
    print(json.dumps({'manifest': str(manifest_path), 'captures': summary, 'missing': missing,
                      'note': 'captures are private; the audit is INCOMPLETE for missing categories'}))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    c = sub.add_parser('canaries')
    c.add_argument('--out', required=True)
    k = sub.add_parser('collect')
    k.add_argument('--out', required=True)
    k.add_argument('--context')
    k.add_argument('--orce-namespace', default='xfsc-orce-pci-orce')
    k.add_argument('--orce-deployment', default='xfsc-orce')
    k.add_argument('--postgres-pod', default='fap-pci-postgres-0')
    k.add_argument('--ocm-namespace', required=True)
    k.add_argument('--since', default='2h')
    k.add_argument('--extra', action='append')
    args = parser.parse_args()
    if args.command == 'canaries':
        canaries(args)
    else:
        collect(args)
    return 0


if __name__ == '__main__':
    sys.exit(main())
