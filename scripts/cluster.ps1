try {
    Import-Module FailoverClusters -ErrorAction Stop

    $clusterResources = Get-ClusterResource | ForEach-Object {
        [PSCustomObject]@{
            name = $_.Name
            state = $_.State.ToString()
            ownerNode = $_.OwnerNode.Name
            resourceType = $_.ResourceType.Name
        }
    }

	$clusterNodes = Get-ClusterNode | ForEach-Object {
        [PSCustomObject]@{
            name = $_.Name
            state = $_.State.ToString()
        }
    }

    $cluster = Get-Cluster -ErrorAction Stop
	
    $output = [PSCustomObject]@{
        cluster = [PSCustomObject]@{
            name = $cluster.Name
        }
        nodes = $clusterNodes
        resources = $clusterResources
    }

    $json = $output | ConvertTo-Json
	Write-Output $json
}
catch {
    $errorOutput = [PSCustomObject]@{
        error = $_.Exception.Message
    }
	
    $json = $errorOutput | ConvertTo-Json
    Write-Output $json
}