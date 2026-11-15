const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const runs=new Set(rows.map(r=>r.demo+'/'+r.run));
console.log('runs with events',runs.size,'calls',rows.length);
const by={};
function errOf(r){ if(r.success===false) return 'TOOLFAIL:'+(r.result||'').slice(0,120);
 if(r.tool.startsWith('xaml_')){ try{const j=JSON.parse(r.result); if(j&&j.error&&typeof j.error=='object') return j.error.code||'?'; if(j&&j.errorCode) return j.errorCode; if(j && typeof j.error=='string' && !Array.isArray(j.results)) return 'ERR:'+j.error.slice(0,80);}catch(e){ if(/^\s*\{/.test(r.result||'')) return null; return 'NONJSON:'+(r.result||'').slice(0,100);} }
 return null;}
for(const r of rows){const t=r.tool;by[t]=by[t]||{n:0,fail:0,codes:{},runs:new Set()};by[t].n++;by[t].runs.add(r.demo+'/'+r.run);const e=errOf(r);if(e){by[t].fail++;by[t].codes[e]=(by[t].codes[e]||0)+1}}
const arr=Object.entries(by).sort((a,b)=>b[1].n-a[1].n);
for(const [t,v] of arr) console.log(t.padEnd(45),v.n,'runs',v.runs.size,'fail',v.fail,JSON.stringify(v.codes).slice(0,400));
