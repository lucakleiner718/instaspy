angular.module('scan', ['ngRoute']).controller 'scanProfileController', ($scope, $http, $timeout) ->
  $scope.username = window.location.pathname.match(/^\/users\/scan\/(.*)$/)[1]
  $scope.website_wo_schema = ->
    if $scope.website
      $scope.website.replace(/^https?:\/\//, '')
    else
      null
  $scope.avg = {likes: null, comments: null}

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

  $scope.updateData()

  followersBars = $('#followers-bars')
  followersBars.highcharts
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
          data: [],
          dataLabels:
            enabled: true,
            color: '#FFFFFF',
            align: 'center',
            format: '{point.y}', # one decimal
            y: -5, # 10 pixels down from the top
        }
      ]

  $scope.$watch 'followersAnalytics', (new_value, old_value) ->
    update = false

    if new_value
      if old_value
        if new_value.toString() != old_value.toString()
          update = true
      else
        update = true

    if update
      followersBarsCharts = followersBars.highcharts()
      followersBarsCharts.series[0].setData new_value