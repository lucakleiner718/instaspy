FactoryGirl.define do
  factory :media_first, class: Media do
    insta_id "902204182978359323_891079859"
  end

  factory :media2, class: Media do
    insta_id "712224782849997746_260820061"
  end

  factory :media_location, class: Media do
    insta_id "893493962470595324_25415261"
    location_lat 26.007230758666992
    location_lng -80.17822265625
  end
end