const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call'&&r.tool.startsWith('xaml_')&&r.endts);
const s={};for(const r of rows){const dt=(Date.parse(r.endts)-Date.parse(r.ts))/1000; const x=s[r.tool]=s[r.tool]||[]; x.push(dt)}
for(const [t,a] of Object.entries(s)){a.sort((x,y)=>x-y); console.log(t.padEnd(32),'n',a.length,'median',a[a.length>>1].toFixed(1),'p90',a[Math.floor(a.length*.9)].toFixed(1),'max',a[a.length-1].toFixed(1),'total',a.reduce((p,c)=>p+c,0).toFixed(0))}
