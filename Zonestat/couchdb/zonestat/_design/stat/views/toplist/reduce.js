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
    var keep;
    if(rereduce) {
        keep = sorted_pairs.splice(0,COUNT);
        sorted_pairs = keep.concat(sorted_pairs.filter(function(n){return n[0]==keys[keys.length-1][2]})) // return n[0]>keys[keys.length-1][2]
    }
    
    for(var n in sorted_pairs){
        tmp[sorted_pairs[n][0]] = sorted_pairs[n][1];
    }

    return tmp;
}