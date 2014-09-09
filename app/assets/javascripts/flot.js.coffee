#this is just a helper for demo purposes, so treat it like such
#it's just meant to give an example of how beautifully flot can be configured using our color helpers
$(document).on 'ready page:load', ->

  #cache the days helper here
  days = ['2.09','3.09','4.09','5.09','6.09','7.09','8.09','9.09']

  #the function that will generate the DEMO data
  randomData = -> _.map([0...days.length], (i) -> [i, parseInt((Math.floor(Math.random() * (1 + 20 - 10))) + 10)])

  #a number formatter function used in the axis labels
  roundFormatter = (val, axis) -> Math.round(val)
  noTextFormatter = -> ''

  $('.flot-transparent-line').each ->
    $el = $(this)

    #defaults for axis options
    axisOptions =
      useXAxisLines: true
      useXAxisLabels: true
      useYAxisLines: true
      useYAxisLabels: true

    #get them from data attributes
    #you can send a data-flot-no-AXIS-lines/labels attribute from the DOM
    #AXIS can be x or y, and either lines and/or labels (you can send both)
    #you can also send flot-no-lines/labels as a shortcut for not sending both axis
    #DEFAULT axis options are all true
    axisOptions.useXAxisLines = false if $el.data('flot-no-x-lines')? || $el.data('flot-no-lines')?
    axisOptions.useXAxisLabels = false if $el.data('flot-no-x-labels')? || $el.data('flot-no-labels')?
    axisOptions.useYAxisLines = false if $el.data('flot-no-y-lines')? || $el.data('flot-no-lines')?
    axisOptions.useYAxisLabels = false if $el.data('flot-no-y-labels')? || $el.data('flot-no-labels')?

    #prepare a random dataset. and a minimum for the vertical axis (if we dont set a minimum it seems to put the lines from a 0 offset and might look weird)
    #we use underscore to get the minimum value of the Y axis
    data = randomData()
    minY = _.min _.map data, (d) -> d[1]

    #we grab the line color from the element's data, or just default to white
    lineColor = '#fff'

    #make the semi transparent version. used for ticks and labels
    transparentLineColor = "rgba(255,255,255,0.3)"

    #build the x axis options
    xAxisOptions = {}
    xAxisOptions.tickColor = if axisOptions.useXAxisLines then transparentLineColor else 'transparent'

    if axisOptions.useXAxisLabels
      xAxisOptions.ticks = _.map(data, (d) -> [d[0], days[d[0]]])
      xAxisOptions.font = { color: lineColor }
    else
      xAxisOptions.tickFormatter = noTextFormatter

    #build the y axis options
    yAxisOptions =
      min: minY - 5
      ticks: 5

    yAxisOptions.tickColor = if axisOptions.useYAxisLines then transparentLineColor else 'transparent'

    if axisOptions.useYAxisLabels
      yAxisOptions.font = { color: lineColor }
      yAxisOptions.tickFormatter = roundFormatter
    else
      yAxisOptions.tickFormatter = noTextFormatter


    #aaaand the plot
    $.plot $el, [data: data],
      series:
        lines:
          show: true
          lineWidth: 2
          fill: true
          fillColor:
            colors: [
              { opacity: 0 }
              { opacity: 0 }
            ]

        points:
          radius: 3
          show: true
          fillColor: 'white'

        shadowSize: 0

      grid:
        hoverable: true
        clickable: true
        tickColor: transparentLineColor
        borderWidth: 0
        color: transparentLineColor

      colors: [lineColor]
      xaxis: xAxisOptions
      yaxis: yAxisOptions

      tooltip: true
      tooltipOpts:
        content: "%y.1MB/s"
        defaultTheme: false
        shifts:
          x: 0
          y: 20
