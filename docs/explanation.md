# Explanation

## One spec per level, one pass

The parser's input is a map from spelling to type, plus command names to nested
specs. An example is `['--verbose'] = 'boolean'`, which tells the parser that
`--verbose` is a flag and that its result key is `--verbose`. The spec also holds
aliases, so `['-v'] = '--verbose'` names the same option without a second
handler. An unprefixed key is a command, so `add = { ['--force'] = 'boolean' }`
gives `add` its own spec.

Parsing is one pass over `argv` at each level. Each word is classified as a long
option, a short option, the `--` terminator, a command word, or a positional. An
option is resolved through the alias map, converted to its type, and stored under
the canonical spelling. Positionals go into that level's `_` in order. At a level
that declares commands, the first positional word selects the command, is
consumed, and its parsed result is nested under the command's name.

There is no grammar tree, no step list, and no second collection phase. Each
level's spec is a flat map, and a command simply points at another flat map. That
is the `arg` model extended by nesting, and it is why the parser fits in a screen
or two.

## Commands scope their options

A command word is the first word that is not an option, and it must match a key
in the current spec. An example is `--verbose add --force file`: `--verbose` is
parsed by the parent spec, `add` selects the child spec, and `--force` and `file`
belong to it. The result nests, so the command's options cannot collide with the
parent's and each level has its own `_`.

Options are not inherited. An example is using a parent-only `--verbose` after
`add`: the child spec does not declare it, so the parser raises. Repeating the
option in the child spec is the explicit way to share it. A command spec may
declare further commands, which nest in the same way.

## Types are strings, repetition is an array

A type is a string, not a constructor. `'boolean'`, `'string'`, and `'number'`
are the closed set. An example is `['--port'] = 'number'`, which converts
`--port 8080` to the number `8080`.

Repetition is an array around one type. An example is
`['--tag'] = { 'string' }`, which appends every `--tag` value to one list. A
repeated boolean produces a list of `true` values. A repeated scalar type
without the array wrapper keeps the last value.

The strings keep the spec readable in Lua, where `String`/`Number` constructors
do not exist. The array wrapper is a single rule, not a separate `multiple`
flag.

## Aliases resolve to canonical keys

An alias is recognized by its leading `-`. An example is `['-n'] = '--name'`,
which lets `-n notes` write to `['--name']`. Aliases may point to other aliases,
so a chain resolves by following the map until it reaches a key with a type.

The result uses the canonical key, not the spelling the user typed. That keeps
the caller's lookup stable regardless of whether `-n`, `--label`, or `--name`
was used. A cycle is rejected before parsing, because the alias map would
otherwise loop forever.

## Short groups are conservative

A short word such as `-abc` splits into `-a`, `-b`, and `-c`. An example is
three boolean flags, which all become `true`. A short option that takes a value
must be the last character in its group, so `-ab value` works when `-b` takes a
value, but `-abc` fails when `-b` takes a value and `-c` follows.

Attached short values are not supported: `-oFILE` is not read as `-o` with the
value `FILE`. Only `-o FILE` works. This is the same trade as `arg`: dropping
attached values removes the ambiguity between a group and a value, and keeps the
short scanner small.

A short number option repeated in a group is a count, not a value request. An
example is `['-n'] = 'number'` with `-nnn`, which stores `3`; a single `-n`
still takes the next word as its value.

## Option-like values are guarded

A value option consumes the next word unless that word looks like another
option. An example is `--name --verbose`: the parser raises instead of silently
setting the name to `--verbose`. The exception is a number option with a numeric
word, so `--count -5` still works. Write `--name=-x` for a string value that
starts with a dash.

That guard is the one place the parser looks ahead with knowledge of the option
type. It is also why the next word is not treated as a value blindly: a typo
would otherwise produce a plausible but wrong result.

## Deliberately absent

The model has no defaults, required options, help generation, permissive mode,
stop-at-positional mode, command aliases, or custom reducers. Each one is a
policy the caller can add in ordinary code:

- Defaults: write `args['--port'] or 8080`.
- Required options: check `args['--name']` after parsing.
- A required command: check `args.add` after parsing.
- Help and version: declare boolean options and print in the caller.
- A boolean count: use a local counter or a list's length.

The parser handles the structural part -- typed options, aliases, repeated
values, commands, and positionals -- and leaves the rest to the caller. That
boundary is what keeps it small and versatile.
