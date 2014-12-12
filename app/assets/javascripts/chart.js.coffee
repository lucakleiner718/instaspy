$(document).on 'ready page:load', ->
  chart_box = $('#chart')
  return false if chart_box.length == 0
#  data = chart_box.data('chart')
  tags = chart_box.data('tags')
  categories = chart_box.data('categories')
  amount_of_days = chart_box.data('amount_of_days')

  initial_series = []
  $.each tags, (index, tag) ->
    initial_series.push {
      name: tag,
#      data: $.map(v, (a, b) -> return a )
    }

  chart_box.highcharts
    chart:
      type: 'line'
      backgroundColor: 'transparent'
    title:
      text: 'Tags Chart ' + tags.join(', ')
    subtitle:
      text: 'Source: Instagram.com'
    xAxis:
      categories: categories
      lineColor: '#fff'
      tickColor: '#fff'
      labels:
        style:
          color: '#fff'
      title:
        text: 'Date (time in UTC)'
        style:
          color: '#fff'
    yAxis:
      title:
        text: 'Mentions'
        style:
          color: '#fff'
      labels:
        style:
          color: '#fff'
      lineColor: '#fff'
      tickColor: '#fff'
    plotOptions:
      line:
#        dataLabels:
#          enabled: true
        enableMouseTracking: true
      series:
        lineWidth: 4
    series: initial_series
    legend:
      itemStyle:
        color: '#fff'

#    colors: ['#ffffff', '#434348', '#90ed7d', '#f7a35c', '#8085e9',
#             '#f15c80', '#e4d354', '#8085e8', '#8d4653', '#91e8e1']
    colors: ['#058DC7', '#5EE63F', '#ED561B', '#DDDF00', '#24CBE5', '#64E572', '#FF9655', '#FFF263', '#6AF9C4']

  window.hc = chart_box.highcharts()

  $('body').on 'tag:update', (e, tag_name) ->

    $.ajax
      method: 'get'
      url: '/chart_tag_data',
      data:
        name: tag_name
        amount_of_days: amount_of_days
      dataType: 'json'
      success: (resp) ->
        $.each hc.series, (index, row) ->
          if row.name == resp.tag
            row.setData resp.data

        found = false
        $('.info-box tr').each ->
          if $(this).find('h5').text() == '#' + tag_name
            found = true
            $(this).find('h5').closest('tr').find('h3').text(resp.last_30_days)

        if !found
          tr = $('.info-box tr').first().clone()
          tr.appendTo($('.info-box tbody'))
          tr.find('h5').text('#' + tag_name)
          tr.find('h3').text(resp.last_30_days)
          tr.show()


  $('body').on 'tags:update', ->
    $.each tags, (index, tag_name) ->
      $('body').trigger('tag:update', tag_name)

  $('body').trigger 'tags:update'

  # update graph every 30 minutes
  setInterval ->
    $('body').trigger 'tags:update'
  , 30*60*1000