var cfdb = cfdb || {};

cfdb.archive = {};
cfdb.archive.url = cfdb.url + "archive";

cfdb.archive.create = function(version){
    var url =  cfdb.archive.url + "/" + version;
    return $.ajax({
            url: url,
            data: null,
            method: "post",
            headers : {
                format: "json"
            },
            beforeSend: function(e){
                $('#input-create-snapshot .spinner').show();
            },
            complete: function(){
                true
            },
            success: function(response){
                cfdb.archive.list();
                var newMin = parseInt(response.payload.archive.version) + 1;
                $('#version').attr("min", newMin);
                $('#version').val(newMin);
                $('#input-create-snapshot .spinner').hide();
            },
            error: function(jqXHR, textStatus, errorThrown){
                alert(textStatus + ": " + errorThrown);
            }
        })
};

/* deployes the snapshot specified by identifier */
cfdb.archive.deploy = function(identifier){
    var url = cfdb.archive.url + "/" + identifier;
    return $.ajax({
        url : url,
        data : null,
        method : "PUT",
        beforeSend : function(e){
            $('body, a').css({"cursor":"wait"});
        },
        success : function(response) {
            cfdb.archive.list();
            $('body, a').css({"cursor":"default"});
            alert("Successfully deployed archive ");
        },
        error: function(jqXHR, textStatus, errorThrown){
            alert(textStatus + ": " + errorThrown);
            $('body').css({"cursor":"default"});
        }
    })
};

/* deletes a snapshot specified by identifier */
cfdb.archive.remove = function(identifier){
    var url = cfdb.archive.url + "/" + identifier,
        row = $('tr[data-snapshot-id="' + identifier + '"]'),
        title = row.attr("data-snapshot-title");
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


/* deletes snapshot artefecats specified by identifier (without removing the archive itself) */
cfdb.archive.removeArtefacts = function(identifier){
    var url = cfdb.archive.url + "/artefacts/" + identifier,
        row = $('tr[data-snapshot-id="' + identifier + '"]'),
        title = row.attr("data-snapshot-title");
    return $.ajax({
            url: url,
            data: null,
            method: "delete",
            headers : {
                format: "json"
            },
            beforeSend: function(e){
                var confirm = window.confirm("You are about to delete the artefacts of snapshot " + title + ". Proceed? ");
                return confirm
            },
            complete: function(){
                true
            },
            success: function(response){
                cfdb.archive.list()
            },
            error: function(jqXHR, textStatus, errorThrown){
                alert(textStatus + ": " + errorThrown);
            }
        })
};

/* fetches the full HTML list of snapshots with the output of app:archivelist() */
cfdb.archive.list = function(){
    var url = cfdb.archive.url
    return $.ajax({
            url: url,
            data: null,
            method: "GET",
            headers : {
                format: "html"
            },
            success: function(response){
                $("#snapshots").parent("div").replaceWith(response.firstChild);   
            },
            error: function(jqXHR, textStatus, errorThrown){
                alert(textStatus + ": " + errorThrown);
            }
        })
};


var uploader = new plupload.Uploader({
    runtimes : 'html5,flash,silverlight,html4',
     
    browse_button : 'snapshot', // you can pass in id...
     
    url : cfdb.archive.url,
    multipart: false,
     
    filters : {
        mime_types: [
            {title : "Zip files", extensions : "zip"}
        ]
    },
 
    // Flash settings
    flash_swf_url : '/plupload/js/Moxie.swf',
 
    // Silverlight settings
    silverlight_xap_url : '/plupload/js/Moxie.xap',
     
 
    init: {
        PostInit: function() {
            document.getElementById('filelist').innerHTML = '';
 
            document.getElementById('uploadarchive').onclick = function() {
                uploader.start();
                $('.progress').show();
                $('#input-upload-snapshot .spinner').show();
                return false;
            };
        },
 
        FilesAdded: function(up, files) {
            plupload.each(files, function(file) {
                document.getElementById('filelist').innerHTML += '<div id="' + file.id + '">' + file.name + ' (' + plupload.formatSize(file.size) + ') <b></b></div>';
            });
        },
        
        FileUploaded: function(up, file, response) {
            $('#input-upload-snapshot .spinner').hide();
            var entry = document.getElementById(file.id);
            entry.parentNode.removeChild(entry);
            cfdb.archive.list();
            $('.progress').hide();
        },
        
 
        UploadProgress: function(up, file) {
            $('.progress .bar').css({
                'width' : file.percent + "%",
                'min-width' : file.percent + "%"
            }).html(file.percent + "%");
        },
        
        StateChanged: function(up) {
            if (up.state == 1) {
                $('#input-upload-snapshot .spinner').hide();
                $('.progress').hide();
            }
        },
 
        Error: function(up, err) {
            /*document.getElementById('console').innerHTML += "\nError #" + err.code + ": " + err.message;*/
            $('#input-upload-snapshot .spinner').hide();
            var entry = document.getElementById(err.file.id);
            entry.parentNode.removeChild(entry);
            window.alert(err.response);
        }
    }
});
 


$(document).ready(function(){
    $('#snapshots-container').on("click", "a[data-action = removeSnapshot]", function(e){
        e.preventDefault();
        var identifier = $(this).parents("tr").attr("data-snapshot-id");
        return cfdb.archive.remove(identifier);
    });
    $('#snapshots-container').on("click", "a[data-action = deploySnapshot]", function(e){
        e.preventDefault();
        var identifier = $(this).parents("tr").attr("data-snapshot-id");
        return cfdb.archive.deploy(identifier);
    });
    $('#snapshots-container').on("click", "a[data-action = remove-snapshot-artefacts]", function(e){
        e.preventDefault();
        var identifier = $(this).parents("tr").attr("data-snapshot-id");
        cfdb.archive.removeArtefacts(identifier);
    });
    $('form[id = input-create-snapshot]').on("submit",function(e){
        e.preventDefault();
        var version = $(this).serializeArray()[0].value;
        cfdb.archive.create(version);
    });
    uploader.init();
}); 