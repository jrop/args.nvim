--- @diagnostic disable: duplicate-set-field
--- @diagnostic disable: missing-fields
--- @diagnostic disable: need-check-nil
--- @diagnostic disable: undefined-field
--- @diagnostic disable: assign-type-mismatch
--- @diagnostic disable: param-type-mismatch

local cli = require 'args'

--- @param spec any
--- @param argv any
--- @return string
local function parse_error(spec, argv)
  local ok, err = pcall(cli.parse, spec, argv)
  assert.is_false(ok, 'expected an error')
  return tostring(err)
end

describe('args', function()
  it(
    'returns an empty positionals list',
    function() assert.are.same({ _ = {} }, cli.parse({}, {})) end
  )

  it('parses a long boolean option', function()
    local spec = { ['--verbose'] = 'boolean' }
    assert.are.same({ _ = {}, ['--verbose'] = true }, cli.parse(spec, { '--verbose' }))
    assert.are.same({ _ = {} }, cli.parse(spec, {}))
  end)

  it('reads a separate string value', function()
    local spec = { ['--name'] = 'string' }
    assert.are.same({ _ = {}, ['--name'] = 'John Doe' }, cli.parse(spec, { '--name', 'John Doe' }))
  end)

  it('reads an inline string value', function()
    local spec = { ['--name'] = 'string' }
    assert.are.same({ _ = {}, ['--name'] = 'John Doe' }, cli.parse(spec, { '--name=John Doe' }))
  end)

  it('reads an empty inline value', function()
    local spec = { ['--name'] = 'string' }
    assert.are.same({ _ = {}, ['--name'] = '' }, cli.parse(spec, { '--name=' }))
  end)

  it('converts a number value', function()
    local spec = { ['--port'] = 'number' }
    assert.are.same({ _ = {}, ['--port'] = 1234 }, cli.parse(spec, { '--port', '1234' }))
  end)

  it('rejects a non-numeric number value', function()
    local err = parse_error({ ['--port'] = 'number' }, { '--port', 'http' })
    assert.is_truthy(err:find('expected a number for --port', 1, true), err)
  end)

  it('rejects a value for a boolean option', function()
    local err = parse_error({ ['--verbose'] = 'boolean' }, { '--verbose=1' })
    assert.is_truthy(err:find('option does not take a value: --verbose', 1, true), err)
  end)

  it('rejects a missing string value', function()
    local err = parse_error({ ['--name'] = 'string' }, { '--name' })
    assert.is_truthy(err:find('option requires argument: --name', 1, true), err)
  end)

  it('rejects an unknown long option', function()
    local err = parse_error({}, { '--nope' })
    assert.is_truthy(err:find('unknown or unexpected option: --nope', 1, true), err)
  end)

  it('treats everything after -- as positionals', function()
    local spec = { ['--verbose'] = 'boolean' }
    assert.are.same({ _ = { '--verbose', 'file' } }, cli.parse(spec, { '--', '--verbose', 'file' }))
  end)

  it(
    'treats a lone dash as a positional',
    function() assert.are.same({ _ = { '-' } }, cli.parse({}, { '-' })) end
  )

  it('collects positionals', function()
    local spec = { ['--verbose'] = 'boolean' }
    assert.are.same(
      { _ = { 'add', 'file.txt' }, ['--verbose'] = true },
      cli.parse(spec, { 'add', 'file.txt', '--verbose' })
    )
  end)

  it('parses a subcommand spec', function()
    local spec = {
      ['--verbose'] = 'boolean',
      add = { ['--force'] = 'boolean' },
    }
    assert.are.same({
      _ = {},
      ['--verbose'] = true,
      add = { _ = { 'file' }, ['--force'] = true },
    }, cli.parse(spec, { '--verbose', 'add', '--force', 'file' }))
  end)

  it('nests subcommand specs', function()
    local spec = {
      remote = { add = { ['--fetch'] = 'boolean' } },
    }
    assert.are.same({
      _ = {},
      remote = { _ = {}, add = { _ = { 'origin' }, ['--fetch'] = true } },
    }, cli.parse(spec, { 'remote', 'add', '--fetch', 'origin' }))
  end)

  it('rejects an unknown command', function()
    local err = parse_error({ add = {} }, { 'remove' })
    assert.is_truthy(err:find('unknown command: remove', 1, true), err)
  end)

  it('does not inherit parent options', function()
    local err = parse_error({ ['--verbose'] = 'boolean', add = {} }, { 'add', '--verbose' })
    assert.is_truthy(err:find('unknown or unexpected option: --verbose', 1, true), err)
  end)

  it(
    'does not dispatch a command after --',
    function()
      assert.are.same(
        { _ = { 'add', '--force' } },
        cli.parse({ add = {} }, { '--', 'add', '--force' })
      )
    end
  )

  it('reads a short boolean option', function()
    local spec = { ['-v'] = 'boolean' }
    assert.are.same({ _ = {}, ['-v'] = true }, cli.parse(spec, { '-v' }))
  end)

  it('resolves a short alias to its canonical key', function()
    local spec = { ['--verbose'] = 'boolean', ['-v'] = '--verbose' }
    assert.are.same({ _ = {}, ['--verbose'] = true }, cli.parse(spec, { '-v' }))
  end)

  it('resolves a transitive alias', function()
    local spec = {
      ['--name'] = 'string',
      ['--label'] = '--name',
      ['-n'] = '--label',
    }
    assert.are.same({ _ = {}, ['--name'] = 'notes' }, cli.parse(spec, { '-n', 'notes' }))
  end)

  it('expands a short group of flags', function()
    local spec = { ['-a'] = 'boolean', ['-b'] = 'boolean', ['-c'] = 'boolean' }
    assert.are.same(
      { _ = {}, ['-a'] = true, ['-b'] = true, ['-c'] = true },
      cli.parse(spec, { '-abc' })
    )
  end)

  it('takes the next argument for the last short option', function()
    local spec = { ['-a'] = 'boolean', ['-b'] = 'string' }
    assert.are.same(
      { _ = {}, ['-a'] = true, ['-b'] = 'value' },
      cli.parse(spec, { '-ab', 'value' })
    )
  end)

  it('rejects a short value option in the middle of a group', function()
    local spec = { ['-a'] = 'boolean', ['-b'] = 'string', ['-c'] = 'boolean' }
    local err = parse_error(spec, { '-abc' })
    assert.is_truthy(err:find('followed by another short argument', 1, true), err)
  end)

  it('does not support attached short values', function()
    local err = parse_error({ ['-o'] = 'string' }, { '-ovalue' })
    assert.is_truthy(err:find('followed by another short argument', 1, true), err)
  end)

  it('rejects an unknown short option', function()
    local err = parse_error({ ['-v'] = 'boolean' }, { '-x' })
    assert.is_truthy(err:find('unknown or unexpected option: -x', 1, true), err)
  end)

  it('rejects a short option with no value', function()
    local err = parse_error({ ['-o'] = 'string' }, { '-o' })
    assert.is_truthy(err:find('option requires argument: -o', 1, true), err)
  end)

  it('collects repeated string values', function()
    local spec = { ['--tag'] = { 'string' } }
    assert.are.same(
      { _ = {}, ['--tag'] = { 'a', 'b' } },
      cli.parse(spec, { '--tag', 'a', '--tag=b' })
    )
  end)

  it('collects repeated booleans', function()
    local spec = { ['--verbose'] = { 'boolean' }, ['-v'] = '--verbose' }
    assert.are.same({ _ = {}, ['--verbose'] = { true, true, true } }, cli.parse(spec, { '-vvv' }))
  end)

  it('collects repeated aliased values', function()
    local spec = { ['--tag'] = { 'string' }, ['-t'] = '--tag' }
    assert.are.same({ _ = {}, ['--tag'] = { 'a', 'b' } }, cli.parse(spec, { '-t', 'a', '-t', 'b' }))
  end)

  it('keeps the last scalar value', function()
    local spec = { ['--name'] = 'string' }
    assert.are.same({ _ = {}, ['--name'] = 'b' }, cli.parse(spec, { '--name', 'a', '--name', 'b' }))
  end)

  it('accepts a negative number value', function()
    local spec = { ['--count'] = 'number' }
    assert.are.same({ _ = {}, ['--count'] = -5 }, cli.parse(spec, { '--count', '-5' }))
  end)

  it('keeps a single short number option value', function()
    local spec = { ['-n'] = 'number' }
    assert.are.same({ _ = {}, ['-n'] = 5 }, cli.parse(spec, { '-n', '5' }))
  end)

  it('counts a repeated short number option', function()
    local spec = { ['-n'] = 'number' }
    assert.are.same({ _ = {}, ['-n'] = 3 }, cli.parse(spec, { '-nnn' }))
  end)

  it('counts a repeated short alias', function()
    local spec = { ['--count'] = 'number', ['-n'] = '--count' }
    assert.are.same({ _ = {}, ['--count'] = 3 }, cli.parse(spec, { '-nnn' }))
  end)

  it('rejects an option-like string value', function()
    local err = parse_error({ ['--name'] = 'string' }, { '--name', '-x' })
    assert.is_truthy(err:find('option requires argument: --name', 1, true), err)
  end)

  it('rejects a non-table subcommand spec', function()
    local err = parse_error({ verbose = 'boolean' }, {})
    assert.is_truthy(err:find('spec for verbose must be a table', 1, true), err)
  end)

  it('rejects a non-string spec key', function()
    local err = parse_error({ [1] = 'boolean' }, {})
    assert.is_truthy(err:find('invalid spec key: 1', 1, true), err)
  end)

  it('rejects a subcommand named underscore', function()
    local err = parse_error({ ['_'] = {} }, {})
    assert.is_truthy(err:find('command name must not be _', 1, true), err)
  end)

  it('rejects a bare dash option', function()
    local err = parse_error({ ['-'] = 'boolean' }, {})
    assert.is_truthy(err:find('invalid option name: -', 1, true), err)
  end)

  it('rejects a double dash option', function()
    local err = parse_error({ ['--'] = 'boolean' }, {})
    assert.is_truthy(err:find('invalid option name: --', 1, true), err)
  end)

  it('rejects a multi-character short option', function()
    local err = parse_error({ ['-ab'] = 'boolean' }, {})
    assert.is_truthy(err:find('short option must have one character: -ab', 1, true), err)
  end)

  it('rejects an option name containing equals', function()
    local err = parse_error({ ['--name=x'] = 'string' }, {})
    assert.is_truthy(err:find('option name must not contain =', 1, true), err)
  end)

  it('rejects an invalid type', function()
    local err = parse_error({ ['--foo'] = 'array' }, {})
    assert.is_truthy(err:find('invalid type for --foo: array', 1, true), err)
  end)

  it('rejects an array type with the wrong length', function()
    local err = parse_error({ ['--foo'] = { 'string', 'number' } }, {})
    assert.is_truthy(err:find('array type for --foo must have one element', 1, true), err)
  end)

  it('rejects an alias to an undeclared option', function()
    local err = parse_error({ ['-v'] = '--verbose' }, {})
    assert.is_truthy(err:find('alias -v does not resolve to a declared option', 1, true), err)
  end)

  it('rejects an alias cycle', function()
    local err = parse_error({ ['-a'] = '-b', ['-b'] = '-a' }, {})
    assert.is_truthy(err:find('alias cycle at', 1, true), err)
  end)

  it('rejects a non-table spec', function()
    local err = parse_error('not a table', {})
    assert.is_truthy(err:find('spec must be a table', 1, true), err)
  end)

  it('rejects a non-table argv', function()
    local err = parse_error({}, 'not a table')
    assert.is_truthy(err:find('argv must be a list of strings', 1, true), err)
  end)

  it('rejects a non-string argument', function()
    local err = parse_error({}, { 1 })
    assert.is_truthy(err:find('argument 1 must be a string', 1, true), err)
  end)
end)
