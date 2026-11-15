const fs = require('fs'), path = require('path');
const [src, out, maxArg] = process.argv.slice(2);
const maxres = parseInt(maxArg || '2500');
const imgdir = out.replace(/\.md$/, '') + '_images';
fs.mkdirSync(path.dirname(out), { recursive: true });
const calls = {}, lines = [], stats = { tools: {}, failed: 0, images: 0 };
const t = (s, n = maxres) => { s = typeof s === 'string' ? s : JSON.stringify(s, null, 1); return s.length <= n ? s : s.slice(0, n) + `\n... [truncated ${s.length - n} chars]`; };
for (const raw of fs.readFileSync(src, 'utf8').split('\n')) {
  let e; try { e = JSON.parse(raw); } catch { continue; }
  const ty = e.type, d = e.data || {}, ts = (e.timestamp || '').slice(11, 19);
  if (ty === 'user.message') lines.push(`\n## User (${ts})\n\n${d.content}\n`);
  else if (ty === 'assistant.message') {
    if ((d.content || '').trim()) lines.push(`\n**Assistant (${ts}):**\n\n${d.content}\n`);
    for (const r of d.toolRequests || []) {
      calls[r.toolCallId] = r.name; stats.tools[r.name] = (stats.tools[r.name] || 0) + 1;
      lines.push(`\n**Tool call (${ts}):** \`${r.name}\`\n\`\`\`json\n${t(r.arguments, 1500)}\n\`\`\`\n`);
    }
  } else if (ty === 'tool.execution_complete') {
    const name = calls[d.toolCallId] || '?'; if (!d.success) stats.failed++;
    const res = d.result || {}; let c = (res && res.content !== undefined) ? res.content : (d.error || res);
    lines.push(`<details><summary>Result \`${name}\` success=${d.success}</summary>\n\n\`\`\`\n${t(c)}\n\`\`\`\n</details>\n`);
  } else if (ty === 'session.binary_asset' && d.type === 'image') {
    fs.mkdirSync(imgdir, { recursive: true }); stats.images++;
    const f = `img${String(stats.images).padStart(3, '0')}.png`;
    fs.writeFileSync(path.join(imgdir, f), Buffer.from(d.data, 'base64'));
    lines.push(`\n![image](${path.basename(imgdir)}/${f})\n`);
  } else if (ty === 'session.task_complete') lines.push(`\n**Task complete (${ts}):** ${d.summary || ''}\n`);
  else if (ty === 'skill.invoked') lines.push(`\n_Skill invoked: ${d.name}_\n`);
  else if (ty === 'session.auto_mode_resolved') lines.push(`\n_Model: ${d.chosenModel}_\n`);
}
const hdr = ['# Session transcript', '', `Source: \`${src}\``, '', '## Tool usage', ''];
for (const [k, v] of Object.entries(stats.tools).sort((a, b) => b[1] - a[1])) hdr.push(`- ${k}: ${v}`);
hdr.push('', `Failed tool calls: ${stats.failed}, images: ${stats.images}`, '');
fs.writeFileSync(out, hdr.concat(lines).join('\n'));
console.log(JSON.stringify(stats));
