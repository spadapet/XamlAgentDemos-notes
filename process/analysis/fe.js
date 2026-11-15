const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const runs={};for(const r of rows){(runs[r.demo+'/'+r.run]=runs[r.demo+'/'+r.run]||[]).push(r)}
let fe=0,feName=0,feUsedNext=0,afterHR=0;
for(const [k,rs] of Object.entries(runs)){rs.sort((a,b)=>a.ts<b.ts?-1:1);
 rs.forEach((r,i)=>{ if(r.tool!='xaml_find_elements')return; fe++; if(r.args.name&&!/[*?]/.test(r.args.name)) feName++;
  const prevX=rs.slice(0,i).reverse().find(x=>x.tool.startsWith('xaml_')&&x.tool!='xaml_find_elements'); if(prevX&&prevX.tool=='xaml_apply_hot_reload') afterHR++;
  let ids=[];try{const j=JSON.parse(r.result);ids=(j.elements||j.results||[]).map(e=>e.id)}catch{}
  const nx=rs.slice(i+1).find(x=>x.tool.startsWith('xaml_')); if(nx){const a=JSON.stringify(nx.args); if(ids.some(id=>a.includes('"'+id+'"'))) feUsedNext++;}
 })}
console.log({fe,feNameExact:feName,feIdsUsedByNextXamlCall:feUsedNext,findAfterHotReload:afterHR});
// visual tree depth/maxNodes stats, truncated flags
let vt=0,trunc=0,dl=0;for(const r of rows.filter(r=>r.tool=='xaml_get_visual_tree')){vt++; if(/"truncated":\s*(true|\d)/.test(r.result))trunc++; if(/depthLimitedNodes/.test(r.result))dl++}
console.log({vt,trunc,depthLimited:dl});
// get_binding_failures counts per run
const bf={};for(const r of rows.filter(r=>/binding_failures/.test(r.tool))) bf[r.demo+'/'+r.run]=(bf[r.demo+'/'+r.run]||0)+1; console.log(bf);
// set_element_property on Window Width
let ww=0;for(const r of rows.filter(r=>r.tool=='xaml_set_element_property')) if(/Width|Height|WindowState|Left|Top/.test(JSON.stringify(r.args))) ww++; console.log('set_property size/window',ww);
