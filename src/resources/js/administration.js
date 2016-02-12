var cfdb = cfdb || {};

cfdb.settings = {};
cfdb.settings.url = cfdb.url + "configuration"; 

cfdb.settings.set = function(load){
    return $.ajax({
            url : cfdb.settings.url,
            data : JSON.stringify(load),
            method : "PUT",
            contentType : "application/json",
            processDate: false,
            dataType : "json",
            success : function(response){
                /*check if every field has been stored correctly*/
                for(var name in load){
                    if (load[name] != response.payload[name]){
                        alert("ERROR: property " + name + ": value mismatch. form = " + load[name] + " vs. configuration = " + response.payload[name]);
                        return false
                    }
                }
                alert("Successfully saved configuration.");
            },
            error: function(jqXHR, textStatus, errorThrown){
                alert(textStatus + ": " + errorThrown);
            }
        })
};

$(document).ready(function(){
    $("form").on("submit", function(e){
       e.preventDefault();
       var array = $(this).serializeArray();
       load = {};
       $.each(
            $(this).serializeArray(), 
            function(i, e){
                load[e.name] = e.value;
            }
        )
       cfdb.settings.set(load);
    });
});