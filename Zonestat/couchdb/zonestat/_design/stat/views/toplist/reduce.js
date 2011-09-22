function(keys, values, rereduce) {
    var COUNT = 25;
    var sum = {};

    for(var v in values) {
        for(var k in values[v]) {
            if (sum[k] == null) {
                sum[k] = values[v][k];
            } else {
                sum[k] += values[v][k];                    
            }
        }
    }
    
    var keys = [];
    for(var k in sum) {
        keys.push(k);
    }

    var pairs = keys.map(function(n){return [n, sum[n]]});
    var sorted_pairs = pairs.sort(function(a,b){return b[1]-a[1]});

    var tmp = {};
    if(rereduce) {
        sorted_pairs = sorted_pairs.splice(0,COUNT);
    }
    
    for(var n in sorted_pairs){
        tmp[sorted_pairs[n][0]] = sorted_pairs[n][1];
    }

    return tmp;
}