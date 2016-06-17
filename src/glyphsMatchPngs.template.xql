xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=html5 media-type=text/html";

<html>
    <body>
        <table>
            <tr>
                <th>title</th>
                <th>tablet</th>
                <th>pics</th>
                <th>graph-el</th>
            </tr>{
for $x in collection('/db/cfdb-data/tablets/')//tei:TEI
let $title := $x//tei:fileDesc//tei:title
let $graphics := $x//tei:zone/tei:graphic/@url
let $collUri := util:collection-name($x)
let $glyph_coll := concat($collUri, '/_glyphs')
let $pics := xmldb:get-child-resources($glyph_coll)
return
    if (count($pics) eq count($graphics)) 
    then () 
    else <tr>
            <th>{$title}</th>
            <th>{$collUri}</th>
            <td>{count($pics)}</td>
            <td>{count($graphics)}</td>
        </tr>
        }</table>
</body>
    
</html>