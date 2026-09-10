#!/usr/bin/env python3
"""Offline integration checks; pushes only to disposable local bare repositories."""
import pathlib
import plistlib
import shutil
import subprocess
import tempfile

source = pathlib.Path(__file__).resolve().parent / 'publish.sh'
with tempfile.TemporaryDirectory(prefix='metaldoom-publish-test-') as temporary:
    root = pathlib.Path(temporary)
    repo, remote = root / 'checkout', root / 'origin.git'

    def run(*args, cwd=repo, ok=True):
        result = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if ok and result.returncode:
            raise AssertionError(f'{args}: {result.stdout}')
        if not ok and not result.returncode:
            raise AssertionError(f'Expected rejection: {args}\n{result.stdout}')
        return result.stdout.strip()

    run('git', 'init', '--bare', str(remote), cwd=root)
    run('git', 'init', '-b', 'main', str(repo), cwd=root)
    for key, value in [('user.name', 'Release Test'), ('user.email', 'test@example.invalid'),
                       ('commit.gpgsign', 'false'), ('tag.gpgsign', 'false')]:
        run('git', 'config', key, value)
    run('git', 'remote', 'add', 'origin', str(remote))
    (repo / 'scripts').mkdir()
    shutil.copyfile(source, repo / 'scripts' / 'publish.sh')

    def commit(version, message):
        (repo / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleShortVersionString': version}))
        (repo / 'change.txt').write_text(message)
        run('git', 'add', '.')
        run('git', 'commit', '-m', message)
        return run('git', 'rev-parse', 'HEAD')

    def ref(name):
        return run('git', '--git-dir', str(remote), 'rev-parse', name)

    first = commit('0.3.0', 'first')
    run('bash', 'scripts/publish.sh', '--dry-run')
    assert run('git', 'tag') == ''
    assert run('git', 'ls-remote', 'origin') == ''
    run('bash', 'scripts/publish.sh')
    assert ref('refs/heads/main') == first and ref('v0.3.0^{commit}') == first
    assert run('git', 'cat-file', '-t', 'v0.3.0') == 'tag'
    second = commit('0.3.0', 'same version')
    run('bash', 'scripts/publish.sh')
    assert ref('refs/heads/main') == second and ref('v0.3.0^{commit}') == first
    third = commit('0.4.0', 'new version')
    run('bash', 'scripts/publish.sh')
    assert ref('v0.4.0^{commit}') == third
    (repo / 'untracked').write_text('stop')
    assert 'Commit or stash' in run('bash', 'scripts/publish.sh', ok=False)
    (repo / 'untracked').unlink()
    commit('0.2.0', 'older version')
    assert 'older than' in run('bash', 'scripts/publish.sh', ok=False)
    commit('0.5.0', 'next version')
    run('git', 'tag', '-a', 'v0.5.0', third, '-m', 'conflict')
    assert 'another commit' in run('bash', 'scripts/publish.sh', ok=False)
    run('git', 'tag', '-d', 'v0.5.0')
    run('git', 'checkout', '-b', 'experiment')
    assert 'Check out main' in run('bash', 'scripts/publish.sh', ok=False)
    run('git', 'checkout', '--detach')
    assert 'Check out main' in run('bash', 'scripts/publish.sh', ok=False)
    run('git', 'checkout', 'main')

    # Simulate someone advancing origin/main independently. The new tag must not
    # appear remotely when the atomic branch push is rejected.
    other = root / 'other'
    run('git', 'clone', '-b', 'main', str(remote), str(other), cwd=root)
    for key, value in [('user.name', 'Other Test'), ('user.email', 'other@example.invalid'), ('commit.gpgsign', 'false')]:
        run('git', 'config', key, value, cwd=other)
    (other / 'other.txt').write_text('concurrent work')
    run('git', 'add', '.', cwd=other)
    run('git', 'commit', '-m', 'advance origin', cwd=other)
    run('git', 'push', 'origin', 'main', cwd=other)
    advanced = ref('refs/heads/main')
    run('bash', 'scripts/publish.sh', ok=False)
    assert ref('refs/heads/main') == advanced
    assert run('git', 'ls-remote', 'origin', 'refs/tags/v0.5.0') == ''
    assert run('git', 'rev-parse', 'v0.5.0^{commit}') == run('git', 'rev-parse', 'HEAD')

print('Publish checks passed: dry run, first release, unchanged version, version bump, dirty checkout, downgrade, conflicting tag, branch/detached HEAD, and atomic rejection.')
