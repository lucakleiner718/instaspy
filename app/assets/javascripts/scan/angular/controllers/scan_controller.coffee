angular.module('scan', ['ngRoute']).controller('scanProfileController', ['$scope', '$http', '$timeout', ($scope, $http, $timeout) ->
  $scope.username = window.location.pathname.match(/^\/users\/scan\/(.*)$/)[1]
  $scope.website_wo_schema = ->
    if $scope.website
      $scope.website.replace(/^https?:\/\//, '')
    else
      null
  $scope.avg = {likes: null, comments: null}
  $scope.updateTimeout = 30

  updateDataWrapper = ->
    setTimeout ->
      $scope.updateData()
    , $scope.updateTimeout * 1000

  $scope.updateData = ->
    $http.get("/users/scan/data/#{$scope.username}.json")
      .then (response) ->
        updateDataWrapper()

        $scope.profilePicture = response.data.profile_picture
        $scope.fullName = response.data.full_name
        $scope.website = response.data.website
        $scope.location = response.data.location
        $scope.avg.likes = response.data.avg_likes
        $scope.avg.comments = response.data.avg_comments
        $scope.followed_by = response.data.followed_by
        $scope.followersUpdatedAt = response.data.followers_updated_at
        $scope.popularFollowersPercentage = response.data.popular_followers_percentage
        $scope.followersAnalytics = response.data.followers_analytics
        $scope.email = response.data.email
        $scope.followersChart = response.data.followers_chart

  $scope.updateData()

  followersBars = $('#followers-bars')
  followersBars.highcharts
    colors: ["#90ee7e", "#7798BF", "#aaeeee", "#ff0066", "#eeaaee", "#55BF3B", "#DF5353", "#7798BF", "#aaeeee"]
    chart:
      type: 'column'
    title:
      text: false
    xAxis:
      type: 'category',
    yAxis:
      min: 0
      allowDecimals: false
      title:
        text: false
    legend:
      enabled: false
    tooltip:
      headerFormat: '<span style="font-size: 10px">Group: {point.key}</span><br/>'
      pointFormat: 'Amount: <b>{point.y} users</b>'
    series:
      [
        {
          name: 'Followers Analytics',
          data: [],
          dataLabels:
            enabled: true,
            color: '#FFFFFF',
            align: 'center',
            format: '{point.y}', # one decimal
            y: -5, # 10 pixels down from the top
        }
      ]

  $scope.$watch 'followersAnalytics', (newValue, oldValue) ->
    update = false

    if newValue
      if oldValue
        if newValue.toString() != oldValue.toString()
          update = true
      else
        update = true

    if update
      $('#followers-bars').closest('.panel').removeClass('ng-hide')
      followersBarsCharts = followersBars.highcharts()
      followersBarsCharts.series[0].setData newValue


  $scope.color =
    primary:    '#1BB7A0'
    success:    '#94B758'
    info:       '#56BDF1'
    infoAlt:    '#7F6EC7'
    warning:    '#F3C536'
    danger:     '#FA7B58'


  $scope.pieChartOptions =
    animate:
      duration: 1000
      enabled: true
    barColor: $scope.color.info
    trackColor: '#f9f9f9'
    scaleColor: '#dfe0e0'
    size: 180
    lineWidth: 20
    scaleLength: 0
    rotate: 0

  $('.piechart.popular-followers .easypiechart').easyPieChart $scope.pieChartOptions
  pieChart = $('.piechart.popular-followers .easypiechart').data('easyPieChart')
  $scope.$watch 'popularFollowersPercentage', (newValue, oldValue) ->
    panel = $('.piechart.popular-followers').closest('.panel')
    if newValue
      panel.removeClass('hide')
      pieChart.update(newValue)
    else
      panel.addClass('hide')


  $scope.profilePreparedness = 0
  $('.piechart.profile-preparedness .easypiechart').easyPieChart $scope.pieChartOptions
  pieChart2 = $('.piechart.profile-preparedness .easypiechart').data('easyPieChart')
  $scope.$watch 'profilePreparedness', (newValue, oldValue) ->
    panel = $('.piechart.profile-preparedness').closest('.panel')
    if newValue < 100
      panel.removeClass('hide')
      pieChart2.update(newValue)
    else
      panel.addClass('hide')


  followersChart = $('#followers-chart')
  followersChart.highcharts
    colors: ['#058DC7', '#5EE63F', '#ED561B', '#DDDF00', '#24CBE5', '#64E572', '#FF9655', '#FFF263', '#6AF9C4']
    chart:
      type: 'line'
    title:
      text: false
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
      title: false
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
      min: 0
    plotOptions:
      line:
        enableMouseTracking: true
      series:
        lineWidth: 4
    tooltip:
      headerFormat: '<span style="font-size: 10px">Month: {point.key}</span><br/>'
      pointFormat: 'Amount: <b>{point.y} users</b>'
    series: [{}]
    legend: false


  $scope.$watch 'followersChart', (newValue, oldValue) ->
    update = false

    if newValue
      if oldValue
        if newValue.toString() != oldValue.toString()
          update = true
      else
        update = true

    if update
      followersChart.closest('.panel').removeClass('ng-hide')
      followersChartHC = followersChart.highcharts()
      followersChartHC.series[0].setData newValue


  $scope.$watchGroup ['avg.likes', 'followersAnalytics', 'followed_by', 'location'], (newValues, oldValues, scope) ->
    prepared = 0
    $.each newValues, (index, value) ->
      prepared += 1 if value
    $scope.profilePreparedness = parseInt((prepared / newValues.length) * 100)

])