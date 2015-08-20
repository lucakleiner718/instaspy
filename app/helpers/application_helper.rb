module ApplicationHelper

  def sortable(column, title = nil)
    column = column.to_s
    title ||= column.titleize
    css_class = (column == sort_column) ? "current #{sort_direction}" : nil
    direction = (column == sort_column && sort_direction == "asc") ? "desc" : "asc"
    attrs = request.query_parameters
    attrs[:sort] = column
    attrs[:direction] = direction
    link_to title, attrs, {:class => css_class}
  end

  def output_data report
    elements = []
    elements << "Date from: #{report.date_from}"
    elements << "Date to: #{report.date_to}"
    elements << "Output data: #{report.output_data.size > 0 ? report.output_data.join(', ') : 'No extra fields'}"
    elements << "Amounts: #{report.amounts.inject([]){|ar, (k,v)| ar << "#{k.to_s.titleize}=#{v}"; ar}.join(', ')}"
    elements.join("<br>").html_safe
  end

end