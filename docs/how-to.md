# How-to guides

## Parse flags and values

Declare each spelling with a type and read the canonical key:

```lua
local cli = require 'args'

local args = cli.parse({
  ['--verbose'] = 'boolean',
  ['--port'] = 'number',
  ['--name'] = 'string',
}, { '--verbose', '--port', '8080', '--name', 'notes' })

-- args._ == {}
-- args['--verbose'] == true
-- args['--port'] == 8080
-- args['--name'] == 'notes'
```

A missing option is absent, so test with `if args['--verbose'] then`.

## Alias a short option

Point a short spelling at the long one:

```lua
local args = cli.parse({
  ['--verbose'] = 'boolean',
  ['-v'] = '--verbose',
  ['--name'] = 'string',
  ['-n'] = '--name',
}, { '-v', '-n', 'notes' })

-- args['--verbose'] == true
-- args['--name'] == 'notes'
```

The result uses the canonical spelling, not the alias. Aliases may point to
other aliases.

## Collect repeated values

Wrap the type in an array:

```lua
local args = cli.parse({
  ['--tag'] = { 'string' },
}, { '--tag', 'a', '--tag=b', '--tag', 'c' })

-- args['--tag'] == { 'a', 'b', 'c' }
```

A repeated boolean collects `true` values. Use a local counter if the caller
needs a boolean count.

## Count a short number option

Repeat a short number option in one group to count its occurrences:

```lua
local args = cli.parse({
  ['-n'] = 'number',
}, { '-nnn' })

-- args['-n'] == 3
```

A single `-n` still takes the next word as its value, so the same option has
both uses.

## Add a subcommand

Give each command its own spec under an unprefixed key:

```lua
local args = cli.parse({
  ['--verbose'] = 'boolean',
  add = {
    ['--force'] = 'boolean',
  },
  remove = {},
}, { '--verbose', 'add', '--force', 'file' })

-- args['--verbose'] == true
-- args.add._ == { 'file' }
-- args.add['--force'] == true
```

The command word is consumed from the positionals and its result is nested
under its name, so test with `if args.add then`. Options before the command use
the parent spec, and options after it use the command's spec. A command spec may
declare its own subcommands.

At a level that declares commands, the first word that is not an option must be
one of those command names. Any other word raises `unknown command: <word>`, so
such a level has no ordinary positionals. `--` is the exception: it ends parsing
before a command is selected and keeps the remaining words as positionals.

## Nest subcommands

A command spec is a spec like any other, so it can declare commands of its own:

```lua
local args = cli.parse({
  remote = {
    ['--fetch'] = 'boolean',
    add = {
      ['--tags'] = { 'string' },
    },
  },
}, { 'remote', '--fetch', 'add', '--tags', 'v1', 'origin' })

-- args.remote['--fetch'] == true
-- args.remote.add['--tags'] == { 'v1' }
-- args.remote.add._ == { 'origin' }
```

Each command word consumes itself and passes the rest of the vector to the next
level, so the nesting follows the words in order. Options before a command use
that level's spec, and options after it use the child spec.

## Share an option with a subcommand

Options are not inherited, so declare an option in every spec that accepts it:

```lua
local spec = {
  ['--verbose'] = 'boolean',
  add = {
    ['--verbose'] = 'boolean',
    ['--force'] = 'boolean',
  },
}

local args = cli.parse(spec, { 'add', '--verbose', '--force' })

-- args.add['--verbose'] == true
-- args.add['--force'] == true
```

The two `--verbose` entries are separate options in separate results. Repeating
the declaration is what makes the option available after the command name.

## Dispatch on the selected command

The result has a key for each command that was selected, so use ordinary `if`
checks:

```lua
local args = cli.parse({
  add = {},
  remove = {},
}, { 'remove', 'file' })

if args.add then
  -- run add
elseif args.remove then
  -- run remove
end
```

A command key is present only when that command was selected, so an absent key
is the signal that the caller chose another command or none.

## Require a subcommand

The parser does not enforce a command, so check for one after parsing:

```lua
local args = cli.parse({
  add = {},
  remove = {},
}, {})

local selected = args.add or args.remove
if not selected then
  error('expected add or remove', 0)
end
```

Use the same check to print help or return a status when the caller requires a
command.

## Pass a negative number

A number option accepts a negative value after it:

```lua
local args = cli.parse({
  ['--offset'] = 'number',
}, { '--offset', '-5' })

-- args['--offset'] == -5
```

A string option rejects an option-like value, so use the inline form when the
value begins with a dash:

```lua
local args = cli.parse({
  ['--pattern'] = 'string',
}, { '--pattern=-foo' })

-- args['--pattern'] == '-foo'
```

## Handle parse errors

The parser raises on invalid input, so wrap it in `pcall` when the caller owns
the message:

```lua
local ok, args = pcall(cli.parse, spec, argv)
if not ok then
  io.stderr:write(('error: %s\n'):format(args))
  os.exit(1)
end
```

The message names the offending option. Help and version are ordinary boolean
options; the caller decides what to print.

## Test the parser

The suite runs under busted on Neovim's LuaJIT. Prepare the dependencies once,
then run one spec directly:

```sh
mise run test:prepare
mise exec -- busted spec/args_spec.lua
```

A test passes a spec and a literal argument vector:

```lua
it('collects tags', function()
  local args = cli.parse({
    ['--tag'] = { 'string' },
  }, { '--tag', 'a', '--tag', 'b' })

  assert.are.same({ _ = {}, ['--tag'] = { 'a', 'b' } }, args)
end)
```

## Publish a release

Publishing requires a clean working tree, a `v*` tag at `HEAD` that has already
been pushed, and an authenticated `gh` CLI. Create the tag and run the release
task:

```sh
git tag v0.1.0
git push origin v0.1.0
mise run release
```

The task runs `mise run ci`, copies `lua/args.lua` to the `args.lua` asset, and
writes `args.lua.sha256`. It checks the copied asset with plain Lua 5.1 before
uploading, then creates the GitHub release with generated notes.

The task refuses to publish when `HEAD` is not at a `v*` tag, the working tree
is dirty, or the remote tag does not exist. This publishes a public release, so
only a maintainer should run it.
