jQuery ($) ->
  $('.report_date_range').datepicker
    maxDate: '0'

  $('#report_format').on 'change', ->
    if $(this).val() == 'tags' || $(this).val() == 'followers'
      $('.report_date_from, .report_date_to').show()
    else
      $('.report_date_from, .report_date_to').hide()

    if ['followers', 'followees', 'tags', 'users'].indexOf($(this).val()) >= 0
      $('.report_output_data').show()
    else
      $('.report_output_data').hide()


  $('#report_format').trigger('change')