Feature: Service Error Handling
  As a developer
  I want the backend to fail gracefully
  So that the UI can guide the user

  Scenario: Metadata search with missing API key
    Given an empty TMDB API key in settings
    When I perform a content search for "Inception"
    Then the system should raise an authentication error
    And the error message should mention "Settings"

  Scenario: Disk full during download
    Given a target disk with 0 bytes free
    When I start a YouTube download
    Then the download should fail with a "Disk Full" error
