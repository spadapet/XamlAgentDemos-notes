const fs=require('fs'); const f=process.argv[2]; const calls={};
for(const raw of fs.readFileSync(f,'utf8').split('\n')){ let e; try{e=JSON.parse(raw)}catch{continue}
 const d=e.data||{}, ts=(e.timestamp||'').slice(11,19);
 if(e.type==='tool.execution_start'){ calls[d.toolCallId]=d.toolName; console.log(ts, d.toolName, JSON.stringify(d.arguments||{}).slice(0,140)); }
 else if(e.type==='tool.execution_complete' && !d.success){ console.log(ts,'  FAILED', calls[d.toolCallId], JSON.stringify(d.error||d.result||'').slice(0,200)); }
 else if(e.type==='user.message'){ console.log(ts,'USER', d.content.slice(0,80)); }
 else if(e.type==='session.task_complete'){ console.log(ts,'DONE', (d.summary||'').slice(0,300)); }
}
