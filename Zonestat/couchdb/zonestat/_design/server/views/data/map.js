function(doc){
    if(doc.geoip){
        doc.geoip.forEach(function(e){
            emit([doc.testrun, e.type, e.address, e.latitude, e.longitude, e.country, e.code, e.city, e.asn, e.name], 1);
        });
    }
}