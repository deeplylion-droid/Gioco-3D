"""Piccolo client per l'API di Meshy (legge la chiave da MESHY_API_KEY)."""
import json, os, sys, time, urllib.request, urllib.error

API = 'https://api.meshy.ai/openapi'


def _req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data, method=method, headers={
        'Authorization': 'Bearer ' + os.environ['MESHY_API_KEY'],
        'Content-Type': 'application/json',
    })
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{method} {path} -> {e.code}: {e.read().decode()[:500]}')


def create(kind, body):
    return _req('POST', f'/v1/{kind}', body)['result']


def wait(kind, task_id, every=5, timeout=1800):
    t0 = time.time()
    while True:
        t = _req('GET', f'/v1/{kind}/{task_id}')
        if t['status'] in ('SUCCEEDED', 'FAILED', 'CANCELED'):
            return t
        if time.time() - t0 > timeout:
            raise TimeoutError(task_id)
        time.sleep(every)


def download(url, path):
    with urllib.request.urlopen(url, timeout=300) as resp, open(path, 'wb') as f:
        f.write(resp.read())
    return path


def balance():
    return _req('GET', '/v1/balance')


if __name__ == '__main__':
    print(balance())
