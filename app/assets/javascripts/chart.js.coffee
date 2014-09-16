$(document).on 'ready page:load', ->
  chart_box = $('#chart')
  data = chart_box.data('chart')
  categories = chart_box.data('categories')

  series = []
  $.each data, (k, v) ->
    console.log k
    series.push {
      name: k,
      data: $.map(v, (a, b) -> return a )
    }

  console.log series

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
#    plotOptions:
#      line:
#        dataLabels:
#          enabled: true
#        enableMouseTracking: true
    series: series
    legend:
      itemStyle:
        color: '#fff'

#    colors: ['#ffffff', '#434348', '#90ed7d', '#f7a35c', '#8085e9',
#             '#f15c80', '#e4d354', '#8085e8', '#8d4653', '#91e8e1']
    colors: ['#058DC7', '#50B432', '#ED561B', '#DDDF00', '#24CBE5', '#64E572', '#FF9655', '#FFF263', '#6AF9C4']