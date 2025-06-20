# FILE: modules/exceptions.psm1
# PURPOSE: Defines the custom exception framework for PMC Terminal.

# 1. Base TUI Exception
# All our custom exceptions will inherit from this, so we can catch them generically.
class TuiException : System.Exception {
    [hashtable]$Data

    TuiException([string]$Message, [hashtable]$Data = @{}) : base($Message) {
        $this.Data = $Data
    }
}

# 2. Specific Exception Types
# These give us context about *where* and *why* the error occurred.

class ComponentRenderException : TuiException {
    ComponentRenderException([string]$Message, [hashtable]$Data = @{}) : base($Message, $Data) {}
}

class StateMutationException : TuiException {
    StateMutationException([string]$Message, [hashtable]$Data = @{}) : base($Message, $Data) {}
}

class NavigationException : TuiException {
    NavigationException([string]$Message, [hashtable]$Data = @{}) : base($Message, $Data) {}
}

class InitializationException : TuiException {
    InitializationException([string]$Message, [hashtable]$Data = @{}) : base($Message, $Data) {}
}


# Export the new classes so they are available globally after import.
