xquery version "3.0";

import module namespace config="@app.uri@/config" at "modules/config.xqm";

let $target-base-default := "/opt/repo"
return 

<response>{
try{
    let $source  := request:get-parameter("source",$config:app-root)
    let $target-base := request:get-parameter("target-base",$target-base-default)
    let $cfdb :=  file:sync($source, $target-base||"/cfdb/sync", ()) 
    (:let $cfdb-data :=  file:sync($source||"/data", $target-base||"/cfdb-data", ())
    return ($cfdb,$cfdb-data):)
    return $cfdb
    
    
} catch * {
    let $log := util:log("ERROR", ($err:code, $err:description) )
    return <ERROR>{($err:code, $err:description)}</ERROR>
}
}</response>