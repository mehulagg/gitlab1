FactoryBot.define do
  factory :package_tag, class: Packages::PackageTag do
    package
    name "next"
  end
end
