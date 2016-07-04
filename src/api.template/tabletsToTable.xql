xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=html5 media-type=text/html";

<html>
    <head>
        <!-- Latest compiled and minified CSS -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" integrity="sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7" crossorigin="anonymous"></link>

<!-- Optional theme -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap-theme.min.css" integrity="sha384-fLW2N01lMqjakBkx3l/M9EahuwpSfeNvV63J5ezn3uZzapT0u7EYsXMjQV+0En5r" crossorigin="anonymous"></link>

<!-- Latest compiled and minified JavaScript -->
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous"></script>
    </head>
    <body>
        <div>
            <table class="table">
                <tr>
                    <th>text_reference</th>
                    <th>title</th>
                    <th>region</th>
                    <th>archive</th>
                    <th>dossier</th>
                    <th>cdli_no</th>
                    <th>nabucco_no</th>
                    <th>museum_no</th>
                    <th>place</th>
                    <th>place_information</th>
                    <th>scribe</th>
                    <th>period</th>
                    <th>date_not_after</th>
                    <th>date_not_before</th>
                    <th>babyloneian_time</th>
                    <th>ductus</th>
                    <th>text_type</th>
                    <th>content</th>
                    <th>distinctive_protagonists</th>
                    <th>bibliography</th>
                    <!--<th>glyphs</th>-->
                    <th>images</th>
                </tr>
                {
    for $tablet in collection("/db/@data.dir@/tablets/")//tei:TEI
        return
            <tr>
                <td class="text_reference">{$tablet//tei:titleStmt/tei:title/text()}</td>
                <td class="title">{$tablet//tei:titleStmt/tei:title/text()}</td>
                <td class="region">{$tablet//tei:msIdentifier/tei:region/text()}</td>
                <td class="archive">{$tablet//tei:collection[@type="archive"]/text()}</td>
                <td class="dossier">{$tablet//tei:collection[@type="dossier"]/text()}</td>
                <td class="cdli_no">{$tablet//tei:altIdentifier[@type="CDLI"]/tei:idno/text()}</td>
                <td class="nabucco_no">{$tablet//tei:altIdentifier[@type="NABUCCO"]/tei:idno/text()}</td>
                <td class="museum_no">{$tablet//tei:altIdentifier[@type="museumNumber"]/tei:idno/text()}</td>
                <td class="place">{$tablet//tei:placeName/text()}</td>
                <td class="place_information">{data($tablet//tei:placeName/@evidence)}</td>
                <td class="scribe">{$tablet//tei:persName/text()}</td>
                <td class="period">{data($tablet//tei:date[@calendar="#gregorian"]/@period)}</td>
                <td class="date_not_after">{data($tablet//tei:date[@calendar="#gregorian"]/@notAfter)}</td>
                <td class="date_not_before">{data($tablet//tei:date[@calendar="#gregorian"]/@notBefore)}</td>
                <td class="babyloneian_time">{$tablet//tei:date[@calendar="#babylonian"]/text()}</td>
                <td class="ductus">{data($tablet//tei:f[@name="ductus"]/tei:symbol/@value)}</td>
                <td class="text_type">{$tablet//tei:keywords[@scheme='local']/tei:term/text()}</td>
                <td class="content">{$tablet//tei:ab/text()}</td>
                <td class="distinctive_protagonists">{$tablet//tei:particDesc/tei:persName/text()}</td>
                <td class="bibliography">{for $bibl in $tablet//tei:surrogates/tei:listBibl/tei:bibl return if(exists($bibl/text())) then concat($bibl/text()," |") else ()}</td>
                <!--<td class="">{for $glyph in $tablet//tei:charDecl return data($glyph/tei:glyph/@xml:id)}</td>-->
                <td class="images">{data($tablet//tei:surface/tei:graphic/@url)}</td>
            </tr>
}
            </table>
        </div>
    </body>
</html>


