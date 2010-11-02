function(doc){
    var tmp = {};
    
    if(doc.dnscheck) {
        doc.dnscheck.forEach(function(e){
            tmp[e.tag] = e.level;
        });
        for(t in tmp) {
            emit([doc.testrun, tmp[t], t], 1);
        }
    }
}