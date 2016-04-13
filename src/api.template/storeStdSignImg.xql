xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";

import module namespace tablet="@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";
import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";

declare variable $data external;

declare function local:move-to-db($id as xs:string, $img-path as xs:string, $filename as xs:string, $mediatype as xs:string) as item() {
    let $log := util:log-app("INFO",$config:app-name, "local:move-to-db()")
    return
    if (some $p in ($id, $img-path, $filename, $mediatype) satisfies $p = "")
    then 
        let $log := util:log-app("INFO",$config:app-name, "local:move-to-db() some parameter is empty")
        return false()
    else system:as-user('cfdbSystem', 'sEN5)u#)~Tn!3E6ZkCW{J9e',
        try {
            let $segment := substring-after($img-path, "upload/"),
                $upload-directory := "/opt/exist/webapp/upload"
            let $file-path := $upload-directory||"/"||$segment
            let $extension := tokenize($filename,'\.')[last()]
            let $exists := file:exists($file-path)
            return
                if ($exists)
                then 
                    let $content := file:read-binary($file-path)
                    let $store :=  xmldb:store($config:data-root||"/etc/stdSigns/imgs", $id||"."||$extension ,$content, $mediatype)
                    let $img-collection := substring-before($segment,'/'||$filename)
(:                     beware, this is working on $EXIST_HOME, so be sure to delete the right directory :)
                    let $rm :=
                        if (contains($upload-directory,'/exist/webapp/upload'))
                        then
                            let $do-rm :=  file:delete($upload-directory||'/'||$img-collection||"/")
                            return 
                                if ($do-rm)
                                then util:log-app("INFO",$config:app-name,"removed temp directory  "||$upload-directory||'/'||$img-collection||"/")
                                else util:log-app("INFO",$config:app-name,"could not remove "||$upload-directory||'/'||$img-collection||"/")
                        else util:log-app("INFO",$config:app-name, "did not delete temp directory because $upload-directoy does not point to /exist/webapp/upload")
                    return $store
                else
                    let $log := util:log-app("INFO",$config:app-name,"file "||$file-path||" not found.")
                    return false()
                
        } catch * {
            let $log := util:log-app("INFO",$config:app-name, "local:move-to-db() something went wrong")
            return false()
        }
    )
};

let $input := util:parse($data),
    $img-path := util:unescape-uri($input/img/path/text(),"UTF-8"),
    $id := $input/img/xs:string(@id),
    $filename := $input/img/xs:string(@filename),
    $mediatype := $input/img/xs:string(@mediatype),
    $extension := tokenize($filename,'\.')[last()],
    $store-img := local:move-to-db($id, $img-path, $filename, $mediatype) 
    
return 
    if ($store-img)
    then 
        <img>
            {for $att in $input/img/@* 
            return attribute {name($att)} {""} }
            <path>{concat('imgs/',$id,'.',$extension)}</path>
            <message>ok</message>
        </img>
    else 
        <img>
            {for $att in $input/img/@* return attribute {name($att)} {""}}
            <path>{concat('imgs/',$id,'.',$extension)}</path>
            <message>an error occured</message>
        </img>

