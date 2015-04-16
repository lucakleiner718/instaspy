class Report
  include Mongoid::Document
  include Mongoid::Timestamps

  field :format, type: String
  field :input_data, type: String
  field :status, type: String
  field :progress, type: Integer, default: 0
  field :jobs, type: String
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :result_data, type: String
  field :notify_email, type: String

  def input
    @input
  end

  def input=input
    @input = input
  end

  def usernames
    self.input_csv.map{|r| r[0]}
  end

  def input_csv
    CSV.read(Rails.root.join('public', self.input_data))
  end

  def new?
    self.status.to_s == 'new'
  end

  def in_process?
    self.status.to_s == 'in_process'
  end

  def finished?
    self.status.to_s == 'finished'
  end

end
