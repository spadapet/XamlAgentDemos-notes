const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse);
let out='';
for(const r of rows.filter(r=>r.kind=='call'&&r.tool=='task_complete')){const s=r.args.summary||JSON.stringify(r.args); if(/useful|valuable|confus|unexpected/i.test(s)) out+='\n\n######## '+r.demo+'/'+r.run+'\n'+s;}
fs.writeFileSync(process.argv[3],out);console.log(out.length);
