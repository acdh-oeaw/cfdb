$(document).ready(function(){
        $("#jsGrid").jsGrid({
            width: "100%",
            
            autoload: true,
            
            filtering: true,
            sorting: true,
            editing: false,
            paging: true,
            
            controller: {
                loadData: function(filter) {
                    return $.ajax({
                        type: "GET",
                        url: "/exist/restxq/cfdb/tablets",
                        data: filter,
                        dataType: "json"
                    });
                },
                insertItem: $.noop,
                updateItem: $.noop,
                deleteItem: $.noop
            },
            // The list of fields is defined by tablet:get-attributes() 
            // field names have to be explicitly added to the REST endpoint defined in api.xqm   
            fields: [
                { name: "text", title: "Text", type: "text", autosearch: true, 
                    itemTemplate: function(value, item) {
                        if (item.editable == 1) {
                            return $("<a href='editTablets.html?t=" + value + "'>" + value + "</a>")
                        } {
                            return value
                        }
                        
                    }
                },
                { name: "region", title: "Region", type: "text", autosearch: true },
                { name: "archive", title: "Archive", type: "text", autosearch: true },
                { name: "dossier", title: "dossier", type: "text", autosearch: true },
                { name: "scribe", title: "Scribe", type: "text", autosearch: true },
                { name: "city", title: "City", type: "text", autosearch: true },
                { name: "period", title: "Period", type: "text", autosearch: true },
                { name: "anteQuem", title: "Ante Quem", type: "text", autosearch: true },
                { name: "postQuem", title: "Post Quem", type: "text", autosearch: true },
                { name: "date", title: "Date",  type: "number", autosearch: true },
                { name: "dateBabylonian", title: "Date (Babylonian)", type: "text", autosearch: true },
                { name: "ductus", title: "Ductus", type: "text", autosearch:true},
                { type: "control", editButton: false, deleteButton: false }
            ]
        })
});