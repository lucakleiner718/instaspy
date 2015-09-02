angular.module('scan', ['ngRoute']).controller('scanProfileController', ['$scope', '$http', '$timeout', ($scope, $http, $timeout) ->
  $scope.username = window.location.pathname.match(/^\/users\/scan\/(.*)$/)[1]
  $scope.website_wo_schema = ->
    if $scope.website
      $scope.website.replace(/^https?:\/\//, '')
    else
      null
  $scope.avg = {likes: null, comments: null}

  $scope.otherPieChart = 26

  updateDataWrapper = ->
    setTimeout ->
      $scope.updateData()
    , 5 * 1000

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
      followersBarsCharts = followersBars.highcharts()
      followersBarsCharts.series[0].setData newValue
      $('#followers-bars').closest('.panel').removeClass('ng-hide')



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

  $('.piechart.other-pie-chart .easypiechart').easyPieChart $scope.pieChartOptions

  pieChart2 = $('.piechart.other-pie-chart .easypiechart').data('easyPieChart')
  pieChart2.update($scope.otherPieChart)

])