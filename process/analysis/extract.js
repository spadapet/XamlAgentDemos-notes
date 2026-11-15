const fs=require('fs'),path=require('path');
const root='Q:/source/XamlAgentDemos-notes/test-runs';
const out=[];
for(const demo of fs.readdirSync(root)){ if(!fs.statSync(path.join(root,demo)).isDirectory()) continue;
 for(const run of fs.readdirSync(path.join(root,demo))){
  const f=path.join(root,demo,run,'events.jsonl'); if(!fs.existsSync(f)) {console.error('noevents',demo,run);continue;}
  const starts={};let idx=0;
  for(const l of fs.readFileSync(f,'utf8').split(/\r?\n/)){ if(!l) continue; let e; try{e=JSON.parse(l)}catch{continue}
   if(e.type=='user.message') out.push({demo,run,kind:'user',text:(e.data.content||'').slice(0,3000),ts:e.timestamp});
   if(e.type=='tool.execution_start'){starts[e.data.toolCallId]={demo,run,kind:'call',i:idx++,tool:e.data.toolName,args:e.data.arguments,ts:e.timestamp,turn:e.data.turnId,parent:e.data.parentToolCallId};}
   if(e.type=='tool.execution_complete'){const s=starts[e.data.toolCallId]; if(!s) continue; s.success=e.data.success; let c=e.data.result&&e.data.result.content; if(c==null&&e.data.error) c=JSON.stringify(e.data.error); s.result=typeof c=='string'?c:JSON.stringify(c); s.endts=e.timestamp; out.push(s); delete starts[e.data.toolCallId];}
  }
  for(const k in starts){starts[k].success=null;out.push(starts[k]);}
 }}
fs.writeFileSync(process.argv[2],out.map(x=>JSON.stringify(x)).join('\n'));
console.log(out.length);

