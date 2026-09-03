import urllib.request
import json
import time
import subprocess
import sys

proc = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
out, _ = proc.communicate('protocol=https\nhost=github.com\n')
token = [l.split('=', 1)[1] for l in out.splitlines() if l.startswith('password=')][0]

url = 'https://api.github.com/repos/hx010207/VIT---VANI/actions/runs?per_page=5'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Authorization': f'token {token}'})

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode('utf-8'))

runs = data.get('workflow_runs', [])
if not runs:
    print('No runs found')
    sys.exit(0)

latest = runs[0]
print(f"Latest Run: ID {latest['id']} | Status: {latest['status']} | Conclusion: {latest['conclusion']} | Commit: {latest['head_sha'][:7]} | URL: {latest['html_url']}")

jobs_url = latest.get('jobs_url')
if jobs_url:
    req_jobs = urllib.request.Request(jobs_url, headers={'User-Agent': 'Mozilla/5.0', 'Authorization': f'token {token}'})
    with urllib.request.urlopen(req_jobs) as j_resp:
        j_data = json.loads(j_resp.read().decode('utf-8'))
    for j in j_data.get('jobs', []):
        print(f"Job: {j['name']} ({j['status']}, {j['conclusion']})")
        for s in j.get('steps', []):
            print(f"  Step: {s['name']} -> {s['status']} ({s['conclusion']})")
