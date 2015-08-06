$(document).on 'ready page:load', ->
  chart_box = $('#user-followers-chart')
  return false if chart_box.length == 0

  categories = []
  $.each chart_box.data('data'), (index, row) ->
    categories.push row[0]

  hc = chart_box.highcharts
    chart:
      type: 'line'
      backgroundColor: 'transparent'
#    title:
#      text: 'User ' + chart_box.data('username') + ' followers Chart'
#    subtitle:
#      text: 'Source: Instagram.com'
    xAxis:
      type: 'datetime'
      dateTimeLabelFormats:
        month: '%b \'%y'
        year: '%Y'
      lineColor: '#fff'
      tickColor: '#fff'
      labels:
        style:
          color: '#fff'
      title:
        text: 'Month'
        style:
          color: '#fff'
    yAxis:
      title:
        text: 'Followers amount'
        style:
          color: '#fff'
      labels:
        style:
          color: '#fff'
      lineColor: '#fff'
      tickColor: '#fff'
    plotOptions:
      line:
        enableMouseTracking: true
      series:
        lineWidth: 4
    series: [{ name: chart_box.data('username'), data: chart_box.data('data') }]
    legend:
      itemStyle:
        color: '#fff'

    colors: ['#058DC7', '#5EE63F', '#ED561B', '#DDDF00', '#24CBE5', '#64E572', '#FF9655', '#FFF263', '#6AF9C4']

#    rangeSelector:
#      selected: 1
