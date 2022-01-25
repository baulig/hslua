local tasty = require 'tasty'

local assert = tasty.assert
local test = tasty.test_case
local group = tasty.test_group

return {
  group 'assertors'  {
    group 'error_matches' {
      test('succeeds if error matches', function ()
        assert.error_matches(
          function () error 'Futurama' end,
          'tura'
        )
      end),
      test('fails if function succeeds', function ()
        local success = pcall(assert.error_matches, function () end, '')
        assert.is_falsy(success)
      end)
    },

    group 'is_truthy' {
      test('zero is truthy', function() assert.is_truthy(0) end),
      test('true is truthy', function() assert.is_truthy(true) end),
      test('empty string is truthy', function() assert.is_truthy '' end),
    },

    group 'is_falsy' {
      test('false is falsy', function() assert.is_falsy(false) end),
      test('nil is falsy', function() assert.is_falsy(nil) end),
    },

    group 'is_true' {
      test('succeeds on `true`', function() assert.is_true(true) end),
      test('fails on 1', function()
        local success = pcall(assert.is_true, 1)
        assert.is_true(not success)
      end),
    },

    group 'is_false' {
      test('succeeds on `false`', function() assert.is_false(false) end),
      test('fails on nil', function()
        local success = pcall(assert.is_false, nil)
        assert.is_false(success)
      end),
    },

    group 'is_nil' {
      test('nil is nil', function () assert.is_nil(nil) end)
    },

    group 'are_equal' {
      test('equal strings', function () assert.are_equal('test', 'test') end)
    },

    group 'are_same' {
      test('numbers', function ()
        assert.are_same(1, 1)
      end),
      test('nil', function ()
        assert.are_same(nil, nil)
      end),
      test('table', function ()
        assert.are_same({2, 3, 5, 7}, {2, 3, 5, 7})
      end),
      test('unequal numbers', function ()
        assert.error_matches(
          function () assert.are_same(0, 1) end,
          "expected same values, got 0 and 1"
        )
      end),
      test('tables', function ()
        assert.error_matches(
          function () assert.are_same({}, {1}) end,
          "expected same values, got"
        )
      end),
    },
  },
  group 'access via subtable' {
    test('assert.is.truthy', function ()
      assert(assert.is.truthy == assert.is_truthy)
    end),
    test('assert.are.equal', function ()
      assert(assert.are.equal == assert.are_equal)
    end),
  },
}
