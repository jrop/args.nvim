# Reference

## `cli.parse(spec, argv)`

Parse an argument vector with an `arg`-style specification.

| Parameter | Type       | Meaning                                                     |
| --------- | ---------- | ----------------------------------------------------------- |
| `spec`    | `table`    | Option spelling to type, list, or alias; command to a spec. |
| `argv`    | `string[]` | Arguments after the program name.                           |

It returns one table per level. Option keys use their canonical spec spelling,
aliases write to the canonical key, missing options are absent, `_` always holds
that level's positionals, and a selected command nests its result under the
command name.

```lua
local cli = require 'args'

local args = cli.parse({
  ['--verbose'] = 'boolean',
  ['-v'] = '--verbose',
  ['--port'] = 'number',
}, { '-v', '--port=8080', 'file.txt' })

-- {
--   _ = { 'file.txt' },
--   ['--verbose'] = true,
--   ['--port'] = 8080,
-- }
```

## Spec entries

### Types

| Type      | Result                                    |
| --------- | ----------------------------------------- |
| `boolean` | `true` when the option is present         |
| `string`  | the raw string                            |
| `number`  | the result of `tonumber`                  |

An absent option contributes no key. A repeated scalar option keeps the last
value.

### Repeated values

Wrap one type in an array to collect every occurrence:

```lua
cli.parse({ ['--tag'] = { 'string' } }, { '--tag', 'a', '--tag=b' })
-- { _ = {}, ['--tag'] = { 'a', 'b' } }
```

The list is always present when the option appears. A repeated boolean produces
a list of `true` values.

### Aliases

A string beginning with `-` is an alias to another spec key:

```lua
{
  ['--verbose'] = 'boolean',
  ['-v'] = '--verbose',
  ['--label'] = '--name',
  ['--name'] = 'string',
}
```

Aliases resolve transitively. The result is stored under the final canonical
key, so `-v` writes to `['--verbose']` and `--label` writes to `['--name']`.

### Subcommands

A key that does not begin with `-` is a command name, and its value is that
command's spec:

```lua
local args = cli.parse({
  ['--verbose'] = 'boolean',
  add = {
    ['--force'] = 'boolean',
  },
}, { '--verbose', 'add', '--force', 'file' })

-- {
--   _ = {},
--   ['--verbose'] = true,
--   add = { _ = { 'file' }, ['--force'] = true },
-- }
```

The first word that is not an option selects the command and is consumed, so it
does not appear in `_`. The command's result nests under its name, with its own
`_`. Options before the command use the parent spec, and options after it use
the command's spec. A command spec may declare commands of its own.

When a spec declares commands and the first positional is not one of them,
parsing raises `unknown command: <word>`. A spec with commands may still be used
without one; the caller decides whether a command is required. The `--`
terminator ends parsing before a command is selected, so its remaining words stay
positionals at the current level.

## Command-line forms

- `--name` for a boolean option.
- `--name=value` or `--name value` for a string or number option.
- `-n` for a short option.
- `-abc` for a group of short options.
- `-o value` for a short option that takes a value.
- A command name as the first positional selects its nested spec.
- `--` to end option parsing; the remaining words become positionals and do not
  select a command.
- `-` is never an option; at a level without commands it is a positional.

Short options do not accept attached values: `-oFILE` is not supported. A short
option that takes a value must be the last option in its group, so
`-ab value` works when `-b` takes a value, but `-abc` fails when `-b` takes a
value and `-c` follows.

A short number option that is not wrapped in an array, repeated in one group,
counts its occurrences, so with `['-n'] = 'number'`, `-nnn` stores `3`. A single
`-n` still takes the next word as its value. A repeated group consumes no value,
so a word after it remains a positional.

A value option consumes the next word unless that word looks like another
option. The exception is a number option with a numeric word, so
`--count -5` works. Use `--name=-x` for a string value that begins with a dash.

## Result

| Key          | Value                                          |
| ------------ | ---------------------------------------------- |
| `_`          | this level's positionals in command-line order |
| spelling     | `true`, a string, a number, or a list          |
| command name | a nested result with the same shape            |

An absent boolean, string, or number option contributes no key. A repeated
option contributes a list. A selected command contributes a nested table.

## Errors

Parsing raises for:

- An unknown long or short option.
- A value passed to a boolean option.
- A missing value for a string or number option.
- A short value option that is not the last in its group.
- A non-numeric word for a number option.
- An unknown command when the spec declares commands.
- A non-string argument in `argv`.

Specification validation raises for:

- A spec that is not a table.
- A non-string or empty spec key.
- An option name that is `-` or `--`, or contains `=`.
- A short option that is not exactly one character after the dash.
- A command whose spec is not a table.
- A command named `_`.
- A type other than `boolean`, `string`, or `number`.
- An array type that does not contain exactly one type.
- An alias that does not resolve to a declared option.
- An alias cycle.

## Limits

- No short attached values (`-oFILE`).
- Options are not inherited. A parent option used after a command is unknown
  unless the command spec declares it.
- No command aliases. Command names are the spec keys.
- No defaults. Use `args['--port'] or 8080`.
- No required options or commands. Check `args['--name']` or `args.add` after
  parsing.
- No help generation.
- No permissive mode or stop-at-positional mode.
- No custom reducers. A spec entry is a type, a list, an alias, or a command
  spec.
- The parser does not print or exit; the caller owns help and version behavior.
