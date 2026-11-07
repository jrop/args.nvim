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

Parent options are not inherited. Declare an option in the command spec to use
it after the command name.

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
