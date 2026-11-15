--- @diagnostic disable: duplicate-set-field
--- @diagnostic disable: missing-fields
--- @diagnostic disable: need-check-nil
--- @diagnostic disable: undefined-field
--- @diagnostic disable: assign-type-mismatch
--- @diagnostic disable: param-type-mismatch

local Test = require 'args.vendor.test'
local cli = require 'args'
local describe, it = Test.describe, Test.it
local assert = Test.assert

--- @param spec any
--- @param argv any
--- @return string
local function parse_error(spec, argv)
  return tostring(assert.raises(function() cli.parse(spec, argv) end))
end

describe('args', function()
  it(
    'returns an empty positionals list',
    function() assert.deep_equal(cli.parse({}, {}), { _ = {} }) end
  )

  it('parses a long boolean option', function()
    local spec = { ['--verbose'] = 'boolean' }
    assert.deep_equal(cli.parse(spec, { '--verbose' }), { _ = {}, ['--verbose'] = true })
    assert.deep_equal(cli.parse(spec, {}), { _ = {} })
  end)

  it('reads a separate string value', function()
    local spec = { ['--name'] = 'string' }
    assert.deep_equal(
      cli.parse(spec, { '--name', 'John Doe' }),
      { _ = {}, ['--name'] = 'John Doe' }
    )
  end)

  it('reads an inline string value', function()
    local spec = { ['--name'] = 'string' }
    assert.deep_equal(cli.parse(spec, { '--name=John Doe' }), { _ = {}, ['--name'] = 'John Doe' })
  end)

  it('reads an empty inline value', function()
    local spec = { ['--name'] = 'string' }
    assert.deep_equal(cli.parse(spec, { '--name=' }), { _ = {}, ['--name'] = '' })
  end)

  it('converts a number value', function()
    local spec = { ['--port'] = 'number' }
    assert.deep_equal(cli.parse(spec, { '--port', '1234' }), { _ = {}, ['--port'] = 1234 })
  end)

  it('rejects a non-numeric number value', function()
    local err = parse_error({ ['--port'] = 'number' }, { '--port', 'http' })
    assert.contains(err, 'expected a number for --port')
  end)

  it('rejects a value for a boolean option', function()
    local err = parse_error({ ['--verbose'] = 'boolean' }, { '--verbose=1' })
    assert.contains(err, 'option does not take a value: --verbose')
  end)

  it('rejects a missing string value', function()
    local err = parse_error({ ['--name'] = 'string' }, { '--name' })
    assert.contains(err, 'option requires argument: --name')
  end)

  it('rejects an unknown long option', function()
    local err = parse_error({}, { '--nope' })
    assert.contains(err, 'unknown or unexpected option: --nope')
  end)

  it('treats everything after -- as positionals', function()
    local spec = { ['--verbose'] = 'boolean' }
    assert.deep_equal(
      cli.parse(spec, { '--', '--verbose', 'file' }),
      { _ = { '--verbose', 'file' } }
    )
  end)

  it(
    'treats a lone dash as a positional',
    function() assert.deep_equal(cli.parse({}, { '-' }), { _ = { '-' } }) end
  )

  it('collects positionals', function()
    local spec = { ['--verbose'] = 'boolean' }
    assert.deep_equal(
      cli.parse(spec, { 'add', 'file.txt', '--verbose' }),
      { _ = { 'add', 'file.txt' }, ['--verbose'] = true }
    )
  end)

  it('parses a subcommand spec', function()
    local spec = {
      ['--verbose'] = 'boolean',
      add = { ['--force'] = 'boolean' },
    }
    assert.deep_equal(cli.parse(spec, { '--verbose', 'add', '--force', 'file' }), {
      _ = {},
      ['--verbose'] = true,
      add = { _ = { 'file' }, ['--force'] = true },
    })
  end)

  it('nests subcommand specs', function()
    local spec = {
      remote = { add = { ['--fetch'] = 'boolean' } },
    }
    assert.deep_equal(cli.parse(spec, { 'remote', 'add', '--fetch', 'origin' }), {
      _ = {},
      remote = { _ = {}, add = { _ = { 'origin' }, ['--fetch'] = true } },
    })
  end)

  it('rejects an unknown command', function()
    local err = parse_error({ add = {} }, { 'remove' })
    assert.contains(err, 'unknown command: remove')
  end)

  it('does not inherit parent options', function()
    local err = parse_error({ ['--verbose'] = 'boolean', add = {} }, { 'add', '--verbose' })
    assert.contains(err, 'unknown or unexpected option: --verbose')
  end)

  it(
    'does not dispatch a command after --',
    function()
      assert.deep_equal(
        cli.parse({ add = {} }, { '--', 'add', '--force' }),
        { _ = { 'add', '--force' } }
      )
    end
  )

  it('reads a short boolean option', function()
    local spec = { ['-v'] = 'boolean' }
    assert.deep_equal(cli.parse(spec, { '-v' }), { _ = {}, ['-v'] = true })
  end)

  it('resolves a short alias to its canonical key', function()
    local spec = { ['--verbose'] = 'boolean', ['-v'] = '--verbose' }
    assert.deep_equal(cli.parse(spec, { '-v' }), { _ = {}, ['--verbose'] = true })
  end)

  it('resolves a transitive alias', function()
    local spec = {
      ['--name'] = 'string',
      ['--label'] = '--name',
      ['-n'] = '--label',
    }
    assert.deep_equal(cli.parse(spec, { '-n', 'notes' }), { _ = {}, ['--name'] = 'notes' })
  end)

  it('expands a short group of flags', function()
    local spec = { ['-a'] = 'boolean', ['-b'] = 'boolean', ['-c'] = 'boolean' }
    assert.deep_equal(
      cli.parse(spec, { '-abc' }),
      { _ = {}, ['-a'] = true, ['-b'] = true, ['-c'] = true }
    )
  end)

  it('takes the next argument for the last short option', function()
    local spec = { ['-a'] = 'boolean', ['-b'] = 'string' }
    assert.deep_equal(
      cli.parse(spec, { '-ab', 'value' }),
      { _ = {}, ['-a'] = true, ['-b'] = 'value' }
    )
  end)

  it('rejects a short value option in the middle of a group', function()
    local spec = { ['-a'] = 'boolean', ['-b'] = 'string', ['-c'] = 'boolean' }
    local err = parse_error(spec, { '-abc' })
    assert.contains(err, 'followed by another short argument')
  end)

  it('does not support attached short values', function()
    local err = parse_error({ ['-o'] = 'string' }, { '-ovalue' })
    assert.contains(err, 'followed by another short argument')
  end)

  it('rejects an unknown short option', function()
    local err = parse_error({ ['-v'] = 'boolean' }, { '-x' })
    assert.contains(err, 'unknown or unexpected option: -x')
  end)

  it('rejects a short option with no value', function()
    local err = parse_error({ ['-o'] = 'string' }, { '-o' })
    assert.contains(err, 'option requires argument: -o')
  end)

  it('collects repeated string values', function()
    local spec = { ['--tag'] = { 'string' } }
    assert.deep_equal(
      cli.parse(spec, { '--tag', 'a', '--tag=b' }),
      { _ = {}, ['--tag'] = { 'a', 'b' } }
    )
  end)

  it('collects repeated booleans', function()
    local spec = { ['--verbose'] = { 'boolean' }, ['-v'] = '--verbose' }
    assert.deep_equal(cli.parse(spec, { '-vvv' }), { _ = {}, ['--verbose'] = { true, true, true } })
  end)

  it('collects repeated aliased values', function()
    local spec = { ['--tag'] = { 'string' }, ['-t'] = '--tag' }
    assert.deep_equal(
      cli.parse(spec, { '-t', 'a', '-t', 'b' }),
      { _ = {}, ['--tag'] = { 'a', 'b' } }
    )
  end)

  it('keeps the last scalar value', function()
    local spec = { ['--name'] = 'string' }
    assert.deep_equal(
      cli.parse(spec, { '--name', 'a', '--name', 'b' }),
      { _ = {}, ['--name'] = 'b' }
    )
  end)

  it('accepts a negative number value', function()
    local spec = { ['--count'] = 'number' }
    assert.deep_equal(cli.parse(spec, { '--count', '-5' }), { _ = {}, ['--count'] = -5 })
  end)

  it('keeps a single short number option value', function()
    local spec = { ['-n'] = 'number' }
    assert.deep_equal(cli.parse(spec, { '-n', '5' }), { _ = {}, ['-n'] = 5 })
  end)

  it('counts a repeated short number option', function()
    local spec = { ['-n'] = 'number' }
    assert.deep_equal(cli.parse(spec, { '-nnn' }), { _ = {}, ['-n'] = 3 })
  end)

  it('counts a repeated short alias', function()
    local spec = { ['--count'] = 'number', ['-n'] = '--count' }
    assert.deep_equal(cli.parse(spec, { '-nnn' }), { _ = {}, ['--count'] = 3 })
  end)

  it('rejects an option-like string value', function()
    local err = parse_error({ ['--name'] = 'string' }, { '--name', '-x' })
    assert.contains(err, 'option requires argument: --name')
  end)

  it('rejects a non-table subcommand spec', function()
    local err = parse_error({ verbose = 'boolean' }, {})
    assert.contains(err, 'spec for verbose must be a table')
  end)

  it('rejects a non-string spec key', function()
    local err = parse_error({ [1] = 'boolean' }, {})
    assert.contains(err, 'invalid spec key: 1')
  end)

  it('rejects a subcommand named underscore', function()
    local err = parse_error({ ['_'] = {} }, {})
    assert.contains(err, 'command name must not be _')
  end)

  it('rejects a bare dash option', function()
    local err = parse_error({ ['-'] = 'boolean' }, {})
    assert.contains(err, 'invalid option name: -')
  end)

  it('rejects a double dash option', function()
    local err = parse_error({ ['--'] = 'boolean' }, {})
    assert.contains(err, 'invalid option name: --')
  end)

  it('rejects a multi-character short option', function()
    local err = parse_error({ ['-ab'] = 'boolean' }, {})
    assert.contains(err, 'short option must have one character: -ab')
  end)

  it('rejects an option name containing equals', function()
    local err = parse_error({ ['--name=x'] = 'string' }, {})
    assert.contains(err, 'option name must not contain =')
  end)

  it('rejects an invalid type', function()
    local err = parse_error({ ['--foo'] = 'array' }, {})
    assert.contains(err, 'invalid type for --foo: array')
  end)

  it('rejects an array type with the wrong length', function()
    local err = parse_error({ ['--foo'] = { 'string', 'number' } }, {})
    assert.contains(err, 'array type for --foo must have one element')
  end)

  it('rejects an alias to an undeclared option', function()
    local err = parse_error({ ['-v'] = '--verbose' }, {})
    assert.contains(err, 'alias -v does not resolve to a declared option')
  end)

  it('rejects an alias cycle', function()
    local err = parse_error({ ['-a'] = '-b', ['-b'] = '-a' }, {})
    assert.contains(err, 'alias cycle at')
  end)

  it('rejects a non-table spec', function()
    local err = parse_error('not a table', {})
    assert.contains(err, 'spec must be a table')
  end)

  it('rejects a non-table argv', function()
    local err = parse_error({}, 'not a table')
    assert.contains(err, 'argv must be a list of strings')
  end)

  it('rejects a non-string argument', function()
    local err = parse_error({}, { 1 })
    assert.contains(err, 'argument 1 must be a string')
  end)
end)
