class_name DevArgs
extends RefCounted
## Reads the start-up arguments used by the dev tools (docs/systems/dev_tools.md). Every argument is
## looked for in both the engine arguments and the user arguments (after `--`), and a value can be
## written `--name=value` or `--name value`. Static, so an autoload can ask in its own `_ready`.

const SILENT_ARGS: Array[String] = ['--autotest', '--shot']


## The engine arguments followed by the user arguments.
static func all() -> PackedStringArray:
  return OS.get_cmdline_args() + OS.get_cmdline_user_args()


static func has(flag: String) -> bool:
  return flag in all()


## The value of `--name=value` or `--name value`, or `default` when the argument is absent or has
## no value.
static func value(name: String, default: String = '') -> String:
  return value_in(all(), name, default)


## Every value of a repeatable `--name=value` argument, in order.
static func values(name: String) -> PackedStringArray:
  return values_in(all(), name)


## Whether this process is an autotest or screenshot run, which plays no sound.
static func is_silent_run() -> bool:
  var args: PackedStringArray = all()
  for flag: String in SILENT_ARGS:
    if flag in args:
      return true
  return false


## `value` over a given argument list (the tests call this directly). A following argument that
## starts with `--` is another argument, not a value.
static func value_in(args: PackedStringArray, name: String, default: String = '') -> String:
  var prefix: String = name + '='
  for i in args.size():
    var arg: String = args[i]
    if arg.begins_with(prefix):
      return arg.substr(prefix.length())
    if arg == name:
      if i + 1 < args.size() and not args[i + 1].begins_with('--'):
        return args[i + 1]
      return default
  return default


static func values_in(args: PackedStringArray, name: String) -> PackedStringArray:
  var prefix: String = name + '='
  var found: PackedStringArray = []
  for arg: String in args:
    if arg.begins_with(prefix):
      found.append(arg.substr(prefix.length()))
  return found
