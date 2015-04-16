class ReportAr < ActiveRecord::Base

  self.table_name = 'reports'

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
