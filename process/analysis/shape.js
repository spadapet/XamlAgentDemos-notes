const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const r=rows.filter(r=>r.tool=='xaml_get_element_properties'&&r.args.includeAll&&!/^Output too large/.test(r.result)).sort((a,b)=>b.result.length-a.result.length)[0];
console.log(r.demo,r.run,JSON.stringify(r.args),r.result.length);console.log(r.result.slice(0,2500));
const j=JSON.parse(r.result); const props=(j.properties||(j.results&&j.results[0].properties)||[]); console.log('nprops',props.length); const src={};for(const p of props){src[p.source||p.valueSource]=(src[p.source||p.valueSource]||0)+1} console.log(src);
