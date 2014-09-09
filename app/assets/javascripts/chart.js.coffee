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
    title:
      text: 'New York Fashion Week tags'
    subtitle:
      text: 'Source: Instagram.com'
    xAxis:
      categories: categories
    yAxis:
      title:
        text: 'Temperature (°C)'
    plotOptions:
      line:
        dataLabels:
          enabled: true
        enableMouseTracking: true
    series: series