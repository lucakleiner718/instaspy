window.highchart_themes =
  default:
    colors: ["#7cb5ec", "#f7a35c", "#90ee7e", "#7798BF", "#aaeeee", "#ff0066", "#eeaaee", "#55BF3B", "#DF5353", "#7798BF", "#aaeeee"]
    chart:
      backgroundColor:
        linearGradient: [0, 0, 500, 1000],
        stops: [
          [0, 'rgb(30, 219, 221)'],
          [1, 'rgb(25, 136, 191)']
        ]
      borderWidth: 0,
      plotBackgroundColor: null,
      plotShadow: false,
      plotBorderWidth: 0
    title:
      style:
        color: '#fff'
    xAxis:
      lineColor: '#fff'
      tickColor: '#fff'
      labels:
        style:
          color: '#fff'
      title:
        style:
          color: '#fff'
    yAxis:
      title:
        style:
          color: '#fff'
      labels:
        style:
          color: '#fff'
      lineColor: '#fff'
      tickColor: '#fff'
    legend:
      itemStyle:
        color: '#fff'


Highcharts.setOptions highchart_themes.default