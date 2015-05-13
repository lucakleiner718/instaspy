require 'rails_helper'

RSpec.describe "create new report", :type => :request do
  it "create new report" do

    expect(Report.all.size).to eq 0

    get "/reports/new"

    assert_select "form.new_report" do
      assert_select "select[name=?]", "report[format]"
      assert_select "textarea[name=?]", "report[input]"
      assert_select "input[name=?]", "report[notify_email]"
    end

    attrs = attributes_for(:report_followers)

    post "/reports", report: attrs

    expect(Report.all.size).to eq 1
    report = Report.first
    expect(report.format).to eq attrs[:format]
    expect(report.original_usernames.size).to eq 1
    expect(report.notify_email).to eq attrs[:notify_email]

    expect(response).to redirect_to(reports_path)
  end
end