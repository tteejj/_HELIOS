# Test file for app-store service
# Run with: Invoke-Pester -Path .\tests\app-store.tests.ps1

BeforeAll {
    # Set up test environment
    $script:BasePath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
    
    # Import required modules
    Import-Module "$script:BasePath\modules\event-system.psm1" -Force
    Import-Module "$script:BasePath\modules\tui-framework.psm1" -Force
    Import-Module "$script:BasePath\services\app-store.psm1" -Force
    
    # Initialize dependencies
    Initialize-EventSystem
    Initialize-TuiFramework
}

Describe "AppStore Service" {
    Context "Initialization" {
        It "should initialize with empty state" {
            # Arrange & Act
            $store = Initialize-AppStore
            
            # Assert
            $store | Should -Not -BeNullOrEmpty
            $store.GetState() | Should -BeOfType [hashtable]
        }
        
        It "should initialize with provided initial data" {
            # Arrange
            $initialData = @{
                counter = 0
                user = @{ name = "Test User" }
            }
            
            # Act
            $store = Initialize-AppStore -InitialData $initialData
            
            # Assert
            $store.GetState("counter") | Should -Be 0
            $store.GetState("user.name") | Should -Be "Test User"
        }
    }
    
    Context "State Management" {
        It "should update state via registered action" {
            # Arrange
            $store = Initialize-AppStore -InitialData @{ counter = 0 }
            
            $store.RegisterAction("INCREMENT", {
                param($Context)
                $current = $Context.GetState("counter")
                $Context.UpdateState(@{ counter = $current + 1 })
            })
            
            # Act
            $result = $store.Dispatch("INCREMENT")
            
            # Assert
            $result.Success | Should -Be $true
            $store.GetState("counter") | Should -Be 1
        }
        
        It "should handle action with payload" {
            # Arrange
            $store = Initialize-AppStore -InitialData @{ counter = 0 }
            
            $store.RegisterAction("ADD", {
                param($Context, $Payload)
                $current = $Context.GetState("counter")
                $Context.UpdateState(@{ counter = $current + $Payload.Amount })
            })
            
            # Act
            $result = $store.Dispatch("ADD", @{ Amount = 5 })
            
            # Assert
            $result.Success | Should -Be $true
            $store.GetState("counter") | Should -Be 5
        }
        
        It "should return error for unregistered action" {
            # Arrange
            $store = Initialize-AppStore
            
            # Act
            $result = $store.Dispatch("UNKNOWN_ACTION")
            
            # Assert
            $result.Success | Should -Be $false
            $result.Error | Should -BeLike "*not registered*"
        }
    }
    
    Context "Subscriptions" {
        It "should notify subscribers on state change" {
            # Arrange
            $store = Initialize-AppStore -InitialData @{ value = "initial" }
            $notificationReceived = $false
            $newValue = $null
            
            $subId = $store.Subscribe("value", {
                param($data)
                $script:notificationReceived = $true
                $script:newValue = $data.NewValue
            })
            
            $store.RegisterAction("UPDATE_VALUE", {
                param($Context)
                $Context.UpdateState(@{ value = "updated" })
            })
            
            # Act
            $store.Dispatch("UPDATE_VALUE")
            
            # Assert
            $notificationReceived | Should -Be $true
            $newValue | Should -Be "updated"
            
            # Cleanup
            $store.Unsubscribe($subId)
        }
        
        It "should support nested path subscriptions" {
            # Arrange
            $store = Initialize-AppStore -InitialData @{
                user = @{ profile = @{ name = "Test" } }
            }
            
            $notified = $false
            $subId = $store.Subscribe("user.profile.name", {
                param($data)
                $script:notified = $true
            })
            
            $store.RegisterAction("UPDATE_NAME", {
                param($Context)
                $Context.UpdateState(@{ 
                    user = @{ profile = @{ name = "Updated" } }
                })
            })
            
            # Act
            $store.Dispatch("UPDATE_NAME")
            
            # Assert
            $notified | Should -Be $true
            
            # Cleanup
            $store.Unsubscribe($subId)
        }
    }
    
    Context "Middleware" {
        It "should execute middleware before actions" {
            # Arrange
            $store = Initialize-AppStore
            $middlewareExecuted = $false
            
            $store.AddMiddleware({
                param($Action, $Store)
                $script:middlewareExecuted = $true
                return $Action  # Pass through
            })
            
            $store.RegisterAction("TEST", { })
            
            # Act
            $store.Dispatch("TEST")
            
            # Assert
            $middlewareExecuted | Should -Be $true
        }
        
        It "should allow middleware to cancel actions" {
            # Arrange
            $store = Initialize-AppStore
            
            $store.AddMiddleware({
                param($Action, $Store)
                if ($Action.Type -eq "FORBIDDEN") {
                    return $null  # Cancel action
                }
                return $Action
            })
            
            $actionExecuted = $false
            $store.RegisterAction("FORBIDDEN", {
                $script:actionExecuted = $true
            })
            
            # Act
            $result = $store.Dispatch("FORBIDDEN")
            
            # Assert
            $result.Success | Should -Be $false
            $result.Error | Should -BeLike "*cancelled*"
            $actionExecuted | Should -Be $false
        }
    }
    
    Context "Time Travel (Debug Features)" {
        It "should maintain action history" {
            # Arrange
            $store = Initialize-AppStore -InitialData @{ value = 0 }
            
            $store.RegisterAction("SET_VALUE", {
                param($Context, $Payload)
                $Context.UpdateState(@{ value = $Payload })
            })
            
            # Act
            $store.Dispatch("SET_VALUE", 1)
            $store.Dispatch("SET_VALUE", 2)
            $store.Dispatch("SET_VALUE", 3)
            
            $history = $store.GetHistory()
            
            # Assert
            $history.Count | Should -Be 3
            $history[0].Action.Payload | Should -Be 1
            $history[1].Action.Payload | Should -Be 2
            $history[2].Action.Payload | Should -Be 3
        }
        
        It "should restore previous state" {
            # Arrange
            $store = Initialize-AppStore -InitialData @{ value = 0 }
            
            $store.RegisterAction("SET_VALUE", {
                param($Context, $Payload)
                $Context.UpdateState(@{ value = $Payload })
            })
            
            # Act
            $store.Dispatch("SET_VALUE", 1)
            $store.Dispatch("SET_VALUE", 2)
            $store.Dispatch("SET_VALUE", 3)
            
            $store.RestoreState(2)  # Go back 2 steps
            
            # Assert
            $store.GetState("value") | Should -Be 1
        }
    }
}

Describe "AppStore Integration" {
    Context "With Navigation Service" {
        It "should update navigation state" -Skip {
            # This would test integration with navigation service
            # Skipped as it requires full service setup
        }
    }
    
    Context "With UI Components" {
        It "should trigger component updates on state change" -Skip {
            # This would test integration with UI components
            # Skipped as it requires full UI setup
        }
    }
}

AfterAll {
    # Cleanup
    Remove-Module app-store -Force -ErrorAction SilentlyContinue
    Remove-Module tui-framework -Force -ErrorAction SilentlyContinue
    Remove-Module event-system -Force -ErrorAction SilentlyContinue
}
