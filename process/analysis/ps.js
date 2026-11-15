const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const gf=rows.filter(r=>r.tool=='get_file'); console.log(JSON.stringify(gf[0].args).slice(0,300));
const ext={};for(const r of gf){const p=r.args.filename||r.args.filePath||r.args.path||''; const k=/large|AppData/i.test(p)?'SPILL':(p.match(/\.(\w+)$/)||['','?'])[1]; ext[k]=(ext[k]||0)+1}
console.log(ext);
for(const r of rows.filter(r=>r.tool=='powershell'||r.tool=='run_command_in_terminal')) console.log('---',r.demo+'/'+r.run,'::',(r.args.command||JSON.stringify(r.args)).replace(/\s+/g,' ').slice(0,260));
