import json, sys, collections, datetime

def ts(s):
    return datetime.datetime.fromisoformat(s.replace('Z', '+00:00'))

def summarize(d):
    ev = [json.loads(l) for l in open(d + r'\events.jsonl', encoding='utf-8') if l.strip()]
    starts = {e['data']['toolCallId']: e['data'] for e in ev if e['type'] == 'tool.execution_start'}
    counts = collections.Counter(s['toolName'] for s in starts.values())
    failed = []
    for e in ev:
        if e['type'] != 'tool.execution_complete':
            continue
        data = e['data']
        content = json.dumps(data.get('result', {}))[:4000]
        name = starts.get(data['toolCallId'], {}).get('toolName', '?')
        if not data.get('success', True) or ('\\"error\\"' in content and name.startswith('xaml_')):
            failed.append((name, json.dumps(starts.get(data['toolCallId'], {}).get('arguments'))[:200], content[:400]))
    times = [ts(e['timestamp']) for e in ev if 'timestamp' in e]
    print('==', d)
    print('duration_min', round((max(times) - min(times)).total_seconds() / 60, 1))
    print('tools', dict(counts.most_common()))
    print('failed', len(failed))
    for f in failed:
        print('  FAIL', f)
    users = [i for i, e in enumerate(ev) if e['type'] == 'user.message']
    fb = None
    for i in users:
        if ev[i]['data'].get('content', '').startswith('Thanks.'):
            for e in ev[i + 1:]:
                if e['type'] == 'assistant.message' and e['data'].get('content'):
                    fb = e['data']['content']
                    break
    for e in ev:
        if e['type'] == 'tool.execution_start' and e['data']['toolName'] == 'task_complete':
            print('TASK_COMPLETE:', json.dumps(e['data'].get('arguments'))[:3000])
    print('FEEDBACK:', fb)

for d in sys.argv[1:]:
    summarize(d)
