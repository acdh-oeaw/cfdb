xquery version "3.0";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=html5 media-type=text/html";


<html>
    <body>
        <div>
            <h1>check dates</h1>
            <p>a little overview of date-values related to the chosen glyph type <strong>{request:get-parameter("sign", "")}</strong></p>
            <p>
                <form method="get">
                    <select name="sign">
                    {for $charName in doc("/db/cfdb-data/etc/stdSigns/stdSigns.xml")//tei:charName
                    return
                        <option value="{$charName}">{$charName}</option>
                    }
                    </select>
                    <input type="submit"></input>
                </form>
            </p>
            <table>
                <tr>
                    <th>ID</th>
                    <th>calendar</th>
                    <th>notAfter</th>
                    <th>notBefore</th>
                    <th>period</th>
                    <th>date</th>
                </tr>
{
    let $sign := request:get-parameter("sign", "")
    let $glyphs := collection("/db/cfdb-data/tablets/")//tei:g[@type = $sign]
    for $x in $glyphs
    let $tablet := $x/ancestor::tei:TEI
    let $teiDate := $tablet//tei:date
        return
            <tr>
                <td>{data($tablet/@xml:id)}</td>
                <td>{data($teiDate/@calendar)}</td>
                <td>{data($teiDate/@notAfter)}</td>
                <td>{data($teiDate/@notBefore)}</td>
                <td>{data($teiDate/@period)}</td>
                <td>{$teiDate}</td>
            </tr>
}
            </table>
        </div>
    </body>
</html>