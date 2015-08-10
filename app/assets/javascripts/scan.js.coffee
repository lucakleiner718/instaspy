jQuery ($) ->
  followers_bars = $('#followers-bars')
  data = followers_bars.data('data')
  if data.length > 0
    followers_bars.highcharts
      colors: ["#90ee7e", "#7798BF", "#aaeeee", "#ff0066", "#eeaaee", "#55BF3B", "#DF5353", "#7798BF", "#aaeeee"]
      chart:
        type: 'column'
      title:
        text: 'Followers Analytics'
      xAxis:
        type: 'category',
      yAxis:
        min: 0
        allowDecimals: false
        title:
          text: 'Amount: <span style="font-size: 10px">{point.key}</span><br/>'
      legend:
        enabled: false
      tooltip:
        headerFormat: '<span style="font-size: 10px">Group: {point.key}</span><br/>'
        pointFormat: 'Amount: <b>{point.y} users</b>'
      series:
        [
          {
            name: 'Followers Analytics',
            data: data,
            dataLabels:
              enabled: true,
              color: '#FFFFFF',
              align: 'center',
              format: '{point.y}', # one decimal
              y: -5, # 10 pixels down from the top
          }
        ]
  else
    followers_bars.hide()