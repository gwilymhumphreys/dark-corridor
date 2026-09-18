"""PreToolUse hook: refuse Godot runs that dump their whole output.

A headless GUT suite or AutoTest run prints thousands of lines, all of which
land in the agent's context. This hook allows a Godot invocation only when its
output is sent to a file or filtered through tail, head, grep or Select-String.
The tools/*.sh wrappers already do that.

Reads the hook payload on stdin, writes a deny decision on stdout, exits 0.
"""

import json
import re
import sys

# A Godot executable run as a command: at the start of the command or after a
# separator, optionally through PowerShell's call operator and a quote. The
# command position matters - a Godot command line quoted inside a script or a
# heredoc is text, not a run, and must not be refused.
INVOCATION = re.compile(
  r'(?:^|[\n;|(]|&&|\|\|)\s*&?\s*["\']?'
  r'(?:[A-Za-z]:[^\s"\']*[/\\])?[Gg]odot[^\s"\']*?(?:\.exe)?["\']?\s+-',
)

# Output is going somewhere other than the transcript.
FILTERED = re.compile(
  r'>\s*\S|\|\s*(tail|head|grep|rg|Select-String|Select-Object)\b',
  re.IGNORECASE,
)

WRAPPER = re.compile(r'tools/(gut|autotest|import|pot)\.sh', re.IGNORECASE)

REASON = (
  'This Godot run would print its whole output into the context. Use a wrapper '
  '- tools/gut.sh (GUT suite), tools/autotest.sh (headless run), '
  'tools/import.sh (reimport), tools/pot.sh (localization) - or redirect it '
  'yourself, for example: <command> > _temp/out.txt 2>&1; tail -20 _temp/out.txt'
)


def main() -> None:
  try:
    payload = json.load(sys.stdin)
  except (json.JSONDecodeError, ValueError):
    return

  if payload.get('tool_name') not in ('Bash', 'PowerShell'):
    return

  command = payload.get('tool_input', {}).get('command', '')
  if not INVOCATION.search(command):
    return
  if WRAPPER.search(command) or FILTERED.search(command):
    return

  json.dump({
    'hookSpecificOutput': {
      'hookEventName': 'PreToolUse',
      'permissionDecision': 'deny',
      'permissionDecisionReason': REASON,
    },
  }, sys.stdout)


main()
