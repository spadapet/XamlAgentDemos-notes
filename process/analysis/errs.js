const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
function classify(r){
 const res=r.result||'';
 if(/^Output too large to read at once/.test(res)) return {spill:true};
 let code=null,msg='';
 if(r.success===false){ let m=res; try{const j=JSON.parse(res); m=j.message||res;}catch{}; try{const j2=JSON.parse(m); code=j2.error; msg=j2.message;}catch{ code='RPC/other'; msg=m;} return {code,msg}; }
 try{const j=JSON.parse(res); if(typeof j.error=='string'){return {code:j.error,msg:j.message||''}} if(j.failed>0){return {batchFailed:j.failed, sub:(j.results||[]).filter(x=>x.error).map(x=>typeof x.error=='string'?x.error:(x.error.code||JSON.stringify(x.error))).join(',')}} }catch{}
 if(/WINDOW_MINIMIZED|OUTPUT_TOO_LARGE|ELEMENT_GONE|TAP_TIMEOUT|DEBUGGER_PAUSED/.test(res.slice(0,300))) return {code:(res.match(/WINDOW_MINIMIZED|OUTPUT_TOO_LARGE|ELEMENT_GONE|TAP_TIMEOUT|DEBUGGER_PAUSED/)||[])[0],msg:res.slice(0,150)};
 return {};
}
const per={},codes={},spills={},msgs={};
for(const r of rows){ if(!r.tool.startsWith('xaml_')) continue; const c=classify(r); const p=per[r.tool]=per[r.tool]||{n:0,err:0,spill:0,batchPartial:0,codes:{}}; p.n++;
 if(c.spill){p.spill++;spills[r.demo+'/'+r.run]=(spills[r.demo+'/'+r.run]||0)+1}
 if(c.code){p.err++;p.codes[c.code]=(p.codes[c.code]||0)+1; codes[c.code]=(codes[c.code]||0)+1; const k=c.code+': '+(c.msg||'').slice(0,160); msgs[k]=(msgs[k]||[]); msgs[k].push(r.demo+'/'+r.run);}
 if(c.batchFailed){p.batchPartial++; p.codes['batch:'+c.sub]=(p.codes['batch:'+c.sub]||0)+1; const k='batch '+r.tool+': '+c.sub; msgs[k]=(msgs[k]||[]); msgs[k].push(r.demo+'/'+r.run);}
}
for(const [t,p] of Object.entries(per).sort((a,b)=>b[1].n-a[1].n)) console.log(t.padEnd(32),'n',p.n,'err',p.err,'spill>20KB',p.spill,'batchPartial',p.batchPartial,JSON.stringify(p.codes));
console.log('\nCODES',codes);console.log('\nSPILLS',spills);
console.log('\nMESSAGES');for(const [k,v] of Object.entries(msgs)) console.log(v.length,k,'|',[...new Set(v)].join(' '));
