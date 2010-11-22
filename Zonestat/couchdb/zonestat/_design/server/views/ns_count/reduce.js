function(keys, values, rereduce) {
    var tmp = [0, 0, 0];
    
    for each(e in values) {
        tmp[0] += e[0];
        tmp[1] += e[1];
        tmp[2] += e[2];
    }
    
    return tmp;
}