extends SceneTree
## Headless translation-catalog extractor (ported from a-machine, adapted for Dark
## Corridor's GDScript content). Run with:
##
##   godot --headless --path . --script res://tools/extract_pot.gd
##
## Collects every translatable string, writes locale/messages.pot, then merges the
## result into each locale/*.po — preserving existing translations and dropping
## strings no longer present. No gettext / msgmerge dependency.
##
## Sources (Dark Corridor uses GDScript content defs, not data files — decision #23):
##   1. .gd   — tr('...') / tr("...") literals (UI + formatted strings)
##   2. .tscn — `text` / `tooltip_text` Control properties (static scene UI)
##   3. .gd   — `name_key = '...'` literals (item / enemy / status / encounter names,
##              displayed at runtime via tr(def.name_key))
##
## See docs/reference/localization.md.

const LOCALES: Array[String] = ['en']
const POT_PATH: String = 'res://locale/messages.pot'
const SCAN_DIR: String = 'res://src'

# Escape-aware string-body sub-patterns: any char that isn't the quote or a backslash, OR a
# backslash-escape (so an escaped quote `\'` stays inside the captured string instead of
# truncating it — `gd_escapes` then unfolds `\'`/`\"`/`\n`/`\t` to the real character).
const Q1: String = "(?:[^'\\\\]|\\\\.)*"    # single-quoted body
const Q2: String = "(?:[^\"\\\\]|\\\\.)*"   # double-quoted body

# Dev / throwaway hosts never ship to players — their text stays English.
const EXCLUDE_FILES: Array[String] = ['corridor_testbed', 'corridor_panel_example', 'combat_sandbox']
# Format specifiers / placeholders that aren't real copy.
const EXCLUDE_IDS: Array[String] = []

var _sources: Dictionary = {}       # msgid -> source label (first seen wins)
var _order: Array[String] = []      # discovery order (stable, readable .pot)


func _init() -> void:
  _collect_from_scripts_and_scenes()
  _write_pot()
  for locale: String in LOCALES:
    _merge_po('res://locale/%s.po' % locale, locale == 'en')
  print('[extract_pot] %d strings extracted across %d locale(s).' % [_order.size(), LOCALES.size()])
  quit()


func _add(msgid: String, source: String) -> void:
  if msgid.strip_edges().is_empty() or msgid == 'TODO':
    return
  if msgid in EXCLUDE_IDS:
    return
  for frag: String in EXCLUDE_FILES:
    if frag in source:
      return
  if _sources.has(msgid):
    return
  _sources[msgid] = source
  _order.append(msgid)


# --- Collection: walk src/ for .gd and .tscn ---------------------------------

func _collect_from_scripts_and_scenes() -> void:
  var files: Array[String] = []
  _walk(SCAN_DIR, files)
  for path: String in files:
    if path.ends_with('.gd'):
      _scan_gd(path)
    elif path.ends_with('.tscn'):
      _scan_tscn(path)


func _walk(dir_path: String, out: Array[String]) -> void:
  var dir: DirAccess = DirAccess.open(dir_path)
  if dir == null:
    return
  dir.list_dir_begin()
  var name: String = dir.get_next()
  while name != '':
    var full: String = dir_path + '/' + name
    if dir.current_is_dir():
      if not name.begins_with('.'):
        _walk(full, out)
    elif name.ends_with('.gd') or name.ends_with('.tscn'):
      out.append(full)
    name = dir.get_next()
  dir.list_dir_end()


func _scan_gd(path: String) -> void:
  var text: String = FileAccess.get_file_as_string(path)
  var label: String = path.replace('res://', '')
  # tr('...') / tr("...") — the lookbehind avoids matching substr(, etc.
  _match_all(text, "(?<![A-Za-z0-9_])tr\\(\\s*'(%s)'" % Q1, label, true)
  _match_all(text, "(?<![A-Za-z0-9_])tr\\(\\s*\"(%s)\"" % Q2, label, true)
  # Single-literal player-facing def fields, each shown via tr(def.<field>):
  #   name_key (every def) · blurb_key (character select hook) · label_key (event option button).
  for field: String in ['name_key', 'blurb_key', 'label_key']:
    _match_all(text, "%s\\s*=\\s*'(%s)'" % [field, Q1], label, true)
    _match_all(text, "%s\\s*=\\s*\"(%s)\"" % [field, Q2], label, true)
  # event_prose_key (event body) may be split across lines as `'...' \ + '...'`; join the
  # segments so the msgid matches the concatenated string tr(def.event_prose_key) sees.
  _scan_joined(text, 'event_prose_key', label)


func _scan_tscn(path: String) -> void:
  var text: String = FileAccess.get_file_as_string(path)
  var label: String = path.replace('res://', '')
  # Control text + tooltip serialize as `... = "..."`.
  _match_all(text, "(?m)^(?:text|tooltip_text) = \"([^\"]*)\"", label)


## Collect a def field whose value may be a multi-segment single-quoted concatenation
## (`field = '...' \ + '...'`, the house single-quote style). Captures the whole segment chain
## and joins the pieces, so a translator gets one entry matching the concatenated runtime
## string (a single '...' value is just a chain of one).
func _scan_joined(text: String, field: String, label: String) -> void:
  var re: RegEx = RegEx.new()
  if re.compile("%s\\s*=\\s*((?:'(?:%s)'[\\s\\\\+]*)+)" % [field, Q1]) != OK:
    push_error('[extract_pot] bad regex for field: ' + field)
    return
  var seg: RegEx = RegEx.new()
  if seg.compile("'(%s)'" % Q1) != OK:
    push_error('[extract_pot] bad segment regex')
    return
  for m: RegExMatch in re.search_all(text):
    var joined: String = ''
    for sm: RegExMatch in seg.search_all(m.get_string(1)):
      joined += sm.get_string(1)
    joined = joined.replace('\\n', '\n').replace('\\t', '\t').replace("\\'", "'").replace('\\"', '"')
    _add(joined, label)


func _match_all(text: String, pattern: String, label: String, gd_escapes: bool = false) -> void:
  var re: RegEx = RegEx.new()
  if re.compile(pattern) != OK:
    push_error('[extract_pot] bad regex: ' + pattern)
    return
  for m: RegExMatch in re.search_all(text):
    var value: String = m.get_string(1)
    # .gd string literals keep escape sequences as literal text; turn them into the
    # real characters so the msgid matches what tr() sees at runtime.
    if gd_escapes:
      value = value.replace('\\n', '\n').replace('\\t', '\t').replace("\\'", "'").replace('\\"', '"')
    _add(value, label)


# --- Writing -----------------------------------------------------------------

func _escape(s: String) -> String:
  return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')


func _write_pot() -> void:
  var out: PackedStringArray = []
  out.append('# Dark Corridor - Translation Template')
  out.append('# Generated by tools/extract_pot.gd - do not edit by hand.')
  out.append('#')
  out.append('msgid ""')
  out.append('msgstr ""')
  out.append('"MIME-Version: 1.0\\n"')
  out.append('"Content-Type: text/plain; charset=UTF-8\\n"')
  out.append('"Content-Transfer-Encoding: 8bit\\n"')
  out.append('')
  for msgid: String in _order:
    out.append('#: %s' % _sources[msgid])
    out.append('msgid "%s"' % _escape(msgid))
    out.append('msgstr ""')
    out.append('')
  _save(POT_PATH, '\n'.join(out))


func _merge_po(path: String, is_english: bool) -> void:
  var existing: Dictionary = _parse_po_msgstrs(path)
  var header: String = _parse_po_header(path)
  var out: PackedStringArray = []
  out.append(header)
  for msgid: String in _order:
    var msgstr: String = existing.get(msgid, '')
    # The English catalog mirrors the source string for any new entry.
    if is_english and msgstr.is_empty():
      msgstr = msgid
    out.append('#: %s' % _sources[msgid])
    out.append('msgid "%s"' % _escape(msgid))
    out.append('msgstr "%s"' % _escape(msgstr))
    out.append('')
  _save(path, '\n'.join(out))


# Returns the header block (the msgid "" entry) verbatim, or a default.
func _parse_po_header(path: String) -> String:
  var text: String = FileAccess.get_file_as_string(path)
  var lines: PackedStringArray = text.split('\n')
  var header: PackedStringArray = []
  var started: bool = false
  for line: String in lines:
    var trimmed: String = line.strip_edges()
    if not started:
      if trimmed == 'msgid ""':
        started = true
        header.append(line)
      continue
    if trimmed.begins_with('msgstr') or trimmed.begins_with('"'):
      header.append(line)
    elif trimmed.is_empty():
      header.append('')
      break
    else:
      break
  if header.is_empty():
    return 'msgid ""\nmsgstr ""\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n'
  return '\n'.join(header)


# Returns msgid -> msgstr for all non-header entries (unescaped).
func _parse_po_msgstrs(path: String) -> Dictionary:
  var result: Dictionary = {}
  if not FileAccess.file_exists(path):
    return result
  var lines: PackedStringArray = FileAccess.get_file_as_string(path).split('\n')
  var cur_id: String = ''
  var cur_str: String = ''
  var mode: String = ''  # 'id' | 'str'
  for line: String in lines:
    var t: String = line.strip_edges()
    if t.begins_with('msgid '):
      if mode == 'str' and not cur_id.is_empty():
        result[_unescape(cur_id)] = _unescape(cur_str)
      cur_id = _strip_quotes(t.substr(6))
      cur_str = ''
      mode = 'id'
    elif t.begins_with('msgstr '):
      cur_str = _strip_quotes(t.substr(7))
      mode = 'str'
    elif t.begins_with('"'):
      if mode == 'id':
        cur_id += _strip_quotes(t)
      elif mode == 'str':
        cur_str += _strip_quotes(t)
  if mode == 'str' and not cur_id.is_empty():
    result[_unescape(cur_id)] = _unescape(cur_str)
  return result


func _strip_quotes(s: String) -> String:
  var t: String = s.strip_edges()
  if t.begins_with('"') and t.ends_with('"') and t.length() >= 2:
    return t.substr(1, t.length() - 2)
  return t


func _unescape(s: String) -> String:
  return s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')


func _save(path: String, content: String) -> void:
  var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
  if f == null:
    push_error('[extract_pot] cannot write ' + path)
    return
  f.store_string(content)
  f.close()
