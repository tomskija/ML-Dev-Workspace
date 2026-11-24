##########################################################
"""
Clones any project (and the UI) in projects.json that isn't already sitting next to this repo.
Uses your normal git and SSH setup on the host.

    python3 scripts/clone_projects.py
"""
##########################################################
import os
import json
import subprocess
from os.path import dirname, abspath, join, normpath

ROOT = dirname(dirname(abspath(__file__)))

##########################################################
def main():
    with open(join(ROOT, 'projects.json')) as f:
        cfg = json.load(f)
    base = normpath(join(ROOT, cfg['workspace']['projects_root']))
    repos = [(p['repo'], p['git']) for p in cfg['projects']]
    if cfg['workspace'].get('ui'): repos.append((cfg['workspace']['ui']['repo'], cfg['workspace']['ui']['git']))
    for repo, git in repos:
        target = join(base, repo)
        if os.path.isdir(join(target, '.git')):
            print(f"ok       {repo}")
            continue
        print(f"cloning  {repo}")
        subprocess.run(['git', 'clone', git, target], check=True)

##########################################################
if __name__ == "__main__":
    main()
##########################################################
