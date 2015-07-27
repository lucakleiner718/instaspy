class Report < ActiveRecord::Base
  
  scope :active, -> { where(:status.in => ['new', 'in_process']) }

  after_destroy :delete_data_files

  validates :format, presence: true

  def delete_data_files
    self.data.each do |name, filepath|
      begin
        FileManager.delete_file filepath
      rescue => e
      end
    end
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
    "#{ENV['FILES_DIR']}/#{self.original_input}"
  end

  def result_data_url
    "#{ENV['FILES_DIR']}/#{self.result_data}"
  end

  def input_amount
    if self.amounts[:input].blank?
      self.amounts[:input] = self.original_csv.size
      self.save
    end
    self.amounts[:input]
  end

end
