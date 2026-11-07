# args.nvim

A tiny `arg`-style command-line parser for Lua.

Describe the options in a spec table, pass the argument vector, and read the
result:

```lua
local cli = require 'args'

local args = cli.parse({
  ['--verbose'] = 'boolean',
  ['-v'] = '--verbose',

  ['--name'] = 'string',
  ['-n'] = '--name',

  ['--port'] = 'number',
  ['--tag'] = { 'string' },
}, { '--verbose', '-n', 'notes', '--port=1234', '--tag', 'a', 'file.txt' })

-- args._ == { 'file.txt' }
-- args['--verbose'] == true
-- args['--name'] == 'notes'
-- args['--port'] == 1234
-- args['--tag'] == { 'a' }
```

A spec entry is one of four things:

- A type: `'boolean'`, `'string'`, or `'number'`.
- An array with one type, for repeated values: `{ 'string' }`.
- An alias string: `['-v'] = '--verbose'`.
- A subcommand: a nested spec under an unprefixed name, such as
  `add = { ['--force'] = 'boolean' }`.

Positionals are always returned in `_`. Within a level, options may appear
before, after, or between positionals. A command word selects its nested spec
and nests that level's result under the command name:

```lua
local args = cli.parse({
  ['--verbose'] = 'boolean',
  add = { ['--force'] = 'boolean' },
}, { '--verbose', 'add', '--force', 'file' })

-- args['--verbose'] == true
-- args.add._ == { 'file' }
-- args.add['--force'] == true
```

## Requirements

- A Lua 5.1 environment, such as LuaJIT
- Neovim 0.10 or newer for the test suite

The module itself calls no Neovim API, so a plugin, a standalone Lua script, or
a test helper can require it.

## Install

Clone the repository into a Neovim package directory:

```sh
git clone https://github.com/jrop/args.nvim \
  ~/.local/share/nvim/site/pack/dev/opt/args.nvim
```

The module is required as `args`:

```lua
local cli = require 'args'
```

## API

`cli.parse(spec, argv)` returns a table. Option keys keep their spec spelling,
and aliases write to the canonical spelling. Missing options are absent, `_` is
always present, and a selected command's key holds a nested table of the same
shape.

| Type      | Value                                   |
| --------- | --------------------------------------- |
| `boolean` | `true` when present                     |
| `string`  | the raw string                          |
| `number`  | the result of `tonumber`                |
| `{ type }` | a list of the converted values         |

A short number option repeated in one group counts its occurrences, so
`-nnn` stores `3`.

The parser is strict: unknown options, missing values, and non-numeric numbers
raise. It does not support short attached values (`-oFILE`), defaults, required
options, or help generation. Parent options are not inherited by a subcommand;
declare them in the command's spec to use them after the command name.

## Documentation

| I want to...                                  | Read                               |
| --------------------------------------------- | ---------------------------------- |
| Look up the spec, result, and errors           | [Reference](docs/reference.md)     |
| Alias options, repeat values, or dispatch      | [How-to guides](docs/how-to.md)    |
| Understand the parser's rules                  | [Explanation](docs/explanation.md) |

## Development

All tasks use `mise`:

```sh
mise run fmt          # format with stylua
mise run fmt:check    # check formatting
mise run lint         # type-check with emmylua_check
mise run test         # run busted under Neovim
mise run test:coverage
mise run ci           # fmt:check, lint, test
```

Initialize the busted type stubs after cloning:

```sh
git submodule update --init --recursive
```

## License

MIT License

Copyright (c) 2026 Jonathan Apodaca

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
