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
                    <th>sign_name</th>
                    <th>abz_number</th>
                    <th>meszl_number</th>
                    <th>image</th>
                </tr>
                {
    for $sign in doc("/db/@data.dir@/etc/stdSigns/stdSigns.xml")//tei:char
        return
            <tr>
                <td>{$sign/tei:charName}</td>
                <td>{data($sign/@n)}</td>
                <td>{$sign//tei:value}</td>
                <td>{concat(data($sign/@xml:id), ".bmp")}</td>
            </tr>
}
            </table>
        </div>
    </body>
</html>


