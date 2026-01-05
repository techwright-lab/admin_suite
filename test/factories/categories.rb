# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    kind { :job_role }

    trait :job_role_category do
      kind { :job_role }
    end

    trait :skill_tag_category do
      kind { :skill_tag }
    end

    trait :engineering do
      name { "Engineering" }
      kind { :job_role }
    end

    trait :product do
      name { "Product" }
      kind { :job_role }
    end

    trait :technical_skill do
      name { "Technical" }
      kind { :skill_tag }
    end

    trait :soft_skill do
      name { "Soft Skills" }
      kind { :skill_tag }
    end
  end
end


