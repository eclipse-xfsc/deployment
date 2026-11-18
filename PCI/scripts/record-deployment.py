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

"""Record what is running in a PCI installation (FR-PCI-75, 86, 89, 93).

Binds the running deployment to an immutable source: the release candidate tag and
its commit, the image references and the digests the pods actually run, the Helm
releases and the version reported by /healthz. Reads only; prints JSON to stdout
or writes it with --out. Contains no Secret values.

  python3 scripts/record-deployment.py --environment IONOS --tag v0.5.0-rc.16 \\
      --base-url https://pci.example.com --out docs/release/deployments/ionos-v0.5.0-rc.16.json
"""
import argparse
import datetime
import json
import subprocess
import sys
import urllib.request


def run(command):
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout


def kubectl_json(args, context):
    return json.loads(run(['kubectl'] + (['--context', context] if context else []) + args + ['-o', 'json']))


def workload_images(namespace, context):
    records = []
    for pod in kubectl_json(['-n', namespace, 'get', 'pods'], context)['items']:
        spec = {c['name']: c['image'] for c in pod['spec']['containers']}
        for status in pod.get('status', {}).get('containerStatuses', []):
            records.append({
                'pod': pod['metadata']['name'],
                'container': status['name'],
                'image': spec.get(status['name']),
                'imageID': status.get('imageID', '').replace('docker-pullable://', ''),
                'ready': status.get('ready', False),
                'restarts': status.get('restartCount', 0)
            })
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--environment', required=True, choices=['IONOS', 'OSC'])
    parser.add_argument('--tag', required=True, help='release candidate tag, e.g. v0.5.0-rc.16')
    parser.add_argument('--base-url', required=True, help='provider base URL without /ui/')
    parser.add_argument('--context')
    parser.add_argument('--orce-namespace', default='xfsc-orce-pci-orce')
    parser.add_argument('--participant-namespace', default='xfsc-orce-pci-source')
    parser.add_argument('--out')
    args = parser.parse_args()
    commit = run(['git', 'rev-list', '-n', '1', args.tag]).strip()
    try:
        with urllib.request.urlopen(args.base_url.rstrip('/') + '/healthz', timeout=10) as response:
            health = json.loads(response.read())
    except Exception as error:  # recorded, not hidden
        health = {'error': type(error).__name__}
    helm = {}
    for namespace in [args.orce_namespace, args.participant_namespace]:
        try:
            helm[namespace] = json.loads(run(['helm'] + (['--kube-context', args.context] if args.context else []) +
                                            ['-n', namespace, 'list', '-o', 'json']))
        except Exception as error:
            helm[namespace] = {'error': type(error).__name__}
    record = {
        'recordType': 'pci-deployment-record',
        'recordedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
        'environment': args.environment,
        'tag': args.tag,
        'commit': commit,
        'reportedVersion': health.get('version'),
        'health': {k: health.get(k) for k in ['status', 'service', 'version', 'orceBasePath'] if k in health} or health,
        'workloads': {ns: workload_images(ns, args.context) for ns in [args.orce_namespace, args.participant_namespace]},
        'helmReleases': helm,
        'consistency': None
    }
    expected = args.tag.lstrip('v')
    record['consistency'] = {
        'versionMatchesTag': record['reportedVersion'] == expected,
        'everyContainerHasDigest': all('@sha256:' in w['imageID'] for ns in record['workloads'].values() for w in ns),
        'everyContainerReady': all(w['ready'] for ns in record['workloads'].values() for w in ns)
    }
    text = json.dumps(record, indent=2) + '\n'
    if args.out:
        with open(args.out, 'w') as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)
    return 0 if all(record['consistency'].values()) else 1


if __name__ == '__main__':
    sys.exit(main())
