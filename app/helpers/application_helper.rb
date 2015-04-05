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

end