require "spec_helper"
require "amazon_credentials"

describe Amazon::Ecs do

  before(:all) do
    Amazon::Ecs.options = {
      :response_group => "Large",
      :associate_tag => AMAZON_ASSOCIATE_ID,
      :AWS_access_key_id => AMAZON_ACCESS_KEY_ID,
      :AWS_secret_key => AMAZON_SECRET_KEY
    }
  end
  describe ".item_search " do
    use_vcr_cassette "ruby"
    let(:response) { Amazon::Ecs.item_search('ruby') }
    let(:item) { response.items.first }

    context "response" do
      it "should respond_to " do
        response.should respond_to(:doc)
        response.should respond_to(:is_valid_request?)
        response.should respond_to(:has_error?)
        response.should respond_to(:error)
        response.should respond_to(:error_code)
        response.should respond_to(:items)
        response.should respond_to(:first_item)
        response.should respond_to(:item_page)
        response.should respond_to(:total_results)
        response.should respond_to(:total_pages)
      end

      it "should have items" do
        response.items.should_not be_empty
      end
    end

    context "item" do
      it "should respond_to" do
        item.should respond_to(:attributes)
        item.should respond_to(:asin)
        item.attributes.each do |key|
          item.should respond_to(key.to_sym)
          child = item.send(key)
          if !child.is_a?(String)
            if !child.is_a?(Array)
              child.should respond_to(:attributes)
            else
              child.each do |grandchild|
                if !grandchild.is_a?(String)
                  grandchild.should respond_to(:attributes)
                end
              end
            end
          end
        end
      end
    end
  end
end