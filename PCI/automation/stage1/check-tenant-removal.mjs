// Runs inside the selected ORCE pod before removing its PCI prerequisites.
import fs from 'node:fs';
import {createRequire} from 'node:module';
const {Client}=createRequire('/data/package.json')('pg');
try {
  const e=process.env,url=new URL(e.PCI_DATABASE_URL),parameters=[...url.searchParams.keys()].filter(k=>k.startsWith('ssl'));
  if(parameters.some(k=>!['sslmode','sslrootcert','sslcert','sslkey'].includes(k)) || (url.searchParams.has('sslmode')&&url.searchParams.get('sslmode')!=='verify-full'))throw Error();
  let ssl;
  if(e.PCI_DATABASE_TLS==='true'||parameters.length){
    ssl={minVersion:'TLSv1.3',maxVersion:'TLSv1.3',rejectUnauthorized:true};
    for(const [key,query,suffix]of [['ca','sslrootcert','CA'],['cert','sslcert','CERT'],['key','sslkey','KEY']]){
      const file=e['PCI_DATABASE_TLS_'+suffix+'_FILE'],parameter=url.searchParams.get(query);
      if(file&&parameter&&file!==parameter)throw Error();
      if(file||parameter)ssl[key]=fs.readFileSync(file||parameter);
    }
    if(Boolean(ssl.cert)!==Boolean(ssl.key))throw Error();
  }
  for(const key of parameters)url.searchParams.delete(key);
  const client=new Client({connectionString:url.toString(),...(ssl?{ssl}:{}),connectionTimeoutMillis:5000,query_timeout:10000});
  await client.connect();
  try{
    const result=await client.query('SELECT count(*)::int AS n FROM tenants WHERE state <> $1',['deleted']);
    if(result.rows[0].n)throw Object.assign(Error(),{code:'PCI-UNINSTALL-ACTIVE-TENANTS'});
  }finally{await client.end();}
}catch(error){
  console.error(error.code==='PCI-UNINSTALL-ACTIVE-TENANTS'?'PCI-UNINSTALL-ACTIVE-TENANTS: complete confirmed tenant deletion first':'PCI-UNINSTALL-DATABASE-UNAVAILABLE');
  process.exitCode=1;
}
