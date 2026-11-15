const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call'&&r.tool.startsWith('xaml_'));
let n=0;for(const r of rows){const a=JSON.stringify(r.args); if(/DataContext|Command/.test(a)){n++; if(n<12){const m=(r.result||'').match(/"name":"(DataContext|Command)"[^}]{0,300}/); console.log(r.demo+'/'+r.run,r.tool,a.slice(0,160),'\n   =>',m?m[0]:'(none)')}}}
console.log('calls mentioning DataContext/Command',n);
