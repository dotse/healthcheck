function(keys,values,rereduce) {
    var count = {
            "CRITICAL": 0,
            "ERROR": 0,
            "WARNING": 0,
            "NOTICE": 0,
            "INFO": 0
        };

    for (var v in values) {
        if(values[v]) {
            count["CRITICAL"] += values[v]["CRITICAL"];
            count["ERROR"] += values[v]["ERROR"];
            count["WARNING"] += values[v]["WARNING"];
            count["NOTICE"] += values[v]["NOTICE"];
            count["INFO"] += values[v]["INFO"];
        } else {
            count = null;
        }
    }
    
    return count;
}