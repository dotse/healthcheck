function(doc){
    var v4mx = 0;
    var v6mx = 0;
    var total = 0;
    
    if(doc.geoip){
        for each (e in doc.geoip){
            if(e.type == "mailserver") {
                total += 1;
                if (e.ipversion == "4" && e.code == "SE") {
                    v4mx += 1;
                } else if (e.ipversion == "6" && e.code == "SE") {
                    v6mx += 1;
                }
            }
        }
        
        emit(doc.testrun, [v6mx, v4mx, total]);
    }
}