const fs=require('fs');
const rows=fs.readFileSync(process.argv[2],'utf8').split('\n').map(JSON.parse).filter(r=>r.kind=='call');
const act={},keys={};
for(const r of rows.filter(r=>r.tool=='xaml_interact')){act[r.args.action]=(act[r.args.action]||0)+1; for(const k of Object.keys(r.args)) keys[k]=(keys[k]||0)+1}
console.log(act,keys);
for(const t of ['xaml_capture_image','xaml_get_element_properties','xaml_find_elements','xaml_get_visual_tree','xaml_explain_property_value','xaml_set_element_property','xaml_get_binding_failures','xaml_get_element_styles','xaml_hit_test','xaml_apply_hot_reload']){const ks={};for(const r of rows.filter(r=>r.tool==t)) for(const [k,v] of Object.entries(r.args)) {if(k=='progressMessage')continue; const kk=(typeof v=='boolean')?k+'='+v:k; ks[kk]=(ks[kk]||0)+1}; console.log(t,JSON.stringify(ks))}
// capture interval
const runs={};for(const r of rows){(runs[r.demo+'/'+r.run]=runs[r.demo+'/'+r.run]||[]).push(r)}
let caps=[];for(const [k,rs] of Object.entries(runs)){const c=rs.filter(r=>r.tool=='xaml_capture_image').length; caps.push(k+':'+c)} console.log(caps.join(' '));
// identical-capture notes
let ident=0;for(const r of rows.filter(r=>r.tool=='xaml_capture_image')) if(/identical|unchanged/i.test(r.result||'')) ident++; console.log('identical captures',ident);
