jQuery ($) ->
  $('.report_date_range').datepicker
    maxDate: '0'

  $('#report_format').on 'change', ->
    if $(this).val() == 'tags'
      $('.report_date_from, .report_date_to').show()
    else
      $('.report_date_from, .report_date_to').hide()

    if ['followers', 'followees', 'tags', 'users'].indexOf($(this).val()) >= 0
      $('.report_output_data').show()
    else
      $('.report_output_data').hide()

    if $(this).val() == 'users'
      $('#report_output_data_last_media_date, #report_output_data_comments, #report_output_data_followers_analytics').closest('.checkbox').show()
    else
      $('#report_output_data_last_media_date, #report_output_data_comments, #report_output_data_followers_analytics').closest('.checkbox').hide()

    if $(this).val() == 'followers' || $(this).val() == 'followees'
      $('#report_output_data_slim, #report_output_data_slim_followers, #report_output_data_email_only').closest('.checkbox').show()
    else
      $('#report_output_data_slim, #report_output_data_slim_followers, #report_output_data_email_only').closest('.checkbox').hide()

    if $(this).val() == 'tags' || $(this).val() == 'recent-media'
      $('#report_output_data_media_url, #report_output_data_all_media').closest('.checkbox').show()
    else
      $('#report_output_data_media_url, #report_output_data_all_media').closest('.checkbox').hide()

    if $(this).val() == 'users-export'
      $('#report_input').closest('.form-group').hide()
      $('#report_country, #report_state, #report_city').closest('.form-group').show()
    else
      $('#report_input').closest('.form-group').show()
      $('#report_country, #report_state, #report_city').closest('.form-group').hide()


  $('#report_format').trigger('change')

  $('.report-info').popover
    trigger: 'hover'

  $('.report-update-status').on
    'ajax:success': (resp) ->
      window.location.reload()

  $('#new_report').on 'submit', ->
    $(this).find(':submit').attr('disabled', true)