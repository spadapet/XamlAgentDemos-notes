const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const st={};const runs={};for(const r of rows){(runs[r.demo+'/'+r.run]=runs[r.demo+'/'+r.run]||[]).push(r)}
const after={};
for(const [k,rs] of Object.entries(runs)){rs.sort((a,b)=>a.ts<b.ts?-1:1); rs.forEach((r,i)=>{ if(r.tool!='xaml_apply_hot_reload')return; let s='?';try{const j=JSON.parse(r.result);s=(j.status||'')+'|code:'+(j.codeStatus||'-')}catch{}; st[s]=(st[s]||0)+1;
 const nx=rs.slice(i+1,i+4).filter(x=>x.tool.startsWith('xaml_')).map(x=>x.tool.slice(5)).join('>'); after[nx]=(after[nx]||0)+1;})}
console.log(st);console.log(Object.entries(after).sort((a,b)=>b[1]-a[1]).slice(0,12));
// hot reload log / status calls following apply
