function(keys, values, rereduce) {
    var tmp = {http:0, https:0};

    for each(e in values) {
        tmp.http += e.http;
        tmp.https += e.https;
    }
    
    return tmp;
}