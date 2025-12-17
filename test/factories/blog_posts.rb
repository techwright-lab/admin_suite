FactoryBot.define do
  factory :blog_post do
    title { "MyString" }
    slug { "MyString" }
    excerpt { "MyText" }
    body { "MyText" }
    status { 1 }
    published_at { "2025-12-15 22:40:16" }
    author_name { "MyString" }
    tags { "MyString" }
  end
end
