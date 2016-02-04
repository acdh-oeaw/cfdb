var cfdb = cfdb || {};

cfdb.archive = {};
cfdb.archive.create = function(version){
    var url = cfdb.url + "archive/" + version
    return $.ajax({
            url: url,
            data: null,
            method: "post",
            headers : {
                format: "json"
            },
            beforeSend: function(e){
                $('#input-create-snapshot.spinner').show();
            },
            complete: function(){
                $('#input-create-snapshot.spinner').hide();
            },
            success: function(response){
                var id = response.msg.archive.identifier,
                    title = response.msg.archive.title,
                    version = response.msg.archive.version,
                    issued = response.msg.archive.extra["date-formatted"],
                    size = response.msg.archive.extra["size-formatted"],
                    mdUrl = response.msg.archive.extra["md-url"],
                    zipUrl = response.msg.archive.extra["zip-url"],
                    filename = response.msg.archive.extra["md-filename"],
                    removable = response.msg.archive.extra.removable
                $('#no-snapshots-placeholder').remove();
                $('#snapshots > tbody').append("<tr data-snapshot-id='" + id + "' data-snapshot-title='" + title + "'>" +
                    "<td><a href='" + zipUrl + "'>" + title + "</a></td>" + 
                    "<td>" + version + "</td>" +
                    "<td>" + issued + "</td>" +
                    "<td>" + size + "</td>" + 
                    "<td><a href='" + mdUrl + "'><span class='label'>show</span></a></td>" +
                "</tr>")
                if (removable) {
                    $('#snapshots tbody tr:last').append("<td><a href='#' data-action='removeSnapshot'><i class='fa fa-times'></i></a></td>")
                }
            },
            error: function(jqXHR, textStatus, errorThrown){
                alert(textStatus + ": " + errorThrown);
            }
        })
};

cfdb.archive.remove = function(identifier){
    var url = cfdb.url + "archive/" + identifier,
        row = $('tr[data-snapshot-id="' + identifier + '"]'),
        title = row.attr("data-snapshot-title") 
    return $.ajax({
            url: url,
            data: null,
            method: "delete",
            headers : {
                format: "json"
            },
            beforeSend: function(e){
                var confirm = window.confirm("You are about to delete the snapshot " + title + ". Proceed? ");
                return confirm
            },
            complete: function(){
                true
            },
            success: function(response){
                var tbody = row.parent()
                row.remove();
                tbody.find("tr").length == 0 ? tbody.append('<tr id="no-snapshots-placeholder"><td colspan="6" style="text-align: center;"><i>No snapshots created so far.</i></td></tr>') : null   
            },
            error: function(jqXHR, textStatus, errorThrown){
                alert(textStatus + ": " + errorThrown);
            }
        })
};

$(document).ready(function(){
    $('#snapshots').on("click", "a[data-action = removeSnapshot]", function(e){
        e.preventDefault();
        var identifier = $(this).parents("tr").attr("data-snapshot-id");
        return cfdb.archive.remove(identifier);
    });
    $('form[id = input-create-snapshot]').on("submit",function(e){
        e.preventDefault();
        var version = $(this).serializeArray()[0].value;
        cfdb.archive.create(version);
    })
}); 