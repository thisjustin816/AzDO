Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDO -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDO.psm1" -Force
    }

    It 'should get feeds without specifying a project' {
        ( Get-AzDOPackageFeed ).Count | Should -BeGreaterThan 20
    }

    It 'should get feeds with specifying a project' {
        Get-AzDOPackageFeed -Project 'MyProject' | Should -Not -BeNullOrEmpty
    }

    It 'should get feeds with specifying multiple projects' {
        $projectFeeds = ( Get-AzDOPackageFeed -Project 'MyProject', 'MyProject' ).name -join ', '
        $projectFeeds | Should -Match 'MyProjectTestFeed'
        $projectFeeds | Should -Match 'MyProjectTestFeed'
    }

    It 'should get a single feed with a name specified' {
        $scmFeed = Get-AzDOPackageFeed -Name 'ScmFeed'
        $scmFeed.name | Should -Be 'ScmFeed'
        $scmFeed.Count | Should -Not -BeGreaterOrEqual 2
    }

    It 'should get a single feed in a project with a name specified' {
        $scmFeed = Get-AzDOPackageFeed -Name 'MyProjectTestFeed'
        $scmFeed.name | Should -Be 'MyProjectTestFeed'
        $scmFeed.Count | Should -Not -BeGreaterOrEqual 2
    }

    It 'should get a feed with each name specified' {
        Get-AzDOPackageFeed -Name 'ScmFeed', 'PulseFeed' | Should -HaveCount 2
    }

    It 'should warn if no feeds are found in the project' {
        Get-AzDOPackageFeed -Project 'Systems Engineering' | Should -BeNullOrEmpty
        Get-AzDOPackageFeed -Project 'Systems Engineering' 3>&1 | Should -Match ''
    }

    It 'should warn if no named feeds are found in a project' {
        Get-AzDOPackageFeed -Name MyFeed -Project MyProject 3>&1 |
            Should -Match 'found in .* for project'
    }
}
