function(doc){
    var res = {};
    
    if(doc.geoip) {
        doc.geoip.forEach(function(e){
            if(e.type == 'nameserver'){
                e.asn.forEach(function(asn){
                    if (res[e.ipversion] == null) {
                        res[e.ipversion] = {};
                    };
                    if(res[e.ipversion][asn] == null) {
                        res[e.ipversion][asn] = 0;
                    }
                    res[e.ipversion][asn] = res[e.ipversion][asn] + 1;
                });
            }
        });
        for(ipv in res) {
            for(asn in res[ipv]){
                emit([ipv, doc.testrun, asn], res[ipv][asn]);
            }
        }
    }
}