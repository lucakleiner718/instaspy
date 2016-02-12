jQuery ($) ->
  $('.report_date_range').datepicker
    maxDate: '0'

  default_list = ['likes', 'location', 'feedly']
  all_abilities = {
    followees: default_list.concat(['slim', 'slim_followers', 'email_only']),
    followers: default_list.concat(['slim', 'slim_followers', 'email_only']),
    tags: default_list.concat(['media_url', 'all_media']),
    users: default_list.concat(['comments', 'last_media_date', 'followers_analytics']),
    'recent-media': ['media_url']
  }

  $('#report_format').on 'change', ->
    kind = $(this).val()
    abilities = all_abilities[kind]
    $('.report_output_data').toggle(!!abilities)

    $('.report_output_data > span.checkbox').hide()
    if abilities
      $.each abilities, (index, ability) ->
        $("#report_output_data_#{ability}").closest('.checkbox').show()

    $('.report_date_from, .report_date_to').toggle(kind == 'tags')

    $('#report_input').closest('.form-group').toggle(kind != 'users-export')
    $('#report_country, #report_state, #report_city').closest('.form-group').toggle(kind == 'users-export')


  $('#report_format').trigger('change')

  $('.report-info').popover
    trigger: 'hover'

  $('.report-update-status').on
    'ajax:success': (resp) ->
      window.location.reload()

  $('#new_report').on 'submit', ->
    $(this).find(':submit').attr('disabled', true)