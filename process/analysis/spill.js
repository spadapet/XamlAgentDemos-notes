const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const runs={};for(const r of rows){(runs[r.demo+'/'+r.run]=runs[r.demo+'/'+r.run]||[]).push(r)}
for(const [k,rs] of Object.entries(runs)){rs.sort((a,b)=>a.ts<b.ts?-1:1); rs.forEach((r,i)=>{ if(/^Output too large/.test(r.result||'')){const nx=rs.slice(i+1,i+3).map(n=>n.tool+':'+JSON.stringify(n.args).slice(0,140)); console.log(k,r.tool,JSON.stringify(r.args).slice(0,200),'\n   size:',(r.result.match(/\(([\d.]+ KB)\)/)||[])[1],'\n   next:',nx.join('\n         '))}})}
// size buckets for xaml results not spilled
const sz={};for(const r of rows.filter(r=>r.tool.startsWith('xaml_'))){const b=(r.result||'').length; const s=sz[r.tool]=sz[r.tool]||{n:0,sum:0,max:0,over10k:0}; s.n++;s.sum+=b;s.max=Math.max(s.max,b); if(b>10000)s.over10k++}
for(const [t,s] of Object.entries(sz)) console.log(t.padEnd(32),'avgB',Math.round(s.sum/s.n),'max',s.max,'>10KB',s.over10k);
