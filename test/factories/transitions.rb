FactoryBot.define do
  factory :transition do
    event { "MyString" }
    action { "MyString" }
    resource { nil }
    from_state { "MyString" }
    to_state { "MyString" }
  end
end
