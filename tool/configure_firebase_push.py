#!/usr/bin/env python3
"""Register Android push apps and download their public configuration.

Read-only unless --apply is supplied. Uses the logged-in gcloud identity;
OAuth tokens and server private keys are never written or printed.
"""
import argparse
import base64
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,61}[a-z0-9]', args.project):
        parser.error('Invalid Google Cloud project ID')
    token = subprocess.check_output(
        ['gcloud', 'auth', 'print-access-token'], text=True).strip()
    base = 'https://firebase.googleapis.com/v1beta1/'

    def request(path, payload=None):
        data = None if payload is None else json.dumps(payload).encode()
        req = urllib.request.Request(base + path, data=data, headers={
            'Authorization': f'Bearer {token}',
            'X-Goog-User-Project': args.project,
            'Content-Type': 'application/json',
        })
        with urllib.request.urlopen(req, timeout=45) as response:
            return json.load(response)

    def complete(operation):
        deadline = time.monotonic() + 240
        while not operation.get('done'):
            if time.monotonic() >= deadline:
                raise RuntimeError('Firebase operation is still pending; rerun to inspect it')
            time.sleep(2)
            operation = request(operation['name'])
        if operation.get('error'):
            raise RuntimeError(operation['error'].get('message', 'Firebase operation failed'))
        return operation.get('response', {})

    project_path = f'projects/{args.project}'
    try:
        request(project_path)
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        if not args.apply:
            print(f'Firebase activation required on existing project {args.project}.')
            print('Plan: activate Firebase, register Play Store and beta Android apps, download public configuration.')
            return
        complete(request(project_path + ':addFirebase', {}))
        print(f'Firebase activated: {args.project}', flush=True)

    apps = []
    page = project_path + '/androidApps'
    while page:
        result = request(page)
        apps.extend(result.get('apps', []))
        cursor = result.get('nextPageToken')
        page = project_path + '/androidApps?pageToken=' + urllib.parse.quote(cursor, safe='') if cursor else None

    registrations = [
        ('com.manugopinath.battlechessarena', 'Battle Chess Arena', 'production'),
        ('com.manugopinath.battlechessarena.mobiletest', 'Battle Chess Arena Beta', 'mobiletest'),
    ]
    output = Path(__file__).resolve().parents[1] / 'android/app/firebase'
    for package, display_name, variant in registrations:
        app = next((item for item in apps if item['packageName'] == package), None)
        if not args.apply:
            print(f'{package}: ' + (f"registered ({app['appId']})" if app else 'registration required'))
            continue
        if app is None:
            app = complete(request(project_path + '/androidApps', {
                'packageName': package, 'displayName': display_name,
            }))
        resource = app.get('name') or f"{project_path}/androidApps/{app['appId']}"
        response = request(resource + '/config')
        config = json.loads(base64.b64decode(response['configFileContents']))
        client = next(item for item in config['client']
                      if item['client_info']['android_client_info']['package_name'] == package)
        values = {
            'projectId': config['project_info']['project_id'],
            'senderId': str(config['project_info']['project_number']),
            'appId': client['client_info']['mobilesdk_app_id'],
            'apiKey': client['api_key'][0]['current_key'],
        }
        if values['projectId'] != args.project or values['appId'] != app['appId']:
            raise RuntimeError('Downloaded Firebase configuration does not match registration')
        if any(not value or '\n' in value or '\r' in value for value in values.values()):
            raise RuntimeError('Invalid Firebase configuration value')
        output.mkdir(parents=True, exist_ok=True)
        destination = output / f'{variant}.properties'
        temporary = destination.with_suffix('.properties.tmp')
        temporary.write_text('# Public Firebase Android app configuration. Not a service-account key.\n'
                             + ''.join(f'{key}={value}\n' for key, value in values.items()))
        temporary.replace(destination)
        print(f"Configured {package}: {app['appId']} → {destination}", flush=True)


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        try:
            detail = json.load(error).get('error', {}).get('message', 'Request failed')
        except (ValueError, KeyError):
            detail = 'Request failed'
        raise SystemExit(f'Firebase request failed ({error.code}): {detail}') from None
