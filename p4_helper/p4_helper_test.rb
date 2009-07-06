require 'test/unit'
require 'p4_helper'

class P4HelperTest < Test::Unit::TestCase
  include P4Helper # Needed since we're unit testing a module, not a class

  def setup
    # NOTE: We do not yet assume any contents of the depot.  When we do,
    # I have some code for populating test fixtures, although it leans a bit
    # toward Rails' conventions.  We can probably 'derail' it. :)

    # Specify the environment, e.g. development vs. test, etc.  It is assumed to be
    # test.  This is done mainly so that the right configuration is used for connecting to
    # Perforce.  This should probably be moved to a generic 'test_helper' which is
    # included in all tests.
    ENV['APP_ENV'] ||= 'test'
  end

  def teardown
  end

  def test_authenticate
    authenticate(p4_config['user_id'], p4_config['password'])
  end

  def test_authenticate_with_bad_password
    assert p4_config['password'] && p4_config['password'].strip != '' # Sanity check
    assert_raises P4AuthenticationException do
      authenticate(p4_config['user_id'], 'not_a_real_password')
    end
  end

  def test_authenticate_with_bad_user
    assert_raises P4AuthenticationException do
      authenticate('not_a_real_user', 'password_does_not_matter')
    end
  end

  def test_find_user_spec
    assert_not_nil find_user_spec(p4_config['user_id'], p4_config['password'])
    assert_nil find_user_spec(p4_config['user_id'], p4_config['password'], "notarealuser")
    assert_raise P4AuthenticationException do
      find_user_spec(p4_config['user_id'], "notarealpassword")
    end
  end

end
