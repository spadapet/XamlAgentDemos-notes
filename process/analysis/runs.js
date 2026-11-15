const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const runs={};
for(const r of rows){const k=r.demo+'/'+r.run;(runs[k]=runs[k]||[]).push(r)}
let tot=0,totx=0;
for(const [k,rs] of Object.entries(runs)){const x=rs.filter(r=>r.tool.startsWith('xaml_')).length; tot+=rs.length;totx+=x;
 const t0=Date.parse(rs[0].ts),t1=Date.parse(rs[rs.length-1].endts||rs[rs.length-1].ts);
 const fb={}; for(const r of rs){ if(/^(powershell|run_command_in_terminal|debugger_|run_build|collect_trace)/.test(r.tool)) fb[r.tool]=(fb[r.tool]||0)+1;}
 console.log(k.padEnd(36),'calls',String(rs.length).padStart(3),'xaml',String(x).padStart(3),'min',((t1-t0)/60000).toFixed(1),JSON.stringify(fb));}
const n=Object.keys(runs).length;console.log('runs',n,'avg calls',(tot/n).toFixed(1),'avg xaml',(totx/n).toFixed(1));
// get_file targets
const gf={};for(const r of rows){ if(['get_file','view','read_file'].includes(r.tool)){const p=(r.args.filePath||r.args.path||r.args.file||JSON.stringify(r.args)); const ext=/Output too large|AppData.*(Temp|Visu)|large/i.test(p)?'SPILL':/SKILL|skills|references/i.test(p)?'skill':(p.match(/\.(\w+)$/)||['','?'])[1]; gf[ext]=(gf[ext]||0)+1}}
console.log('file reads by kind',gf);
