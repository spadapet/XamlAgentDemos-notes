const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
for(const r of rows.filter(r=>['rg','grep','grep_search','file_search','glob'].includes(r.tool))) console.log(r.demo+'/'+r.run,r.tool,(r.args.pattern||r.args.query||'').slice(0,150), '|', (r.args.glob||r.args.includePattern||''));
const fr=rows.find(r=>r.tool=='xaml_find_resource'&&r.demo=='StyleMaze'); console.log('\nFIND_RESOURCE',JSON.stringify(fr.args),fr.result.slice(0,1500));
