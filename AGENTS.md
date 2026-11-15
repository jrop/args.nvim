# args.nvim - Agent Development Guide

## Project

`lua/args.lua` parses an argument vector with an `arg`-style specification
that is flat at each level. The module is a library, not a plugin: it calls no
Neovim API and does not print, exit, or read the host's arguments.

The public entry point is `cli.parse(spec, argv)`. The spec maps an option
spelling to a type, an array wrapping one type for repeated values, or another
spelling for an alias. A key that does not begin with `-` is a command name, and
its value is that command's spec. It returns a table whose keys are canonical
spellings, whose `_` field holds that level's positionals, and whose command key
holds a nested result. Invalid input raises a Lua error.

The parser does not model defaults, required options, help generation,
permissive mode, or stop-at-positional mode. The caller adds those in ordinary
code.

## Commands

All tasks use `mise`:

- `mise run fmt` - format with stylua
- `mise run fmt:check` - check formatting
- `mise run lint` - type-check with `emmylua_check` (warnings are errors)
- `mise run test` - run the specs under Neovim 0.12.6
- `mise run test:version [--coverage] <version>` - run the specs under one
  Neovim version, which mise installs first (`nightly` is refreshed when its tag
  moves)
- `mise run test:coverage` - run the 0.12.6 specs with line coverage of
  `lua/args.lua`
- `mise run ci` - `fmt:check` then `lint` then `test`
- `mise run release` - publish the current `v*` tag to GitHub (maintainers only)

The specs run on test.nvim's own runner, so the suite needs no Lua, luarocks,
or busted install. Run one spec file, or narrow by case name, by invoking the
vendored file directly:

```sh
mise exec -- nvim --clean -l lua/args/vendor/test.lua spec/args_spec.lua
mise exec -- nvim --clean -l lua/args/vendor/test.lua --filter 'alias'
```

## Architecture

- **`lua/args.lua`** - spec validation, alias resolution, short and long
  option scanning, type conversion, and result assembly.
- **`spec/args_spec.lua`** - black-box tests. Each case passes a spec and a
  literal argument vector and compares the result or catches the error.
- **`lua/args/vendor/test.lua`** - test.nvim (spec API, assertions, runner,
  and coverage), vendored by `nvim-bundle` from `nvim-bundle.json`. The file is
  generated and stylua-ignored, so change the pin and run `nvim-bundle install`
  rather than editing it. Specs import the spec API from it, i.e., `describe`,
  `it`, and `assert` are locals, not busted globals. Its `assert.deep_equal`
  takes `(got, want)`.

The spec is built into `aliases`, `handlers`, and `commands` before parsing, and
each command spec is built the same way. Parsing is one pass over `argv` per
level. Long options use `--name`, `--name=value`, and `--name value`; short
options split `-abc` into one-character options. A value-taking short option must
be last in its group, and attached short values (`-oFILE`) are not supported. A
short number option repeated in one group counts its occurrences (`-nnn` stores
`3`). The result stores values under the canonical spelling, so an alias never
creates a second key. A command word selects the matching command spec, consumes
that word, and nests the child result under the command name. Options are not
inherited by child specs.

## Supported behavior

- Types: `boolean`, `string`, and `number`.
- Repeated values: an array wrapping one type.
- Aliases, resolved transitively to a canonical key.
- Long options, short options, and short groups.
- A repeated short number option counts its occurrences (`-nnn`).
- Subcommands: an unprefixed key holding a nested spec, selected by the first
  positional word.
- `--` terminator; a lone `-` is never an option.
- Negative numbers as values for number options.
- A strict option-like value guard for separate values.
- `_` always present at every level for that level's positionals.

The deliberate limits are listed in `docs/reference.md`; keep that list and the
code in sync.

## Conventions

- LuaJIT; do **not** use goto.
- Stylua: single quotes, no call parentheses for simple statements, 2-space
  indent, 100-column width, sorted requires.
- The source disables `need-check-nil` and `param-type-mismatch` because the
  spec is validated before parsing and the lookups cannot miss.
- Keep each spec level flat. Commands nest specs; do not add a general grammar,
  combinators, or backtracking.
- Validate the spec before parsing: option names, command names, type
  definitions, alias resolution, alias cycles, and nested command specs.
- Invalid input raises with a short message. Do not reintroduce a status flag.
- Keep the canonical-key rule: aliases write to the declared spelling.
- Do not add features the caller can write in ordinary code (defaults,
  requiredness, help).
- The release task publishes `lua/args.lua` as the single-file `args.lua` asset
  plus an `args.lua.sha256` checksum. It refuses an untagged `HEAD`, a dirty
  tree, or a tag missing from the remote.

## Test environment

The suite runs host-side on test.nvim's runner under Neovim's LuaJIT. The tests are
black-box: they exercise only `cli.parse`, so an internal refactor that keeps
the public result unchanged must keep the suite green.

## Documentation

The documentation follows the four Diátaxis modes:

- **`README.md`** - the tutorial and front door. Keep it learning-oriented.
- **`docs/how-to.md`** - task-oriented recipes.
- **`docs/reference.md`** - spec entries, result shape, argument forms, errors,
  and limits.
- **`docs/explanation.md`** - why the parser uses a flat spec at each level and
  what it deliberately leaves to the caller.

Do not put implementation rationale in the README or how-to guide; link to the
explanation instead.
