$(document).on 'ready page:load', ->
  chart_box = $('#chart')
#  data = chart_box.data('chart')
  tags = chart_box.data('tags')
  categories = chart_box.data('categories')

  initial_series = []
  $.each tags, (index, tag) ->
    initial_series.push {
      name: tag,
#      data: $.map(v, (a, b) -> return a )
    }

  chart_box.highcharts
    chart:
      type: 'line'
      backgroundColor:
        linearGradient: [500, 0, 500, 500]
        stops: [
          [0, '#1edbdd'],
          [1, '#1ca3c8']
        ]
#      height: '100%'
    title:
      text: 'Fashion Week Tags'
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
        text: 'Date'
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
      dataType: 'json'
      success: (resp) ->
        $.each hc.series, (index, row) ->
          if row.name == resp.tag
            row.setData resp.data

  $('body').on 'tags:update', ->
    $.each tags, (index, tag_name) ->
      $('body').trigger('tag:update', tag_name)

  $('body').trigger 'tags:update'

  # update graph every 3 minutes
  setInterval ->
    $('body').trigger 'tags:update'
  , 3*60*1000