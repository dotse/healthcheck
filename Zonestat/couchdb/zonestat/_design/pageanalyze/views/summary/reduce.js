function(keys, values, rereduce) {
    var res = {
        "total_bytes": 0,
        "count": 0,
        "external_resources": 0,
        "compressed_resources": 0,
        "average_compression_ratio_percent": 0,
        "total_requests": 0,
        "total_time": 0,
    };
    
    values.forEach(function(e){
        res.total_bytes += e.total_bytes;
        res.external_resources += e.external_resources;
        res.compressed_resources += e.compressed_resources;
        res.average_compression_ratio_percent += e.average_compression_ratio_percent;
        res.total_requests += e.total_requests;
        res.total_time += e.total_time;
        if(e.count) {
            res.count += e.count;
        } else {
            res.count += 1;
        }
    });
    
    return res;
}