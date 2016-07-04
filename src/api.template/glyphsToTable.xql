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
                    <th>identifier</th>
                    <th>tablet</th>
                    <th>sign</th>
                    <th>reading</th>
                    <th>context</th>
                    <th>note</th>
                    <th>image</th>
                </tr>
                {
    for $g in collection("/db/@data.dir@/tablets/")//tei:g
    let $id := data($g/@xml:id)
        return
            <tr>
                <td>{substring($id,7)}</td>
                <td>{$g/ancestor::tei:TEI//tei:title}</td>
                <td>{data($g/@type)}</td>
                <td>{$g}</td>
                <td>{$g/ancestor::tei:seg[1]}</td>
                <td>{$g/ancestor::tei:TEI//tei:note[@target=concat("#",$id)]}</td>
                <td>{concat(substring($id,7), ".png")}</td>
            </tr>
}
            </table>
        </div>
    </body>
</html>


