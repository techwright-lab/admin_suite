# frozen_string_literal: true

require "test_helper"

class SkillTagTest < ActiveSupport::TestCase
  def setup
    @skill_tag = build(:skill_tag)
  end

  test "valid skill_tag" do
    assert @skill_tag.valid?
  end

  test "requires name" do
    @skill_tag.name = nil
    assert_not @skill_tag.valid?
    assert_includes @skill_tag.errors[:name], "can't be blank"
  end

  test "requires unique name" do
    create(:skill_tag, name: "Ruby")
    @skill_tag.name = "Ruby"
    assert_not @skill_tag.valid?
    assert_includes @skill_tag.errors[:name], "has already been taken"
  end

  test "normalizes name to titlecase" do
    @skill_tag.name = "  ruby on rails  "
    @skill_tag.save!
    assert_equal "Ruby On Rails", @skill_tag.name
  end

  test "has many interview_applications through application_skill_tags" do
    skill = create(:skill_tag)
    interview_applications = create_list(:interview_application, 3)
    skill.interview_applications << interview_applications
    
    assert_equal 3, skill.interview_applications.count
  end

  test "destroys dependent application_skill_tags" do
    skill = create(:skill_tag)
    interview_application = create(:interview_application)
    skill.interview_applications << interview_application
    
    join_id = skill.application_skill_tags.first.id
    skill.destroy
    
    assert_nil ApplicationSkillTag.find_by(id: join_id)
  end

  test ".by_category scope filters by category" do
    tech_category = create(:category, :skill_tag_category, name: "Technical #{SecureRandom.hex(4)}")
    soft_category = create(:category, :skill_tag_category, name: "Soft Skills #{SecureRandom.hex(4)}")
    tech = create(:skill_tag, category: tech_category)
    soft = create(:skill_tag, category: soft_category)
    
    results = SkillTag.by_category(tech_category.id)
    assert_includes results, tech
    assert_not_includes results, soft
  end

  test ".alphabetical scope orders by name" do
    z_skill = create(:skill_tag, name: "ZZZ Skill")
    a_skill = create(:skill_tag, name: "AAA Skill")
    
    results = SkillTag.alphabetical
    assert_equal a_skill.id, results.first.id
    assert_equal z_skill.id, results.last.id
  end

  test ".popular scope orders by interview application count" do
    popular = create(:skill_tag)
    unpopular = create(:skill_tag)
    
    create_list(:interview_application, 5).each { |i| i.skill_tags << popular }
    create_list(:interview_application, 2).each { |i| i.skill_tags << unpopular }
    
    results = SkillTag.popular
    assert_equal popular.id, results.first.id
  end

  test "#interview_application_count returns correct count" do
    skill = create(:skill_tag)
    create_list(:interview_application, 3).each { |i| i.skill_tags << skill }
    
    assert_equal 3, skill.interview_application_count
  end

  test ".find_or_create_by_name creates new skill" do
    skill = SkillTag.find_or_create_by_name("New Skill")
    
    assert skill.persisted?
    assert_equal "New Skill", skill.name
  end

  test ".find_or_create_by_name finds existing skill" do
    existing = create(:skill_tag, name: "Existing")
    
    skill = SkillTag.find_or_create_by_name("Existing")
    assert_equal existing.id, skill.id
  end

  test ".find_or_create_by_name normalizes name" do
    skill = SkillTag.find_or_create_by_name("  ruby on rails  ")
    assert_equal "Ruby On Rails", skill.name
  end
end
