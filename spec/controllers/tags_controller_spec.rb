require 'rails_helper'

RSpec.describe TagsController, type: :controller do

  describe "GET #index" do
    it 'should load tags page without tags' do
      get 'index'
      expect(response).to be_success
      expect(response).to have_http_status(200)
    end

    it 'should show tags table' do
      5.times { Tag.create(name: generate(:tag)) }

      get 'index'
      expect(response).to be_success
      expect(response).to have_http_status(200)

      expect(assigns(:tags).size).to eq 5
    end
  end

end
