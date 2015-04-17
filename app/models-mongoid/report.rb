class Report
  include Mongoid::Document

  field :format, type: String
  field :original_input, type: String
  field :processed_input, type: String
  field :status, type: String
  field :progress, type: Integer, default: 0
  field :jobs, type: Hash, default: {}
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :result_data, type: String
  field :notify_email, type: String
  field :output_data, type: Array, default: []
  field :not_processed, type: Array, default: []
  field :steps, type: Array, default: []
  field :date_from, type: DateTime
  field :date_to, type: DateTime
  include Mongoid::Timestamps

  # probably not best way
  def id
    self.read_attribute(:id).to_s
  end

  def input
    @input
  end

  def input=input
    @input = input
  end

  def original_usernames
    self.original_csv.map{|r| r[0]}
  end
  alias :usernames :original_usernames

  def processed_ids
    self.processed_csv.map{|r| r[1]}
  end

  def original_csv
    CSV.read(Rails.root.join('public', self.original_input))
  end

  def processed_csv
    CSV.read(Rails.root.join('public', self.processed_input))
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

  def self.process_input data
    rows = data.split("\r\n").map{|el| el.split("\r")}.flatten.map{|el| el.split("\n")}.flatten
    csv_string = CSV.generate do |csv|
      rows.each do |row|
        csv << [row.strip.gsub(/\//, '')]
      end
    end

    csv_string
  end

end
