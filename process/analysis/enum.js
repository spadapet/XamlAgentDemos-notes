const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call'&&r.tool.startsWith('xaml_'));
const late=rows.filter(r=>/final|feedback|consolidated/.test(r.run));
let enumNum=0,ex=null;for(const r of late){const m=(r.result||'').match(/"name":"(Visibility|HorizontalAlignment|Stretch|Orientation)","value":"(\d)"/); if(m){enumNum++; ex=ex||r.demo+'/'+r.run+' '+m[0]}}
console.log('late enum numeric results',enumNum,ex);
let named=0;for(const r of late){if(/"name":"Visibility","value":"(Collapsed|Visible|Hidden)"/.test(r.result||'')) named++} console.log('named visibility',named);
// capture identical notes
for(const r of rows.filter(r=>r.tool=='xaml_capture_image'&&/identical/i.test(r.result||''))) console.log(r.demo+'/'+r.run, r.result.slice(0,250));
