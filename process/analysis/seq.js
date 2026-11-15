const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call'&&r.demo=='BindingStorm'&&r.run=='run-final2'&&r.tool.startsWith('xaml_'));
rows.sort((a,b)=>a.ts<b.ts?-1:1);
console.log(rows.map(r=>r.tool.slice(5).replace('get_binding_failures','BF').replace('clear_binding_failures','CLR').replace('capture_image','cap')+(r.args.action?'('+r.args.action+')':'')).join(' > '));
