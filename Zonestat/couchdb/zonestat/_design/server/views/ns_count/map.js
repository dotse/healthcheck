function(doc){
    var v4ns = 0;
    var v6ns = 0;
    
    if(doc.geoip){
        for each (e in doc.geoip){
            if(e.type == "nameserver") {
                emit([doc.testrun, e.ipversion, e.address], 1);
            }
        }    
    }
}