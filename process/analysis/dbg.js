const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
for(const r of rows.filter(r=>/^debugger_(evaluate|set_break|ui_|launch|read_file)/.test(r.tool)||r.tool=='task')) console.log('---',r.demo+'/'+r.run,r.tool,'::',JSON.stringify(r.args).replace(/\s+/g,' ').slice(0,330));
