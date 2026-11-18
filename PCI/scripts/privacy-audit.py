#!/usr/bin/env python3
# Copyright (c) 2026 LEANEA GmbH and others.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License, Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0.
#
# SPDX-License-Identifier: Apache-2.0

"""Scan private, operator-collected evidence without printing its contents."""
import argparse,base64,hashlib,json,os,sys
from pathlib import Path
REQUIRED={'pci-logs','ocm-logs','database','nats','orce-context','traces','backups'}

def scan(canaries,manifest):
    if not canaries or any(len(c)<16 or len(c)>512 for c in canaries):raise ValueError('Use synthetic canaries between 16 and 512 bytes')
    needles=set(canaries)
    for value in canaries:needles.update([base64.b64encode(value),base64.urlsafe_b64encode(value).rstrip(b'='),json.dumps(value.decode(),ensure_ascii=True)[1:-1].encode()])
    overlap=max(map(len,needles))-1;results=[];covered=set()
    for entry in manifest:
        category=entry['category'];paths=entry.get('paths',[])
        if category not in REQUIRED or not isinstance(paths,list):raise ValueError('Invalid capture category')
        present=0
        for name in paths:
            path=Path(name)
            if not path.is_file() or path.is_symlink():results.append({'category':category,'capture':path.name,'status':'MISSING'});continue
            digest=hashlib.sha256();found=False;tail=b''
            with path.open('rb') as stream:
                while chunk:=stream.read(65536):
                    digest.update(chunk);data=tail+chunk;found=found or any(needle in data for needle in needles);tail=data[-overlap:]
            results.append({'category':category,'capture':path.name,'sha256':digest.hexdigest(),'status':'FOUND' if found else 'NO_MATCH'});present+=1
        if present and present==len(paths):covered.add(category)
    missing=sorted(REQUIRED-covered)
    return {'scope':'submitted-captures-only','status':'FAIL' if any(x['status']=='FOUND' for x in results) else 'INCOMPLETE' if missing or any(x['status']=='MISSING' for x in results) else 'NO_CANARY_MATCH','missingCategories':missing,'captures':results,'limitations':['Does not decode encrypted/compressed captures. Export searchable plaintext privately.','No-match is evidence for these captures and canaries, not GDPR certification.']}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--canary-file',required=True);parser.add_argument('--manifest',required=True);args=parser.parse_args()
    try:
        values=[x for x in Path(args.canary_file).read_bytes().splitlines() if x];result=scan(values,json.loads(Path(args.manifest).read_text()));print(json.dumps(result,indent=2));return 0 if result['status']=='NO_CANARY_MATCH' else 1
    except Exception:print(json.dumps({'status':'INCOMPLETE','code':'PCI-PRIVACY-CAPTURE-INVALID'}));return 2
if __name__=='__main__':sys.exit(main())
