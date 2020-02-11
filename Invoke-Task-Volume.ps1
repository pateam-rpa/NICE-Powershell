param(
[string]$solutionId, 
[string]$workflowId,
[string]$workflowName,
[string]$priority,
[int]$numberoftasks
)

$Logfile = $PSScriptRoot.Substring(0,3) + "\nice_systems\RTServer\logs\InvokerTaskScheduler.log"
$Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
$https = $true
$base = 'localhost:9200' 

#-file D:\nice_systems\RTServer\scripts\Invoke-Task-Volume.ps1 dproj_rbdioskBzs2bIrjNkhs0z $Project.workflowItem1_x5ii "Display name of project" 4 1

#testparam 
#$solutionId = 'dproj_rbdioskBzs2bIrjNkhs0z'
#$workflowId = '$Project.workflowItem1_x5ii'
#$workflowName = 'Display name of project' 
#$priority = 4
#$numberoftasks = 1


Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}





    $call = {
        param($verb, $params, $body)

        $uri = "http://$base"

        $headers = @{ 
            # No authorization needed when calling localhost
            # 'Authorization' = 'Basic ####'
       
        }

        Write-Host "`nCalling [$uri/$params]" -f Green
        if($body) {
            if($body) {
                Write-Host "BODY`n--------------------------------------------`n$body`n--------------------------------------------`n" -f Green
            }
        }

        $response = wget -Uri "$uri/$params" -method $verb -Headers $headers -ContentType 'application/json' -Body $body -UseBasicParsing
        $response.content
    }

    $put = {
        param($params,  $body)
        &$call "Put" $params $body
    }

    $post = {
        param($params,  $body)
        &$call "Post" $params $body
    }

    $get = {
        param($params)
        &$call "Get" $params
    }

    $delete = {
        param($params)
        &$call "Delete" $params
    }

    $cat = {
        param($json)

        &$get "_cat/indices?v&pretty"
    }

    $search = {
        param($index, $datatype, $json)


        &$get "$index/$datatype/_search?pretty&source=$json&source_content_type=application/json"
    }


function CheckIfAlreadyInvokedES {
param (
    [string]$taskName
)

try{ 
    $input = @"
{
    "query" : {
        "bool": {
            "must":  {"match": {"taskState": "active"}},
            "must":  {"match": {"taskName": "$taskName"}} 

        }
    }
    ,"size" : 100
    ,"_source" : ["taskState","createdTime","taskName","priority","taskStatus","queue"]
}
"@
    $result = &$search 'clients' 'ra_task' $input
    $jsonresult = convertfrom-json -InputObject $result
    $output = $jsonresult.hits.hits._source | format-table

    return @($output).Count
    }
catch{
    return $Error[0].Exception
    } 
}

$InvokedCount = CheckIfAlreadyInvokedES $workflowName
write-host $InvokedCount

if($InvokedCount.Gettype().name -eq 'MethodInvocationException'){
   LogWrite ($Stamp + " - SolutionId: " + $solutionId + " - WorkflowName: " + $workflowName + " - Error occurred: " + $InvokedCount)
}elseif($InvokedCount -eq 0) {
#$true
$headers = @{}
$headers.Add("Content-Type","application/json")
$headers.Add("Media-Type","application/json")

$myFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

if($https) { 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Uri = 'https://' + $myfqdn + ':7078/RTServer/rest/nice/rti/ra/invocations'
}else{
$Uri = 'http://' + $myfqdn + ':7077/RTServer/rest/nice/rti/ra/invocations'
}

$body = @"
{
  "requestMetaData": {
    "initiatorType": "THIRD_PARTY_APP",
    "initiatorId": "LocalhostInvocation",
    "businessData": [
      "Invoker"
    ]
  },
  "requestData": [
    {
      "workflowMetaData": {
        "solution": "$solutionId",
        "workflowId": "$workflowId",
        "workflowPriority": "$priority"
      },
      "workflowData": {
        "arguments": [
            { 
            "type" : "int",
            "value" : "$numberoftasks" 
            } 
        ]
      }
    }
  ]
}    
"@  

try{ 
$html = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body -ContentType "application/json" 

} 
catch { 
LogWrite ($Stamp + " - SolutionId: " + $solutionId + " - WorkflowName: " + $workflowName + " - Error occurred: " + $Error[0].Exception )
return;
}
LogWrite ($Stamp + " - Request ID: " + $html.requestId + " - " + $html.message)

}elseif($InvokedCount -gt 0) {
   LogWrite ($Stamp + " - SolutionId: " + $solutionId + " - WorkflowName: " + $workflowName + " - Was already invoked, skipping invocation")
}