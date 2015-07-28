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

    if $(this).val() == 'users'
      $('#report_output_data_last_media_date, #report_output_data_comments').closest('.checkbox').show()
    else
      $('#report_output_data_last_media_date, #report_output_data_comments').closest('.checkbox').hide()

    if $(this).val() == 'followers' || $(this).val() == 'followees'
      $('#report_output_data_slim, #report_output_data_slim_followers').closest('.checkbox').show()
    else
      $('#report_output_data_slim, #report_output_data_slim_followers').closest('.checkbox').hide()

    if $(this).val() == 'tags'
      $('#report_output_data_media_url, #report_output_data_all_media').closest('.checkbox').show()
    else
      $('#report_output_data_media_url, #report_output_data_all_media').closest('.checkbox').hide()


  $('#report_format').trigger('change')

  $('.report-info').popover
    trigger: 'hover'

  $('.report-update-status').on
    'ajax:success': (resp) ->
      window.location.reload()