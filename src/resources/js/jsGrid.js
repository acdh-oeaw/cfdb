$(document).ready(function(){
        $("#jsGrid").jsGrid({
            width: "100%",
            height: "75%",
            
            filtering: true,
            editing: false,
            sorting: true,
            paging: true,
            autoload: true,
            noDataContent: "no data retrieved",   
            controller: {
                loadData: function(filter) {
                    var d = $.Deferred();
                    $.ajax({
                        url: "/exist/restxq/cfdb/tablets" + filter.serialize(),
                        dataType: "json"
                        }).done(function(response) {
                        d.resolve(response.value);
                    });
                    
                    return d.promise();
                    /*return $.ajax({
                        type: "GET",
                        url: "/exist/restxq/cfdb/tablets",
                        data: filter,
                        dataType: "json"
                    });*/
                },
                insertItem: $.noop,
                updateItem: $.noop,
                deleteItem: $.noop
            },
            
            fields: [
                { name: "id", title: "Text", type: "text", autosearch: true},
                { name: "region", title: "Region", type: "text", autosearch: true },
                { name: "archive", title: "Archive", type: "text", autosearch: true },
                { name: "dossier", title: "dossier", type: "text", autosearch: true },
                { name: "scribe", title: "Scribe", type: "text", autosearch: true },
                { name: "city", title: "City", type: "text", autosearch: true },
                { name: "period", title: "Period", type: "text", autosearch: true },
                { name: "anteQuem", title: "Ante Quem", type: "text", autosearch: true },
                { name: "postQuem", title: "Post Quem", type: "text", autosearch: true },
                { name: "date", title: "Date",  type: "integer", autosearch: true },
                { name: "dateBabylonian", title: "Date (Babylonian)", type: "text", autosearch: true },
                { name: "ductus", title: "Ductus", type: "text", autosearch: true },
                { name: "editable", title: "editable", type: "text", autosearch: false },
                { type: "control", editButton: false, deleteButton: false }
            ]
        })
});