#!/usr/bin/env python3
"""Throws random keystrokes at a range-checked build of the editor (headless) and reports crashes.
usage: tests/fuzz.py [runs] [seed]"""
import os, random, subprocess, sys, tempfile

runs = int(sys.argv[1]) if len(sys.argv) > 1 else 30
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
here = os.path.dirname(os.path.abspath(__file__))
exe = os.path.join(here, '..', 'build', 'dbg', 'tiepaper_dbg')
root = os.path.join(here, '..')
if not os.path.exists(exe):                      # build the range-checked binary on first use
    os.makedirs(os.path.join(root, 'build', 'dbg'), exist_ok=True)
    os.makedirs(os.path.join(root, 'build', 'units-dbg'), exist_ok=True)
    subprocess.run(['fpc', '-Mobjfpc', '-Sh', '-Cr', '-Ci', '-Co', '-O-', '-gl', '-FUbuild/units-dbg', '-Fusrc',
                    '-FEbuild/dbg', '-otiepaper_dbg', 'src/tiepaper.lpr'], cwd=root, check=True,
                   capture_output=True)
env = dict(os.environ, HOME='/tmp/pchome-fuzz', XDG_CONFIG_HOME='/tmp/pchome-fuzz/.config', SDL_VIDEODRIVER='dummy')

words = ['the', 'quick', 'brown', 'fox', '12.5', '(40)', '\\lm5:rm40', '\\ju on', '\\hd2:A,B,C', '\\fp', 'abc  def',
         '\\t=phrase', 'x' * 90, ' ', 'Zeta', '3.14159', '-7', '$1,200.50']
keys = ['return', 'backspace', 'delete', 'left', 'right', 'up', 'down', 'home', 'end', 'pageup', 'pagedown', 'tab',
        'insert', 'shift+return', 'shift+home', 'escape', 'f7', 'f6', 'shift+left', 'shift+right', 'shift+up',
        'shift+down', 'shift+end', 'shift+pageup', 'shift+pagedown', 'alt+a', 'alt+c', 'alt+x', 'alt+v',
        'alt+b', 'alt+i', 'alt+u', 'shift+delete', 'shift+insert', 'ctrl+insert', 'ctrl+shift+left',
        'ctrl+shift+home', 'ctrl+shift+end', 'ctrl+f6', 'ctrl+b']
ctrl = ['r', 't', 'c', 'd', 'e', 'q', 'p', 'm', 'k', 'y', 'shift+k', 'shift+c', 'shift+m', 'shift+s', 'shift+r',
        'shift+i', 'shift+d', 'shift+e', '=', 'shift+h', '.', 'shift+a', 'shift+q', 'shift+w', 'n', 'shift+l',
        '-', 'i', 'u', 'shift+2', 'f', 'h', 'v', 'z', 'shift+z', '+', 'home', 'end', 'up', 'down', 'left', 'right']
extra = ['return', 'y', 'n', '1', '5', 'x', '2', 'escape']

os.makedirs('/tmp/pchome-fuzz/.config', exist_ok=True)
os.makedirs('/tmp/pchome-fuzz/work', exist_ok=True)   # random Ctrl+S answers land here, not in the project
fails = 0
for r in range(runs):
    rnd = random.Random(seed * 1000 + r)
    lines = ['size %d %d' % (rnd.choice([500, 800, 1100]), rnd.choice([300, 500, 700]))]
    for _ in range(rnd.randint(40, 160)):
        c = rnd.random()
        if c < 0.35:
            lines.append('text ' + rnd.choice(words))
        elif c < 0.55:
            lines.append('key ' + rnd.choice(keys))
        elif c < 0.85:
            m = rnd.choice(ctrl)
            lines.append('key ctrl+' + m)
            # prompts and selection loops want a few follow-up events
            for _ in range(rnd.randint(0, 3)):
                e = rnd.choice(extra)
                lines.append(('key ' if e in ('return', 'escape') else 'text ') + e)
        elif c < 0.9:
            if rnd.random() < 0.5:
                x, y = rnd.randint(0, 600), rnd.randint(20, 300)
                lines.append(rnd.choice(['click', 'dclick', 'shiftclick']) + ' %d %d' % (x, y))
                lines.append('drag %d %d' % (rnd.randint(0, 600), rnd.randint(0, 340)))
                lines.append('release')
            else:
                lines.append('key escape')
        else:
            lines.append('text ' + rnd.choice(words))
    lines.append('dump /tmp/pchome-fuzz/last-dump.txt')
    lines.append('quit')
    with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False) as f:
        f.write('\n'.join(lines) + '\n')
        name = f.name
    p = subprocess.run([exe, '--script', name], env=env, cwd='/tmp/pchome-fuzz/work', capture_output=True, text=True, timeout=120)
    if p.returncode != 0:
        fails += 1
        keep = os.path.join(tempfile.gettempdir(), 'pc-fuzz-fail-%d-%d.txt' % (seed, r))
        os.replace(name, keep)
        print('run', r, 'exit', p.returncode, '->', keep)
        print((p.stdout + p.stderr)[-1500:])
    else:
        os.unlink(name)
print('%d runs, %d failures' % (runs, fails))
sys.exit(1 if fails else 0)
