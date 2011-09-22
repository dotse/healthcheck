function(doc){
    if(doc.geoip){
        doc.geoip.forEach(function(e){
            var h = {};
            h[e.address] = 1;
            emit([doc.testrun, e.type, e.address], h);
        });
    }
}