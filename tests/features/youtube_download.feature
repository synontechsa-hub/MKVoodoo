Feature: YouTube Download Workflow
  As a media collector
  I want to download videos from YouTube
  So that I can convert them for my mobile device

  Scenario: Successful metadata fetch
    Given a valid YouTube URL "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    When I request video information
    Then I should see the title "Never Gonna Give You Up"
    And I should see a valid thumbnail URL

  Scenario: Successful video download
    Given a valid YouTube URL "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    When I start the download process
    Then the final file path should be returned deterministically
    And the file should exist on disk
