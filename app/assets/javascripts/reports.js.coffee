jQuery ($) ->
  $('.report_date_range').datepicker
    maxDate: '0'

  $('#report_format').on 'change', ->
    if $(this).val() == 'tags'
      $('.report_date_from, .report_date_to').show()
    else
      $('.report_date_from, .report_date_to').hide()

  $('#report_format').trigger('change')