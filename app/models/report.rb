class Report < ActiveRecord::Base

  attr_accessor :country, :state, :city
  
  scope :active, -> { where(:status.in => ['new', 'in_process']) }

  after_destroy :delete_data_files

  before_create do
    self.status = 'new'
  end

  after_create do
    if self.format != 'users-export'
      csv_string = Report.process_input @input
      filepath = "reports/reports_data/report-#{self.id}-original-input.csv"
      FileManager.save_file filepath, content: csv_string
      self.update_attribute :original_input, filepath
    end

    ReportProcessNewWorker.perform_async self.id
  end

  after_commit do
    if self.status_changed? && self.status == 'stopped'
      # ReportStopJobs.perform_async self.id
      @report.batches.each do |name, jid|
        Sidekiq::Batch.new(jid).invalidate_all
        Sidekiq::Batch.new(jid).status.delete
      end
      @report.batches = {}
    end
  end

  OUTPUT_DATA = [
    ['AVG Likes', 'likes'], ['AVG Comments', 'comments'], ['Location', 'location'], ['Feedly subscribers amount', 'feedly'],
    ['Last media date', 'last_media_date'], ['Slim (1k+ followers, with email)', 'slim'],
    ['Slim (1k+ followers)', 'slim_followers'], ['Media Image URL', 'media_url'], ['Include All Media', 'all_media'],
    ['Followers Analytics', 'followers_analytics']
  ]

  GOALS = [
    ['Followers', 'followers'], ['Followees', 'followees'], ['Users', 'users'], ['Tags', 'tags'],
    ['Recent Media', 'recent-media'], ['Users export', 'users-export']
  ]

  validates :format, presence: true, inclusion: { in: GOALS.map{|el| el[1]} }

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
    # CSV.read(Rails.root.join('public', self.original_input))
    CSV.parse(FileManager.read_file(self.original_input))
  end

  def processed_csv
    # CSV.read(Rails.root.join('public', self.processed_input))
    CSV.parse(FileManager.read_file(self.processed_input))
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
    rows = data.split(/\r\n|\r|\n/)
    csv_string = CSV.generate do |csv|
      rows.each do |row|
        csv << [row.strip.gsub(/\//, '')]
      end
    end

    csv_string
  end

  def original_input_url
    FileManager.file_url self.original_input
  end

  def result_data_url
    FileManager.file_url self.result_data
  end

  def input_amount
    if self.amounts['input'].blank?
      self.amounts['input'] = self.original_csv.size
      self.save
    end
    self.amounts['input']
  end

  private

  def delete_data_files
    self.data.each do |name, filepath|
      begin
        FileManager.delete_file filepath
      rescue => e
      end
    end
  end

end
