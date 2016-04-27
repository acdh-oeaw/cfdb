xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace tablet="@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";
declare namespace functx = "http://www.functx.com";

(:script to delete all .xml files from each tablets/tablet_ collection which has not the same name as the collection :)

declare function functx:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;

declare function functx:substring-after-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {

   replace ($arg,concat('^.*',functx:escape-for-regex($delim)),'')
 } ;

declare function functx:substring-before-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {

   if (matches($arg, functx:escape-for-regex($delim)))
   then replace($arg,
            concat('^(.*)', functx:escape-for-regex($delim),'.*'),
            '$1')
   else ''
 } ;

for $doc in collection($config:tablets-root)//tei:TEI
let $docName := document-uri(root($doc))
let $path := functx:substring-before-last($docName, '/')
let $tabletCollection := functx:substring-after-last($path, '/')
let $fileName := functx:substring-after-last($docName, '/')

return
    if($fileName != concat($tabletCollection,'.xml'))
    then
(:        xmldb:remove($path,$fileName):)
        $fileName
    else
        ()