"""CAS journal for helper-owned Deployment fields; never records secret values."""
import copy
import json
import subprocess
ANNOTATION = 'fap-pci.xfsc.org/helper-runtime'

def plan(deployment, container_name, env=None, mounts=None, volumes=None):
    updated = copy.deepcopy(deployment)
    spec = updated['spec']; pod = spec['template']['spec']
    container = next(c for c in pod['containers'] if c['name'] == container_name)
    annotations = spec['template'].setdefault('metadata', {}).setdefault('annotations', {})
    journal = json.loads(annotations.get(ANNOTATION, '{"version":1,"containers":{},"volumes":{}}'))
    if journal.get('version') != 1: raise ValueError('Unsupported helper ownership journal')
    state = journal['containers'].setdefault(container_name, {'env':{}, 'volumeMounts':{}})
    def merge(target, field, entries, records):
        values = target.setdefault(field, [])
        for entry in entries or []:
            name = entry['name']; old = next((v for v in values if v['name'] == name), None)
            record = records.get(name)
            if record and old != record['applied']: raise ValueError('PCI-HELPER-FIELD-CONFLICT: '+name)
            if not record: record = {'before':copy.deepcopy(old)}; records[name] = record
            record['applied'] = copy.deepcopy(entry)
            values[:] = [v for v in values if v['name'] != name] + [copy.deepcopy(entry)]
    merge(container, 'env', env, state['env'])
    merge(container, 'volumeMounts', mounts, state['volumeMounts'])
    merge(pod, 'volumes', volumes, journal['volumes'])
    annotations[ANNOTATION] = json.dumps(journal, sort_keys=True, separators=(',', ':'))
    if len(annotations[ANNOTATION]) > 200000: raise ValueError('Helper ownership journal too large')
    return [{'op':'test','path':'/metadata/uid','value':deployment['metadata']['uid']},
            {'op':'test','path':'/metadata/resourceVersion','value':deployment['metadata']['resourceVersion']},
            {'op':'replace','path':'/spec','value':spec}]

def apply(kubectl, deployment, container, **changes):
    patch = plan(deployment, container, **changes)
    subprocess.run(kubectl+['patch','deployment',deployment['metadata']['name'],'--type=json','--patch',json.dumps(patch)],check=True,stdout=subprocess.DEVNULL)
