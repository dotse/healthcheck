function(keys,values,rereduce){
    var result = {
        "CRITICAL": {"0": 0, "1":0, "2":0, "3+":0 },
        "ERROR": {"0": 0, "1":0, "2":0, "3+":0 },
        "WARNING": {"0": 0, "1":0, "2":0, "3+":0 },
    };
    
    values.forEach(function(e){
        ["CRITICAL", "ERROR", "WARNING"].forEach(function(l){
            ["0", "1", "2", "3+"].forEach(function(b){
                result[l][b] += e[l][b];
            });
        });
    });
    
    return result;
}