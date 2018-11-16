sarit = {};
sarit.modules = {};
sarit.modules.transliterate = {};
sarit.modules.transliterate.transliterated = false;

sarit.modules.transliterate.transliterate_file = function() {
    if (sarit.modules.transliterate.transliterated === true) {
        sarit.modules.transliterate.transliterated = false;

        $(".content").html(sarit.modules.transliterate.original);        
    } else {
        var location = window.location;
        var relPath = location.pathname.replace(/^.*\/([^\/]+)$/, "$1");
        var params = "doc=" + relPath + "&" + location.search.substring(1);
        
        var container = $("#content-container");
       
        $.ajax({
            url: $("html").data("app") + "/modules/transliterate/transliterate-by-exist-id.xql",
            dataType: "json",
            data: params,
            error: function(xhr, status) {
                alert("Not found: " + params);
            },
            success: function(data) {
                if (data.error) {
                    alert(data.error);
                    return;
                }
                
                sarit.modules.transliterate.original = $(".content").html();
                sarit.modules.transliterate.transliterated = true;
                
                $(".content").html(data.content);
            }
        });        
    }
};
