function(doc){
    var v4ns = 0;
    var v6ns = 0;
    
    if(doc.geoip){
        for each (e in doc.geoip){
            if(e.type == "nameserver") {
                if(e.ipversion == "4") {
                    v4ns += 1;
                } else if (e.ipversion == "6") {
                    v6ns += 1;
                }
            }
        }
        
        emit(doc.testrun, [v6ns, v4ns, 1]);
    }
}