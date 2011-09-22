function(doc){
    if(doc.geoip){
        doc.geoip.forEach(function(e){
            emit(e.address, e);
        });
    }
}