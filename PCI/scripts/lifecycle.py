#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Non-interactive deploy/upgrade/uninstall runner for the ORCE automation flow."""
import argparse,fcntl,json,os,re,signal,ssl,subprocess,sys,tempfile,time,uuid
import urllib.request,urllib.parse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class LifecycleError(Exception):
    def __init__(self,code,step,exit_code=None):self.code,self.step,self.exit_code=code,step,exit_code

def problem(error):
    step=getattr(error,'step','validation')
    guidance={
        'validation':('The release configuration is incomplete or inconsistent.','Check the explicit kubeconfig, context, dedicated namespace, editor HTTPS URL and private credential file.'),
        'context':('The selected Kubernetes context could not be read.','Check that the kubeconfig file exists and includes the exact configured context.'),
        'prerequisites':('Ground-zero or telemetry preparation failed.','Run scripts/preflight.sh for this context; check the failed workload events and dependency readiness before retrying.'),
        'editor_auth':('ORCE editor authentication failed.','Check the editor URL and its TLS certificate, username and password file. Use the ORCE editor account.'),
        'artifacts':('The flow or UI installation failed.','Check editor reachability, flow revision conflicts and the target data volume. Retry with the same release and configuration.'),
        'uninstall':('Uninstall stopped before confirming completion.','Check tenant deletion, artifact ownership and runtime identity. Preserve the existing data and retry after resolving the reported phase.'),
    }
    detail,next_step=guidance.get(step,guidance['validation'])
    return {'code':getattr(error,'code','PCI-AUTOMATION-FAILED'),'step':step,'detail':detail,'nextStep':next_step,**({'exitCode':error.exit_code} if getattr(error,'exit_code',None) is not None else {})}

def configuration(path):
    value=json.loads(Path(path).read_text())
    if not isinstance(value,dict) or set(value)-{'g0Args','editorUrl','editorUsername','editorPasswordFile','providerCurlConfig','environment','allowUninstall','legacyBaselineFile'}:raise LifecycleError('PCI-AUTOMATION-CONFIG','validation')
    args=value.get('g0Args')
    if not isinstance(args,list) or not args or not all(isinstance(x,str) and '\x00' not in x for x in args):raise LifecycleError('PCI-AUTOMATION-ARGS','validation')
    required=['--kubeconfig','--context','--orce-namespace','--orce-deployment','--orce-container','--main-host']
    options={}
    for key in required:
        if args.count(key)!=1 or args.index(key)+1>=len(args):raise LifecycleError('PCI-AUTOMATION-ARGS','validation')
        options[key]=args[args.index(key)+1]
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*',options['--orce-namespace']) or options['--orce-namespace'] in ['ocm-wstack','infrastructure','security','xfsc-orce-operator']:raise LifecycleError('PCI-AUTOMATION-NAMESPACE','validation')
    endpoint=urllib.parse.urlsplit(value.get('editorUrl',''))
    if endpoint.scheme!='https' or endpoint.username or endpoint.password or endpoint.hostname!=options['--main-host'] or endpoint.query or endpoint.fragment:raise LifecycleError('PCI-AUTOMATION-EDITOR','validation')
    environment=value.get('environment',{})
    if not isinstance(environment,dict) or any(not re.fullmatch('PCI_[A-Z0-9_]+',k) or not isinstance(v,str) for k,v in environment.items()):raise LifecycleError('PCI-AUTOMATION-ENV','validation')
    return value,options

def run(operation,config_path,emit):
    config,opt=configuration(config_path)
    if operation=='uninstall' and not config.get('allowUninstall'):raise LifecycleError('PCI-AUTOMATION-UNINSTALL-DISABLED','validation')
    env={**os.environ,**config.get('environment',{})}
    env.pop('BASH_ENV',None);env.pop('ENV',None)
    env['KUBECONFIG']=opt['--kubeconfig']
    with tempfile.TemporaryDirectory(prefix='pci-lifecycle-') as directory:
        private=Path(directory)
        def command(step,args,output=False):
            emit('pci.automation.step',step=step,status='running')
            # Private child output is deliberately not copied into ORCE context.
            # Only stable phase identifiers and exit codes cross this boundary.
            with subprocess.Popen(args,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True) as proc:
                chunks=[];deadline=time.monotonic()+2400
                # A timer terminates the whole subprocess group; no shell is used.
                import threading
                def expired():
                    try:os.killpg(proc.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
                previous=signal.getsignal(signal.SIGTERM)
                def terminate(signum,frame):
                    expired();raise LifecycleError('PCI-AUTOMATION-CANCELLED',step)
                signal.signal(signal.SIGTERM,terminate)
                timer=threading.Timer(2400,expired);timer.start()
                try:
                    for line in iter(proc.stdout.readline,b''):
                        if output:
                            chunks.append(line)
                            if sum(map(len,chunks))>4194304:proc.terminate();raise LifecycleError('PCI-AUTOMATION-OUTPUT-LIMIT',step)
                        if time.monotonic()>deadline:proc.kill();raise LifecycleError('PCI-AUTOMATION-DEADLINE',step)
                    code=proc.wait(timeout=10)
                finally:timer.cancel();signal.signal(signal.SIGTERM,previous)
            if code:raise LifecycleError('PCI-AUTOMATION-CHILD-FAILED',step,code)
            emit('pci.automation.step',step=step,status='complete')
            return b''.join(chunks)
        # Pin a private kubeconfig to the requested context for helpers which
        # use kubectl without an explicit --context. Never change the user's file.
        kube=command('context',['kubectl','--kubeconfig',opt['--kubeconfig'],'--context',opt['--context'],'config','view','--raw','--minify','--flatten','-o','json'],True)
        context_file=private/'kubeconfig';context_file.write_bytes(kube);context_file.chmod(0o600);env['KUBECONFIG']=str(context_file)
        if config.get('legacyBaselineFile'):command('legacy_baseline',['python3','scripts/import-legacy-baseline.py','--context',opt['--context'],'--kubeconfig',str(context_file),'--baseline',config['legacyBaselineFile'],'--apply'])
        if operation in ['deploy','upgrade']:command('prerequisites',['bash','scripts/deploy.sh',*config['g0Args']])
        if operation!='uninstall':
            command('artifacts',['python3','scripts/install-with-retries.py','--source',str(ROOT),'--config',str(Path(config_path).resolve())])
            return {'namespace':opt['--orce-namespace'],'deployment':opt['--orce-deployment']}
        emit('pci.automation.step',step='editor_auth',status='running')
        password=Path(config['editorPasswordFile']).read_text().rstrip('\r\n')
        body=urllib.parse.urlencode({'client_id':'node-red-admin','grant_type':'password','scope':'*','username':config.get('editorUsername','admin'),'password':password}).encode()
        request=urllib.request.Request(config['editorUrl'].rstrip('/')+'/auth/token',data=body,headers={'Content-Type':'application/x-www-form-urlencoded'})
        ctx=ssl.create_default_context();ctx.minimum_version=ssl.TLSVersion.TLSv1_3;ctx.maximum_version=ssl.TLSVersion.TLSv1_3
        try:
            with urllib.request.urlopen(request,timeout=20,context=ctx) as response:token=json.loads(response.read(65536)).get('access_token','')
            if not isinstance(token,str) or not token or '\n' in token or '\r' in token:raise ValueError()
        except Exception:raise LifecycleError('PCI-AUTOMATION-EDITOR-AUTH','editor_auth') from None
        curl=private/'editor.curl';curl.write_text('header = '+json.dumps('Authorization: Bearer '+token)+'\n');curl.chmod(0o600)
        del password,body,token;env['PCI_ORCE_CURL_CONFIG']=str(curl)
        flags=[]
        if config.get('providerCurlConfig'):env['PCI_PROVIDER_CURL_CONFIG']=config['providerCurlConfig'];flags=['--delete-tenants']
        command('uninstall',['bash','scripts/uninstall.sh',opt['--orce-namespace'],opt['--orce-deployment'],*flags])
        return {'namespace':opt['--orce-namespace'],'deployment':opt['--orce-deployment']}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('operation',choices=['deploy','upgrade','install-artifacts','uninstall']);parser.add_argument('--config',required=True);args=parser.parse_args()
    os.umask(0o077);run_id=str(uuid.uuid4());started=time.monotonic();version=(ROOT/'VERSION').read_text().strip()
    def emit(event,**values):print(json.dumps({'event':event,'runId':run_id,'operation':args.operation,'version':version,**values}),flush=True)
    try:
        # One release runner per configuration; concurrent reconciliations must
        # not overwrite flow revisions or Helm state.
        lock_path=Path(args.config).resolve().with_suffix('.lock')
        with lock_path.open('w') as lock:
            try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:raise LifecycleError('PCI-AUTOMATION-BUSY','validation')
            result=run(args.operation,args.config,emit)
        emit('pci.automation.result',status='complete',elapsedMs=round((time.monotonic()-started)*1000),**result);return 0
    except Exception as error:
        emit('pci.automation.result',status='failed',**problem(error),elapsedMs=round((time.monotonic()-started)*1000));return 1
if __name__=='__main__':sys.exit(main())
