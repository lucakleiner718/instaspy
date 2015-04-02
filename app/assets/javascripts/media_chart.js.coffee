$(document).on 'ready page:load', ->
  media_chart = $('#media-chart')
  return false if media_chart.length == 0

  published = []
  $.each media_chart.data('published'), (index, row) ->
    published.push row[1]

  added = []
  $.each media_chart.data('added'), (index, row) ->
    added.push row[1]
  initial_series = [
    {
      name: 'Media published',
      data: published
    },
    {
      name: 'Media added',
      data: added
    }
  ]

  media_chart.highcharts
    chart:
      type: 'line'
      backgroundColor: 'transparent'
    title:
      text: 'Media Chart'
    subtitle:
      text: 'Source: Instagram.com'
    xAxis:
      categories: media_chart.data('keys')
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
        text: 'Amount'
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