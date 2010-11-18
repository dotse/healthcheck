function(doc){
    var res = {};
    
    if(doc.geoip) {
        doc.geoip.forEach(function(e){
            if(e.type == 'nameserver'){
                e.asn.forEach(function(asn){
                    if(res[asn] == null) {
                        res[asn] = 0;
                    }
                    res[asn] = res[asn] + 1;
                });
            }
        });
        for(asn in res){
            emit([doc.testrun, asn], res[asn]);
        }
    }
}