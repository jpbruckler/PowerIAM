---
document type: cmdlet
external help file: PowerIAM-Help.xml
HelpUri: ''
Locale: en-US
Module Name: PowerIAM
ms.date: 12/15/2024
PlatyPS schema version: 2024-05-01
title: Checkpoint-IamCache
---

# Checkpoint-IamCache

## SYNOPSIS

Caches user or group objects from Active Directory in the PowerShell
Universal cache.

## SYNTAX

### __AllParameterSets

```
Checkpoint-IamCache [[-Scope] <string[]>] [-Force] [-MemoryOnly] [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
  {{Insert list of aliases}}

## DESCRIPTION

Queries Active Directory for user or group information, depending on the
value provided to the item parameter.
The information cached depends
on the module settings for PowerIAM.Cache.User.Properties and
PowerIAM.Cache.Group.Properties.

When called, this will check the current lifetime remaining for the cache
specified with -Scope.
If the remaining lifetime is 10 minutes or less,
or if the -Force switch is provided, this will update the cache with
new information queried from Active Directory.

## EXAMPLES

### EXAMPLE 1

Checkpoint-IamCache -Scope User

Checks if the cache lifetime remaining for the user cache is less than
10 minutes, and if so overwrites the existing cache with data queried
from Active Directory.

## PARAMETERS

### -Force

Causes a new checkpoint be taken regardless of the lifetime remaining in
the current cache.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -MemoryOnly

{{ Fill MemoryOnly Description }}

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Scope

Either User or Group.
Sets the scope of objects to cache.

```yaml
Type: System.String[]
DefaultValue: "@('User', 'Group')"
SupportsWildcards: false
ParameterValue: []
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### [System.Collections.Hashtable]

{{ Fill in the Description }}

### System.Collections.Hashtable

{{ Fill in the Description }}

## NOTES

See about_PowerIAMSettings


## RELATED LINKS

{{ Fill in the related links here }}

