function(doc){
    if(doc.dnscheck) {
        var count = {
            "CRITICAL": 0,
            "ERROR": 0,
            "WARNING": 0,
            "NOTICE": 0,
            "INFO": 0,
            "DEBUG": 0
        };
        
        doc.dnscheck.forEach(function(e){
            count[e.level] += 1;
        });
        
        var result = {
            "CRITICAL": {"0": 0, "1":0, "2":0, "3+":0 },
            "ERROR": {"0": 0, "1":0, "2":0, "3+":0 },
            "WARNING": {"0": 0, "1":0, "2":0, "3+":0 },
        };
        
        ["CRITICAL", "ERROR", "WARNING"].forEach(function(l){
            if(count[l] == 0) {
                result[l]["0"] = 1;
            } else if(count[l] == 1) {
                result[l]["1"] = 1;
            } else if(count[l] == 2) {
                result[l]["2"] = 1;
            } else if(count[l] >2) {
                result[l]["3+"] = 1;
            } 
        });
        
        emit(doc.testrun, result);
    }
}