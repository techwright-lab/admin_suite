# frozen_string_literal: true

require "test_helper"

class UserPreferenceTest < ActiveSupport::TestCase
  def setup
    @preference = build(:user_preference)
  end

  test "valid user_preference" do
    assert @preference.valid?
  end

  test "requires user" do
    @preference.user = nil
    assert_not @preference.valid?
    assert_includes @preference.errors[:user], "can't be blank"
  end

  test "requires unique user" do
    user = create(:user)
    # User already has a preference from after_create callback
    
    duplicate = build(:user_preference, user: user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user], "has already been taken"
  end

  test "validates preferred_view inclusion" do
    @preference.preferred_view = "invalid"
    assert_not @preference.valid?
    assert_includes @preference.errors[:preferred_view], "is not included in the list"
  end

  test "validates theme inclusion" do
    @preference.theme = "invalid"
    assert_not @preference.valid?
    assert_includes @preference.errors[:theme], "is not included in the list"
  end

  test "belongs to user" do
    user = create(:user)
    # User already has a preference, so let's use that one
    preference = user.preference
    
    assert_equal user, preference.user
  end

  test "#kanban_view? returns true for kanban" do
    @preference.preferred_view = "kanban"
    assert @preference.kanban_view?
  end

  test "#kanban_view? returns false for list" do
    @preference.preferred_view = "list"
    assert_not @preference.kanban_view?
  end

  test "#list_view? returns true for list" do
    @preference.preferred_view = "list"
    assert @preference.list_view?
  end

  test "#list_view? returns false for kanban" do
    @preference.preferred_view = "kanban"
    assert_not @preference.list_view?
  end

  test "#dark_mode? returns true for dark theme" do
    @preference.theme = "dark"
    assert @preference.dark_mode?
  end

  test "#dark_mode? returns false for light theme" do
    @preference.theme = "light"
    assert_not @preference.dark_mode?
  end

  test "#dark_mode? returns false for system theme" do
    @preference.theme = "system"
    assert_not @preference.dark_mode?
  end

  test "has correct VIEWS constant" do
    assert_equal ["kanban", "list"], UserPreference::VIEWS
  end

  test "has correct THEMES constant" do
    assert_equal ["light", "dark", "system"], UserPreference::THEMES
  end
end
