const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const runs={};for(const r of rows){(runs[r.demo+'/'+r.run]=runs[r.demo+'/'+r.run]||[]).push(r)}
const big={},tri={};const sameRuns={};const idUse={};
for(const [k,rs0] of Object.entries(runs)){const rs=rs0.filter(r=>r.tool.startsWith('xaml_')).sort((a,b)=>a.ts<b.ts?-1:1);
 for(let i=1;i<rs.length;i++){const b=rs[i-1].tool.slice(5)+' > '+rs[i].tool.slice(5);big[b]=(big[b]||0)+1}
 let i=0;while(i<rs.length){let j=i;while(j+1<rs.length&&rs[j+1].tool==rs[i].tool)j++; const len=j-i+1; if(len>=3){const key=rs[i].tool;(sameRuns[key]=sameRuns[key]||[]).push(k+':'+len)} i=j+1;}
 for(const r of rs){const ids=[].concat(r.args.elementId||[],r.args.elementIds||[]); for(const id of ids){const key=k+'|'+r.tool+'|'+id; idUse[key]=(idUse[key]||0)+1}}
}
console.log('TOP BIGRAMS');Object.entries(big).sort((a,b)=>b[1]-a[1]).slice(0,30).forEach(x=>console.log(x[1],x[0]));
console.log('\nSTREAKS >=3 same tool consecutively');for(const [t,v] of Object.entries(sameRuns)) console.log(t,v.length,v.join(' '));
console.log('\nSAME ID SAME TOOL >=4');Object.entries(idUse).filter(x=>x[1]>=4).sort((a,b)=>b[1]-a[1]).slice(0,40).forEach(x=>console.log(x[1],x[0]));
